import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/ai_service.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});
  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final _questionController = TextEditingController();
  String? _aiAnswer;
  bool _isLoading = false;

  final List<_FAQ> _faqs = [
    _FAQ('How do I add an item?',
        'Go to the Items tab and tap the + button at the bottom right. '
        'You can fill in details manually, take a photo, or use AI Auto-Fill to detect item info automatically.'),
    _FAQ('Can I add an item without a cabinet?',
        'Yes! Cabinet and Box are optional when adding items. You can assign a location later by editing the item.'),
    _FAQ('How does AI Auto-Fill work?',
        'When adding an item, tap the ✨ button next to the item name to auto-fill fields based on the name. '
        'Or take a photo — AI will scan the label and extract name, brand, expiry date, and more.'),
    _FAQ('How do I search in Chinese or Malay?',
        'Just type in any language in the Search tab. Tap the ✨ AI icon to run a smart search — '
        'it translates your query, finds related items, and suggests where to buy if not found.'),
    _FAQ('How do I connect to the smart cabinet hardware?',
        'Go to Menu → IoT / Cabinet Settings. Make sure Bluetooth is on, then tap Scan to find your ESP32 device. '
        'Once connected, the cabinet door state and sensor readings will appear automatically.'),
    _FAQ('How do I get expiry alerts?',
        'Expiry alerts appear in the Notifications tab automatically. Items expiring within 7 days are flagged as "Soon". '
        'Make sure you set an expiry date when adding items.'),
    _FAQ('How do I set a low stock alert?',
        'When adding or editing an item, set the "Low Stock Alert At" field. '
        'When quantity drops to or below that number, the item appears in Notifications.'),
    _FAQ('How do I change the app language or theme?',
        'Go to Menu → Dark Mode toggle to switch between light and dark. '
        'The app automatically responds to your device language settings.'),
    _FAQ('How do I back up my data?',
        'All your data is automatically saved to Firebase cloud in real time. '
        'Logging in on a new device with the same account restores everything instantly.'),
    _FAQ('How do I delete my account?',
        'Go to Menu → User Profile → scroll down → Delete Account. '
        'This permanently removes all your data from the cloud.'),
  ];

  @override
  void initState() {
    super.initState();
    AIService().initialize();
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _askAI() async {
    final q = _questionController.text.trim();
    if (q.isEmpty) return;
    setState(() { _isLoading = true; _aiAnswer = null; });
    try {
      final answer = await AIService().getHelpAnswer(q);
      setState(() => _aiAnswer = answer);
    } catch (e) {
      setState(() => _aiAnswer = 'Could not get an answer: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subColor  = textColor.withValues(alpha: 0.55);
    final isDark    = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ── AI Help Assistant ─────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4ECDC4), Color(0xFF45B7D1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text('AI Support Assistant',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('Ask anything about the app',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _questionController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'e.g. How do I add a photo?',
                            hintStyle: TextStyle(color: Colors.white60),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: _isLoading
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send, color: Colors.white),
                        onPressed: _isLoading ? null : _askAI,
                      ),
                    ],
                  ),
                ),
                if (_aiAnswer != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(_aiAnswer!,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13, height: 1.5)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Quick links ───────────────────────────
          Text('Quick Actions',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textColor)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _quickLink(
                context,
                icon: Icons.email_outlined,
                label: 'Email Us',
                color: const Color(0xFF6C5CE7),
                onTap: () => _launch('mailto:support@smartcabinet.app'),
              )),
              const SizedBox(width: 12),
              Expanded(child: _quickLink(
                context,
                icon: Icons.chat_bubble_outline,
                label: 'WhatsApp',
                color: const Color(0xFF00B894),
                onTap: () => _launch('https://wa.me/601234567890'),
              )),
              const SizedBox(width: 12),
              Expanded(child: _quickLink(
                context,
                icon: Icons.language,
                label: 'Website',
                color: const Color(0xFF45B7D1),
                onTap: () => _launch('https://smartcabinet.app'),
              )),
            ],
          ),
          const SizedBox(height: 24),

          // ── FAQ ───────────────────────────────────
          Text('Frequently Asked Questions',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textColor)),
          const SizedBox(height: 8),
          ..._faqs.map((faq) => _FAQCard(faq: faq)),

          const SizedBox(height: 24),

          // ── App info ──────────────────────────────
          Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('Smart Cabinet Finder',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: textColor)),
                  const SizedBox(height: 4),
                  Text('Version 1.0.0',
                      style: TextStyle(color: subColor, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('Powered by Gemini AI + Firebase',
                      style: TextStyle(color: subColor, fontSize: 12)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () =>
                            _launch('https://smartcabinet.app/privacy'),
                        child: const Text('Privacy Policy'),
                      ),
                      const Text('·'),
                      TextButton(
                        onPressed: () =>
                            _launch('https://smartcabinet.app/terms'),
                        child: const Text('Terms of Use'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _quickLink(BuildContext context,
      {required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// ── FAQ Card ──────────────────────────────────────
class _FAQCard extends StatefulWidget {
  final _FAQ faq;
  const _FAQCard({required this.faq});
  @override
  State<_FAQCard> createState() => _FAQCardState();
}

class _FAQCardState extends State<_FAQCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subColor  = textColor.withValues(alpha: 0.6);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        onExpansionChanged: (v) => setState(() => _expanded = v),
        leading: Icon(
          _expanded
              ? Icons.help
              : Icons.help_outline,
          color: const Color(0xFF4ECDC4),
        ),
        title: Text(widget.faq.question,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(widget.faq.answer,
                style: TextStyle(
                    fontSize: 13, color: subColor, height: 1.6)),
          ),
        ],
      ),
    );
  }
}

class _FAQ {
  final String question, answer;
  const _FAQ(this.question, this.answer);
}