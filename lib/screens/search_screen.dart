import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/item_provider.dart';
import '../providers/language_provider.dart';
import '../models/item_model.dart';
import '../services/ai_service.dart';
import '../widgets/item_card.dart';
import '../widgets/empty_state.dart';
import 'item_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl   = TextEditingController();
  final SpeechToText _speech = SpeechToText();

  String _query        = '';
  bool _isListening    = false;
  bool _speechReady    = false;
  bool _isAiSearching  = false;
  SmartSearchResult? _smartResult;

  // ── Voice language selection ──────────────────────────
  // speech_to_text recognizes ONE locale per session — it cannot
  // auto-detect which language you're speaking. So instead of guessing,
  // we let the user pick, and we check what's actually installed on
  // the device before offering a language as an option.
  List<LocaleName> _availableLocales = [];
  String _voiceLocale = 'en_US';

  static const _langOptions = [
    {'label': 'EN', 'locale': 'en_US'},
    {'label': '中文', 'locale': 'zh_CN'},
    {'label': 'BM', 'locale': 'ms_MY'},
  ];

  // Maps LanguageProvider's app-level language code to a speech_to_text
  // localeId, so the mic defaults to whatever language the user already
  // picked for the app instead of always starting on English.
  static const Map<String, String> _appCodeToSpeechLocale = {
    'en': 'en_US',
    'zh': 'zh_CN',
    'ms': 'ms_MY',
  };

  @override
  void initState() {
    super.initState();
    context.read<ItemProvider>().loadItems();
    AIService().initialize();

    final appLanguageCode = context.read<LanguageProvider>().locale.languageCode;
    _voiceLocale = _appCodeToSpeechLocale[appLanguageCode] ?? 'en_US';

    _initSpeech();
  }

  Future<void> _initSpeech() async {
    if (kIsWeb) return;
    try {
      final ok = await _speech.initialize(
        onError: (_) => setState(() => _isListening = false),
        onStatus: (s) {
          if (s == SpeechToText.doneStatus || s == SpeechToText.notListeningStatus) {
            setState(() => _isListening = false);
          }
        },
      );
      if (!mounted) return;
      setState(() => _speechReady = ok);
      if (ok) await _refreshAvailableLocales();
    } catch (_) {}
  }

  // Re-checks which speech locales are installed on the device right now.
  // Lets the user tap "Refresh" after changing a language setting in
  // Settings/Google app, instead of having to fully restart the app.
  Future<void> _refreshAvailableLocales() async {
    try {
      final locales = await _speech.locales();
      if (mounted) setState(() => _availableLocales = locales);
    } catch (_) {}
  }

  bool _localeSupported(String localePrefix) => _availableLocales
      .any((l) => l.localeId.toLowerCase().startsWith(localePrefix.toLowerCase()));

  @override
  void dispose() {
    _ctrl.dispose();
    if (_speechReady) _speech.stop();
    super.dispose();
  }

  // ── Voice toggle ─────────────────────────────────────
  Future<void> _toggleVoice() async {
    if (!_speechReady) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone not available. Check permissions.')));
      return;
    }
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    if (!_localeSupported(_voiceLocale.split('_')[0])) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
            'Voice input for this language isn\'t installed on your device. '
            'Add it under your phone\'s language / speech settings, or pick a different language above.')),
      );
      return;
    }

    setState(() => _isListening = true);
    try {
      await _speech.listen(
        localeId: _voiceLocale,
        // Longer window + longer pause tolerance so speech isn't cut off
        // mid-sentence, especially with natural pauses in a second language.
        listenFor: const Duration(seconds: 45),
        pauseFor: const Duration(seconds: 5),
        listenMode: ListenMode.dictation,
        partialResults: true,
        onResult: (result) {
          setState(() {
            _ctrl.text = result.recognizedWords;
            _query     = result.recognizedWords;
          });
          if (result.finalResult && result.recognizedWords.isNotEmpty) {
            setState(() => _isListening = false);
            _runAiSearch(result.recognizedWords.trim());
          }
        },
      );
    } catch (_) {
      setState(() => _isListening = false);
    }
  }

  // ── AI Smart Search ───────────────────────────────────
  Future<void> _runAiSearch(String query) async {
    if (query.trim().isEmpty) return;
    setState(() { _isAiSearching = true; _smartResult = null; });
    final allNames = context.read<ItemProvider>().items.map((i) => i.name).toList();
    try {
      final result = await AIService().smartSearch(query, allNames);
      if (!mounted) return;
      setState(() { _smartResult = result; _isAiSearching = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isAiSearching = false);
    }
  }

  Future<void> _openLink(String url) async {
    try {
      String u = url.trim();
      if (!u.startsWith('http')) u = 'https://$u';
      await launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemProvider = context.watch<ItemProvider>();
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subColor  = textColor.withValues(alpha: 0.5);
    final searchBg  = isDark ? const Color(0xFF2D2D2D) : Colors.white;

    final localResults = _query.isEmpty
        ? <ItemModel>[]
        : itemProvider.searchItems(_query);

    final aiItems = _smartResult != null
        ? itemProvider.items.where((item) =>
            _smartResult!.matchedItemNames.any((name) =>
                item.name.toLowerCase().contains(name.toLowerCase()) ||
                name.toLowerCase().contains(item.name.toLowerCase())))
            .toList()
        : <ItemModel>[];

    return Column(
      children: [
        // ── Search bar ──────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Container(
            decoration: BoxDecoration(
              color: searchBg,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.07),
                  blurRadius: 10, offset: const Offset(0, 3))],
            ),
            child: Row(children: [
              const Padding(
                padding: EdgeInsets.only(left: 14),
                child: Icon(Icons.search, color: Color(0xFF636E72)),
              ),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  onChanged: (v) => setState(() {
                    _query       = v;
                    _smartResult = null;
                  }),
                  onSubmitted: (v) { if (v.trim().isNotEmpty) _runAiSearch(v); },
                  decoration: InputDecoration(
                    hintText: 'Search in any language… 中文 / BM / English',
                    hintStyle: TextStyle(color: subColor, fontSize: 13),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 14),
                  ),
                ),
              ),
              if (_query.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() {
                    _ctrl.clear(); _query = ''; _smartResult = null;
                  }),
                ),
              // Voice button
              if (!kIsWeb)
                _isListening
                    ? GestureDetector(
                        onTap: _toggleVoice,
                        child: Container(
                          margin: const EdgeInsets.all(8),
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(16)),
                          child: const Icon(Icons.stop, color: Colors.white, size: 16),
                        ),
                      )
                    : IconButton(
                        icon: Icon(Icons.mic,
                            color: _speechReady ? const Color(0xFF4ECDC4) : Colors.grey.shade400,
                            size: 22),
                        onPressed: _toggleVoice,
                      ),
              // AI search button
              IconButton(
                icon: _isAiSearching
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4ECDC4)))
                    : const Icon(Icons.auto_awesome, color: Color(0xFF4ECDC4), size: 20),
                tooltip: 'AI Smart Search',
                onPressed: _query.trim().isNotEmpty ? () => _runAiSearch(_query) : null,
              ),
            ]),
          ),
        ),

        // ── Voice language picker ──────────────────────
        // Lets the user tell the recognizer which language they're about
        // to speak, instead of the app guessing. Chips for languages not
        // installed on the device are shown dimmed with an explanatory tap.
        if (!kIsWeb && _speechReady)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Icon(Icons.language, size: 14, color: subColor),
                const SizedBox(width: 6),
                ..._langOptions.map((opt) {
                  final label    = opt['label']!;
                  final localeId = opt['locale']!;
                  final supported = _localeSupported(localeId.split('_')[0]);
                  final selected  = _voiceLocale == localeId;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () {
                        if (supported) {
                          setState(() => _voiceLocale = localeId);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  '$label voice input isn\'t installed on this device. '
                                  'Add it in your phone\'s language / speech settings, then tap Refresh.'),
                              action: SnackBarAction(
                                label: 'Refresh',
                                onPressed: _refreshAvailableLocales,
                              ),
                            ),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFF4ECDC4).withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected
                                ? const Color(0xFF4ECDC4)
                                : subColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(label, style: TextStyle(
                          fontSize: 11,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          color: !supported
                              ? subColor.withValues(alpha: 0.3)
                              : (selected ? const Color(0xFF4ECDC4) : subColor),
                        )),
                      ),
                    ),
                  );
                }),
                const Spacer(),
                // Manual refresh: re-check installed languages after the
                // user changes a setting, without restarting the app.
                GestureDetector(
                  onTap: () async {
                    await _refreshAvailableLocales();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Checked for newly installed languages.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Icon(Icons.refresh, size: 16, color: subColor),
                ),
              ],
            ),
          ),

        // Language detect tag
        if (_smartResult != null &&
            _smartResult!.detectedLanguage.isNotEmpty &&
            _smartResult!.detectedLanguage.toLowerCase() != 'english')
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Row(children: [
              const Icon(Icons.translate, size: 13, color: Color(0xFF4ECDC4)),
              const SizedBox(width: 5),
              Text('${_smartResult!.detectedLanguage} → "${_smartResult!.englishTranslation}"',
                  style: TextStyle(fontSize: 11, color: subColor)),
            ]),
          ),

        // Body
        Expanded(
          child: _query.isEmpty
              ? _emptyState(subColor)
              : _isAiSearching
                  ? const Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF4ECDC4)),
                        SizedBox(height: 16),
                        Text('AI is searching…'),
                      ]))
                  : _smartResult != null
                      ? _smartResults(aiItems, localResults, textColor, subColor, isDark)
                      : _localResults(localResults, textColor, subColor),
        ),
      ],
    );
  }

  Widget _emptyState(Color subColor) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.travel_explore, size: 72, color: subColor.withValues(alpha: 0.2)),
      const SizedBox(height: 16),
      Text('Search in any language',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: subColor)),
      const SizedBox(height: 6),
      Text('Type 头痛, sakit kepala, headache…',
          style: TextStyle(fontSize: 13, color: subColor)),
      const SizedBox(height: 4),
      Text('Tap ✨ for AI smart search',
          style: TextStyle(fontSize: 12, color: const Color(0xFF4ECDC4).withValues(alpha: 0.9))),
      if (!kIsWeb && _speechReady) ...[
        const SizedBox(height: 4),
        Text('Pick a language above, then tap 🎤 to search by voice',
            style: TextStyle(fontSize: 12, color: subColor)),
      ],
    ]),
  );

  Widget _smartResults(List<ItemModel> aiItems, List<ItemModel> localItems,
      Color textColor, Color subColor, bool isDark) {
    final result = _smartResult!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (aiItems.isNotEmpty) ...[
          _sectionHeader('📦 Found in cabinet (${aiItems.length})', textColor),
          const SizedBox(height: 8),
          _grid(aiItems),
          const SizedBox(height: 20),
        ],
        if (aiItems.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline, color: Colors.orange, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(
                  'Not found in your cabinet. See where to buy below.',
                  style: TextStyle(fontSize: 13, color: textColor))),
            ]),
          ),
          const SizedBox(height: 16),
        ],
        if (result.relatedInfo.isNotEmpty) ...[
          _sectionHeader('💡 Related Information', textColor),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFF4ECDC4).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF4ECDC4).withValues(alpha: 0.25)),
            ),
            child: Text(result.relatedInfo,
                style: TextStyle(fontSize: 13, color: textColor, height: 1.6)),
          ),
          const SizedBox(height: 20),
        ],
        if (result.onlineSuggestions.isNotEmpty) ...[
          _sectionHeader('🛒 Where to Buy', textColor),
          const SizedBox(height: 8),
          ...result.onlineSuggestions.map((s) => _shopCard(s, textColor, subColor)),
          const SizedBox(height: 12),
        ],
        if (localItems.isNotEmpty) ...[
          _sectionHeader('🔍 Other matches', textColor),
          const SizedBox(height: 8),
          _grid(localItems),
        ],
      ],
    );
  }

  Widget _localResults(List<ItemModel> results, Color textColor, Color subColor) {
    if (results.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const EmptyState(icon: Icons.search_off,
              title: 'No results found',
              subtitle: 'Tap ✨ to search with AI'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _runAiSearch(_query),
            icon: const Icon(Icons.auto_awesome, size: 16),
            label: const Text('Try AI Smart Search'),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4ECDC4)),
          ),
        ],
      );
    }
    return _grid(results);
  }

  Widget _grid(List<ItemModel> items) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2, childAspectRatio: 0.78,
      crossAxisSpacing: 12, mainAxisSpacing: 12,
    ),
    itemCount: items.length,
    itemBuilder: (ctx, i) => ItemCard(
      item: items[i],
      onTap: () => Navigator.push(ctx,
          MaterialPageRoute(builder: (_) => ItemDetailScreen(item: items[i]))),
    ),
  );

  Widget _sectionHeader(String title, Color textColor) =>
      Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor));

  Widget _shopCard(OnlineSuggestion s, Color textColor, Color subColor) =>
      Card(
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openLink(s.searchUrl),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF4ECDC4).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF4ECDC4)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.platform, style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
                  if (s.note.isNotEmpty)
                    Text(s.note, style: TextStyle(fontSize: 12, color: subColor)),
                ],
              )),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF4ECDC4).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Open', style: TextStyle(fontSize: 12, color: Color(0xFF4ECDC4), fontWeight: FontWeight.w600)),
                  SizedBox(width: 4),
                  Icon(Icons.open_in_new, size: 13, color: Color(0xFF4ECDC4)),
                ]),
              ),
            ]),
          ),
        ),
      );
}