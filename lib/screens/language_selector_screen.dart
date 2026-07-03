import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../l10n/app_localizations.dart';

class LanguageSelectorScreen extends StatelessWidget {
  const LanguageSelectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();
    final appLocalizations = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(appLocalizations.selectLanguage),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  const Icon(
                    Icons.language,
                    size: 60,
                    color: Color(0xFF4ECDC4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    appLocalizations.selectLanguage,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose your preferred language',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Expanded(
              child: ListView(
                children: LanguageProvider.supportedLocales.map((locale) {
                  final code = locale.languageCode;
                  final name = LanguageProvider.languageNames[code]!;
                  final flag = LanguageProvider.languageFlags[code]!;
                  final isSelected = languageProvider.isSelected(code);

                  return GestureDetector(
                    onTap: () => _selectLanguage(context, code),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF4ECDC4).withOpacity(0.1)
                            : (isDark
                                ? Colors.grey.shade800
                                : Colors.white),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF4ECDC4)
                              : (isDark
                                  ? Colors.grey.shade700
                                  : Colors.grey.shade300),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(flag, style: const TextStyle(fontSize: 32)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? const Color(0xFF4ECDC4)
                                        : null,
                                  ),
                                ),
                                Text(
                                  code == 'en' ? 'English' :
                                  code == 'zh' ? '简体中文' : 'Bahasa Melayu',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              Icons.check_circle,
                              color: Color(0xFF4ECDC4),
                              size: 28,
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectLanguage(BuildContext context, String languageCode) {
    final languageProvider = context.read<LanguageProvider>();
    languageProvider.setLanguage(languageCode);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Language changed to ${LanguageProvider.languageNames[languageCode]}',
        ),
        backgroundColor: const Color(0xFF4ECDC4),
        duration: const Duration(seconds: 2),
      ),
    );
    Navigator.pop(context);
  }
}