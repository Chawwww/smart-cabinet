import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../models/item_model.dart';
import '../services/ai_service.dart';

// ════════════════════════════════════════════════════════
// MedicineInfoScreen
//
// Shows full medicine information for any item:
//   • Purpose / usage
//   • Dosage guide
//   • Side effects
//   • Storage tips
//   • Warnings
//   • Alternatives
//
// Supports:
//   • Text query — type medicine name
//   • Voice input — speak the medicine name (multi-language)
//   • Auto-load — if item passed in, shows info immediately
// ════════════════════════════════════════════════════════

class MedicineInfoScreen extends StatefulWidget {
  // Optional: pass an existing item to auto-load its info
  final ItemModel? item;

  const MedicineInfoScreen({super.key, this.item});

  @override
  State<MedicineInfoScreen> createState() => _MedicineInfoScreenState();
}

class _MedicineInfoScreenState extends State<MedicineInfoScreen> {
  final _queryCtrl   = TextEditingController();
  final SpeechToText _speech = SpeechToText();
  final ScrollController _scrollController = ScrollController();

  MedicineInfo? _info;
  bool _isLoading    = false;
  bool _isListening  = false;
  bool _speechReady  = false;
  String? _error;
  List<String> _searchHistory = [];

  @override
  void initState() {
    super.initState();
    AIService().initialize();
    _initSpeech();
    _loadSearchHistory();
    
    // Auto-load if item provided
    if (widget.item != null) {
      _queryCtrl.text = widget.item!.name;
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _fetchMedicineInfo(widget.item!.name));
    }
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    _scrollController.dispose();
    _speech.stop();
    super.dispose();
  }

  // ── Speech init ───────────────────────────────────────
  Future<void> _initSpeech() async {
    if (kIsWeb) return;
    try {
      final ok = await _speech.initialize(
        onError: (_) => setState(() => _isListening = false),
        onStatus: (s) {
          if (s == SpeechToText.doneStatus ||
              s == SpeechToText.notListeningStatus) {
            setState(() => _isListening = false);
          }
        },
      );
      setState(() => _speechReady = ok);
    } catch (_) {
      setState(() => _speechReady = false);
    }
  }

  // ── Search History ────────────────────────────────────
  void _loadSearchHistory() {
    setState(() {
      _searchHistory = [
        'Paracetamol', 'Ibuprofen', 'Amoxicillin',
        'Loratadine', '扑热息痛', '布洛芬'
      ];
    });
  }

  void _saveToHistory(String query) {
    if (query.trim().isEmpty) return;
    setState(() {
      _searchHistory.remove(query);
      _searchHistory.insert(0, query);
      if (_searchHistory.length > 20) _searchHistory.removeLast();
    });
  }

  // ── Voice toggle ──────────────────────────────────────
  Future<void> _toggleVoice() async {
    if (!_speechReady) {
      _showSnack('Microphone not available. Check permissions.');
      return;
    }

    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    setState(() => _isListening = true);

    // Pick best locale available
    String locale = 'en_US';
    try {
      final locales = await _speech.locales();
      for (final pref in ['zh_CN', 'ms_MY', 'en_US']) {
        final lang = pref.split('_')[0];
        if (locales.any((l) => l.localeId.startsWith(lang))) {
          locale = pref;
          break;
        }
      }
    } catch (_) {}

    try {
      await _speech.listen(
        localeId: locale,
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 2),
        partialResults: true,
        onResult: (result) {
          setState(() => _queryCtrl.text = result.recognizedWords);
          if (result.finalResult && result.recognizedWords.isNotEmpty) {
            setState(() => _isListening = false);
            _fetchMedicineInfo(result.recognizedWords.trim());
          }
        },
      );
    } catch (e) {
      // Fallback: try without parameters
      await _speech.listen(
        onResult: (result) {
          setState(() => _queryCtrl.text = result.recognizedWords);
          if (result.finalResult && result.recognizedWords.isNotEmpty) {
            setState(() => _isListening = false);
            _fetchMedicineInfo(result.recognizedWords.trim());
          }
        },
      );
    }
  }

  // ── Fetch medicine info ───────────────────────────────
  Future<void> _fetchMedicineInfo(String name) async {
    if (name.trim().isEmpty) {
      _showSnack('请输入药物名称 / Enter medicine name');
      return;
    }

    setState(() {
      _isLoading = true;
      _error     = null;
      _info      = null;
    });

    try {
      final info = await AIService().getMedicineInfo(name.trim());
      setState(() => _info = info);
      _saveToHistory(name.trim());
      // Scroll to top to show results
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(
            content: Text(msg),
            duration: const Duration(seconds: 2),
          ));

  // ── Share result ──────────────────────────────────────
  void _shareInfo() {
    if (_info == null) return;
    Clipboard.setData(ClipboardData(text: _info!.toPlainText()));
    _showSnack('📋 Copied to clipboard');
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subColor  = textColor.withValues(alpha: 0.55);
    final isDark    = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Medicine Info'),
        actions: [
          if (_info != null)
            IconButton(
              icon: const Icon(Icons.share_outlined,
                  color: Color(0xFF4ECDC4)),
              tooltip: 'Share info',
              onPressed: _shareInfo,
            ),
          if (_info != null)
            IconButton(
              icon: const Icon(Icons.copy_outlined,
                  color: Color(0xFF4ECDC4)),
              tooltip: 'Copy info',
              onPressed: _shareInfo,
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Search bar with voice ──────────────────────
          _buildSearchBar(isDark, subColor, textColor),

          // Voice listening indicator
          if (_isListening) _buildListeningIndicator(textColor),

          // ── Body ────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? _buildLoading()
                : _error != null
                    ? _buildError(_error!, textColor, subColor)
                    : _info != null
                        ? _buildResult(_info!, textColor, subColor, isDark)
                        : _buildEmptyState(subColor, isDark),
          ),
        ],
      ),
    );
  }

  // ── Search Bar Widget ────────────────────────────────
  Widget _buildSearchBar(bool isDark, Color subColor, Color textColor) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF2D2D2D)
                    : Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                        alpha: isDark ? 0.3 : 0.07),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: Icon(Icons.medication_outlined,
                        color: Color(0xFF4ECDC4), size: 20),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _queryCtrl,
                      onSubmitted: (v) => _fetchMedicineInfo(v),
                      decoration: InputDecoration(
                        hintText: '输入药物名称… e.g. Paracetamol, 扑热息痛',
                        hintStyle: TextStyle(
                            color: subColor, fontSize: 13),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 13),
                      ),
                    ),
                  ),
                  if (_queryCtrl.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() {
                        _queryCtrl.clear();
                        _info  = null;
                        _error = null;
                      }),
                    ),
                  // Voice button
                  if (!kIsWeb) _voiceButton(),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Search button
          GestureDetector(
            onTap: () => _fetchMedicineInfo(_queryCtrl.text),
            child: Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4ECDC4), Color(0xFF45B7D1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.search,
                  color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _voiceButton() {
    if (_isListening) {
      return GestureDetector(
        onTap: _toggleVoice,
        child: Container(
          margin: const EdgeInsets.all(8),
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.stop,
              color: Colors.white, size: 16),
        ),
      );
    }
    return IconButton(
      icon: Icon(
        Icons.mic,
        color: _speechReady
            ? const Color(0xFF4ECDC4)
            : Colors.grey.shade400,
        size: 22,
      ),
      tooltip: 'Voice input',
      onPressed: _toggleVoice,
    );
  }

  Widget _buildListeningIndicator(Color textColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        border: Border(
          bottom: BorderSide(
              color: Colors.red.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.mic, color: Colors.red, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _queryCtrl.text.isEmpty
                  ? 'Listening… speak medicine name'
                  : '"${_queryCtrl.text}"',
              style: TextStyle(
                  fontSize: 13,
                  color: textColor,
                  fontStyle: FontStyle.italic),
            ),
          ),
          GestureDetector(
            onTap: _toggleVoice,
            child: const Text('Stop',
                style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
                color: Color(0xFF4ECDC4)),
            const SizedBox(height: 16),
            Text('Searching medicine information…',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                  fontSize: 14)),
          ],
        ),
      );

  Widget _buildError(
      String error, Color textColor, Color subColor) =>
      Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 60, color: Colors.red),
              const SizedBox(height: 16),
              Text('查询失败 / Query failed',
                style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor)),
              const SizedBox(height: 8),
              Text(error,
                  style:
                      TextStyle(fontSize: 12, color: subColor),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () =>
                    _fetchMedicineInfo(_queryCtrl.text),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4ECDC4)),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );

  Widget _buildEmptyState(Color subColor, bool isDark) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4ECDC4)
                        .withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.medication,
                      size: 44, color: Color(0xFF4ECDC4)),
                ),
                const SizedBox(height: 16),
                const Text('Medicine Information Assistant',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(
                  '输入或说出药物名称，AI 将提供：\n'
                  'Type or speak a medicine name. AI will provide:',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: subColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Feature list
          ...[
            ('💊', 'Purpose & Uses'),
            ('📋', 'Dosage Guide'),
            ('⚠️', 'Side Effects'),
            ('🌡️', 'Storage Instructions'),
            ('🚫', 'Contraindications'),
            ('🔄', 'Alternatives'),
          ].map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF2D2D2D)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade200),
                  ),
                  child: Row(children: [
                    Text(e.$1,
                        style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Text(e.$2,
                        style: TextStyle(
                            fontSize: 13, color: subColor)),
                  ]),
                ),
              )),
            const SizedBox(height: 16),
          // Search history
          if (_searchHistory.isNotEmpty) ...[
            Text('Recent Searches:',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: subColor)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _searchHistory.take(10).map((name) => GestureDetector(
                    onTap: () {
                      _queryCtrl.text = name;
                      _fetchMedicineInfo(name);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4ECDC4)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: const Color(0xFF4ECDC4)
                                .withValues(alpha: 0.4)),
                      ),
                      child: Text(name,
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF4ECDC4),
                              fontWeight: FontWeight.w500)),
                    ),
                  )).toList(),
            ),
          ],
          const SizedBox(height: 16),
          // Quick suggestions
          Text('常用查询 / Quick searches:',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: subColor)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              'Paracetamol', 'Ibuprofen', 'Amoxicillin',
              'Loratadine', '扑热息痛', '布洛芬', 'Omeprazole',
              'Metformin', 'Cetirizine', 'Vitamin C',
              'Aspirin', 'Antibiotic', 'Cough Syrup',
            ].map((name) => GestureDetector(
                  onTap: () {
                    _queryCtrl.text = name;
                    _fetchMedicineInfo(name);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4ECDC4)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFF4ECDC4)
                              .withValues(alpha: 0.4)),
                    ),
                    child: Text(name,
                        style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF4ECDC4),
                            fontWeight: FontWeight.w500)),
                  ),
                )).toList(),
          ),
        ],
      );

  // ── Medicine result card ──────────────────────────────
  Widget _buildResult(MedicineInfo info, Color textColor,
      Color subColor, bool isDark) {
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        // Header with rating/info badge
        Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
                child: Text('💊', style: TextStyle(fontSize: 26))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(info.name,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textColor)),
                if (info.chineseName.isNotEmpty)
                  Text(info.chineseName,
                      style: TextStyle(
                          fontSize: 14, color: subColor)),
              ],
            ),
          ),
          // Info badge
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF4ECDC4).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('AI',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4ECDC4))),
          ),
        ]),
        const SizedBox(height: 16),

        // Info sections
        if (info.purpose.isNotEmpty)
          _infoSection('💊 药物用途 / Purpose & Uses',
              info.purpose, const Color(0xFFFF6B6B), isDark),

        if (info.dosage.isNotEmpty)
          _infoSection('📋 用法用量 / Dosage',
              info.dosage, const Color(0xFF4ECDC4), isDark),

        if (info.sideEffects.isNotEmpty)
          _infoSection('⚠️ 副作用 / Side Effects',
              info.sideEffects, Colors.orange, isDark),

        if (info.contraindications.isNotEmpty)
          _infoSection('🚫 禁忌事项 / Contraindications',
              info.contraindications, Colors.red, isDark),

        if (info.storage.isNotEmpty)
          _infoSection('🌡️ 储存方式 / Storage',
              info.storage, const Color(0xFF45B7D1), isDark),

        if (info.alternatives.isNotEmpty)
          _infoSection('🔄 替代药物 / Alternatives',
              info.alternatives, const Color(0xFF6C5CE7), isDark),

        // Warnings
        if (info.warnings.isNotEmpty)
          _warningSection(info.warnings),

        // Disclaimer
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('⚕️ Medical Disclaimer',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                'This information is AI-generated for reference only. '
                'Always consult a qualified pharmacist or doctor '
                'before taking any medication.\n\n'
                '此信息由 AI 提供，仅供参考。在服用任何药物前，'
                '请务必咨询合格的药剂师或医生。',
                style: TextStyle(
                    fontSize: 11,
                    color: subColor,
                    fontStyle: FontStyle.italic,
                    height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _infoSection(String title, String content, Color color,
      bool isDark) =>
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14)),
              ),
              child: Row(children: [
                Text(title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: color)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(content,
                  style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface,
                      height: 1.6)),
            ),
          ],
        ),
      );

  Widget _warningSection(String warnings) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('⚠️ 重要警告 / Important Warnings',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.red)),
            const SizedBox(height: 8),
            Text(warnings,
                style: const TextStyle(
                    fontSize: 13,
                    color: Colors.red,
                    height: 1.6)),
          ],
        ),
      );
}