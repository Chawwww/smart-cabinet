// lib/services/ai_service.dart
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../config/app_constants.dart';

class AIService {
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();

  GenerativeModel? _model;
  GenerativeModel? _visionModel;
  bool _initialized = false;

  // ══════════════════════════════════════════════
  // FIX #1: initialize() no longer fails silently.
  // Callers (and the UI) can now check `isInitialized`
  // and read `initError` to see *why* init failed,
  // instead of every later call just throwing a
  // generic "AI model not initialized." with no context.
  // ══════════════════════════════════════════════
  String? _initError;
  bool get isInitialized => _initialized;
  String? get initError => _initError;

  void initialize() {
    if (_initialized) return;

    try {
      _model = GenerativeModel(
        model: 'gemini-3.1-flash-lite', // Using stable model
        apiKey: AppConstants.geminiApiKey,
        systemInstruction: Content.text('''
You are Smart Cabinet AI Assistant.

Responsibilities:
- Help users locate stored items.
- Suggest categories for new items.
- Predict shelf life and expiry dates.
- Give storage recommendations.
- Extract item information from images and text.
- Organize cabinet contents.

Rules:
- Be concise and helpful.
- Use simple language.
- Return JSON only when requested — no markdown, no backticks, no explanation.
- Keep answers accurate.
'''),
      );

      // Separate vision model for image analysis
      _visionModel = GenerativeModel(
        model: 'gemini-3.1-flash-lite',
        apiKey: AppConstants.geminiApiKey,
      );

      _initialized = true;
      _initError = null;
      debugPrint('✅ Gemini AI initialized successfully');
    } catch (e) {
      _initialized = false;
      _initError = e.toString();
      debugPrint('❌ Gemini initialization failed: $e');
    }
  }

  void _ensureInitialized() {
    if (_model == null) {
      throw Exception(
        'AI model not initialized.'
        '${_initError != null ? ' Reason: $_initError' : ''}',
      );
    }
  }

  // ══════════════════════════════════════════════
  // CORE CHAT (ORIGINAL - KEPT)
  // ══════════════════════════════════════════════
  Future<String> chat(String message) async {
    _ensureInitialized();
    try {
      final response = await _model!.generateContent([Content.text(message)]);
      return response.text ?? 'No response generated.';
    } catch (e) {
      throw Exception('Failed to get AI response: $e');
    }
  }

  // ══════════════════════════════════════════════
  // SMART SEARCH (IMPROVED)
  // Used by SearchScreen: detects language, translates,
  // matches cabinet items, and suggests where to buy
  // items that aren't in the cabinet.
  // ══════════════════════════════════════════════
  Future<SmartSearchResult> smartSearch(
      String query, List<String> cabinetItemNames) async {
    _ensureInitialized();

    final prompt = '''
User searched for: "$query"

This query may be written in Chinese, Malay, English, or another language.

Cabinet contains these items: ${cabinetItemNames.isEmpty ? 'None' : cabinetItemNames.join(', ')}

Return ONLY this JSON (no markdown, no backticks):
{
  "detected_language": "name of the language the query is written in, e.g. Chinese, Malay, English",
  "english_translation": "the query translated to English, empty string if the query is already in English",
  "matched_item_names": ["exact cabinet item names that match the query, empty array if none match"],
  "related_info": "brief helpful info about what the user is searching for, 2-4 sentences, empty string if not applicable",
  "online_suggestions": [
    {
      "platform": "store or platform name, e.g. Shopee, Guardian, Watsons, Lazada",
      "note": "short helpful note, e.g. fastest delivery or nearest branch",
      "search_url": "a URL that searches for this item on that platform"
    }
  ]
}

Rules:
- Only populate online_suggestions when matched_item_names is empty (item not found in cabinet)
- Limit online_suggestions to 2-4 relevant, real platforms
- Return ONLY the JSON, absolutely nothing else
''';

    try {
      final response = await _model!.generateContent([Content.text(prompt)]);
      final result = _parseSmartSearch(response.text ?? '{}');

      // If no items matched and no suggestions, add fallback suggestions
      if (result.matchedItemNames.isEmpty && result.onlineSuggestions.isEmpty) {
        return SmartSearchResult(
          detectedLanguage: result.detectedLanguage,
          englishTranslation: result.englishTranslation,
          matchedItemNames: [],
          relatedInfo: result.relatedInfo.isNotEmpty
              ? result.relatedInfo
              : 'Try searching on Shopee, Lazada, or Amazon for this item.',
          onlineSuggestions: [
            OnlineSuggestion(
              platform: 'Shopee',
              note: 'Popular online marketplace in Malaysia',
              searchUrl: 'https://shopee.com.my/search?keyword=${Uri.encodeComponent(query)}',
            ),
            OnlineSuggestion(
              platform: 'Lazada',
              note: 'Wide selection of products',
              searchUrl: 'https://www.lazada.com.my/catalog/?q=${Uri.encodeComponent(query)}',
            ),
            OnlineSuggestion(
              platform: 'Google',
              note: 'Search for more options',
              searchUrl: 'https://www.google.com/search?q=${Uri.encodeComponent(query)}',
            ),
          ],
        );
      }

      return result;
    } catch (e) {
      // Return fallback on error
      return SmartSearchResult(
        detectedLanguage: 'en',
        englishTranslation: query,
        matchedItemNames: [],
        relatedInfo: 'Could not search. Try typing in English.',
        onlineSuggestions: [
          OnlineSuggestion(
            platform: 'Shopee',
            note: 'Malaysia online shopping',
            searchUrl: 'https://shopee.com.my/search?keyword=${Uri.encodeComponent(query)}',
          ),
        ],
      );
    }
  }

  // ══════════════════════════════════════════════
  // AUTO-FILL FROM IMAGE (IMPROVED)
  // Supervisor Req 6: AI recognises items from photo
  //
  // FIX #2: image bytes are now read ONCE and passed
  // down to the fallback instead of re-reading the same
  // file from disk a second time.
  // ══════════════════════════════════════════════
  Future<ItemAutoFill> autoFillFromImage(File imageFile) async {
    _ensureInitializedVision();

    final imageBytes = await imageFile.readAsBytes();
    final mimeType = _getMimeType(imageFile.path);

    const prompt = '''
Look at this item image carefully.
Extract all visible information and return ONLY this JSON (no markdown, no backticks):
{
  "name": "item name or product name",
  "brand": "brand or manufacturer, empty string if not visible",
  "description": "brief description of what this item is",
  "category": "one of: Medicine, Food, Drinks, Tools, Documents, Electronics, Clothing, Others",
  "quantity": 1,
  "unit": "one of: pcs, box, bottle, pack, kg, g, L, ml",
  "expiry_date": "YYYY-MM-DD if visible, empty string if not",
  "production_date": "YYYY-MM-DD if visible, empty string if not",
  "note": "any visible dosage, warnings, or instructions",
  "tags": ["tag1", "tag2"]
}
Rules:
- name is required — make your best guess from the image
- Look carefully for expiry dates: EXP, Best Before, BB, Use By, 到期
- For medicine, look for dosage information
- For food, look for weight/volume
- Return ONLY the JSON, nothing else
''';

    try {
      final response = await _visionModel!.generateContent([
        Content.multi([DataPart(mimeType, imageBytes), TextPart(prompt)]),
      ]);
      final result = _parseAutoFill(response.text ?? '{}');

      // If name is empty, try a more general prompt.
      // Reuse the bytes we already read instead of hitting disk again.
      if (result.name.isEmpty) {
        return _autoFillFromImageFallback(imageBytes, mimeType);
      }

      return result;
    } catch (e) {
      // Fallback to name-based auto-fill if image analysis fails
      debugPrint('Image analysis failed: $e');
      try {
        return await _autoFillFromImageFallback(imageBytes, mimeType);
      } catch (_) {
        return ItemAutoFill.empty();
      }
    }
  }

  // Fallback for image analysis.
  // Now takes already-read bytes + mimeType instead of a File,
  // so we never read the same image off disk twice.
  Future<ItemAutoFill> _autoFillFromImageFallback(
      Uint8List imageBytes, String mimeType) async {
    const prompt = '''
Describe what you see in this image.
Return ONLY this JSON (no markdown):
{
  "name": "what is this item?",
  "category": "Medicine/Food/Drinks/Tools/Others",
  "description": "brief description"
}
''';

    try {
      final response = await _visionModel!.generateContent([
        Content.multi([DataPart(mimeType, imageBytes), TextPart(prompt)]),
      ]);
      final result = _parseAutoFill(response.text ?? '{}');
      return ItemAutoFill(
        name: result.name,
        brand: '',
        description: result.description,
        category: result.category,
        quantity: 1,
        unit: 'pcs',
        expiryDate: null,
        productionDate: null,
        note: '',
        tags: [],
      );
    } catch (e) {
      return ItemAutoFill.empty();
    }
  }

  // ══════════════════════════════════════════════
  // AUTO-FILL FROM NAME (IMPROVED)
  // ══════════════════════════════════════════════
  Future<ItemAutoFill> autoFillFromName(String itemName) async {
    _ensureInitialized();

    final prompt = '''
The user is adding an item called: "$itemName"
Return ONLY this JSON (no markdown, no backticks):
{
  "name": "$itemName",
  "brand": "typical brand or manufacturer for this item, empty if unknown",
  "description": "brief description of what this item typically is",
  "category": "one of: Medicine, Food, Drinks, Tools, Documents, Electronics, Clothing, Others",
  "quantity": 1,
  "unit": "most typical unit for this item: pcs, box, bottle, pack, kg, g, L, ml",
  "expiry_date": "",
  "production_date": "",
  "note": "brief storage tip or important note for this item type",
  "tags": ["relevant", "tags", "here"]
}

If this looks like a medicine, add "medicine" as a tag.
If it's food, add "food", "perishable" or "non-perishable".
Return ONLY the JSON, nothing else.
''';
    try {
      final response = await _model!.generateContent([Content.text(prompt)]);
      final result = _parseAutoFill(response.text ?? '{}');

      // If category is empty, try to guess from name
      if (result.category.isEmpty) {
        return _guessCategoryFromName(itemName);
      }

      return result;
    } catch (e) {
      return _guessCategoryFromName(itemName);
    }
  }

  // Fallback category guessing
  ItemAutoFill _guessCategoryFromName(String name) {
    final lowerName = name.toLowerCase();
    String category = 'Others';
    List<String> tags = [];

    // Medicine detection
    if (lowerName.contains('medicine') ||
        lowerName.contains('药') ||
        lowerName.contains('tablet') ||
        lowerName.contains('capsule') ||
        lowerName.contains('syrup') ||
        lowerName.contains('ointment') ||
        lowerName.contains('cream') ||
        lowerName.contains('pill')) {
      category = 'Medicine';
      tags.add('medicine');
    }
    // Food detection
    else if (lowerName.contains('food') ||
        lowerName.contains('snack') ||
        lowerName.contains('canned') ||
        lowerName.contains('包') ||
        lowerName.contains('食')) {
      category = 'Food';
      tags.add('food');
    }
    // Drinks detection
    else if (lowerName.contains('drink') ||
        lowerName.contains('饮料') ||
        lowerName.contains('water') ||
        lowerName.contains('juice') ||
        lowerName.contains('soda') ||
        lowerName.contains('tea') ||
        lowerName.contains('coffee')) {
      category = 'Drinks';
      tags.add('drink');
    }
    // Tools detection
    else if (lowerName.contains('tool') ||
        lowerName.contains('工具') ||
        lowerName.contains('hammer') ||
        lowerName.contains('screw') ||
        lowerName.contains('drill') ||
        lowerName.contains('wrench')) {
      category = 'Tools';
      tags.add('tool');
    }
    // Documents detection
    else if (lowerName.contains('document') ||
        lowerName.contains('文件') ||
        lowerName.contains('paper') ||
        lowerName.contains('file') ||
        lowerName.contains('folder')) {
      category = 'Documents';
      tags.add('document');
    }
    // Electronics detection
    else if (lowerName.contains('electronic') ||
        lowerName.contains('电') ||
        lowerName.contains('battery') ||
        lowerName.contains('cable') ||
        lowerName.contains('charger') ||
        lowerName.contains('phone')) {
      category = 'Electronics';
      tags.add('electronics');
    }
    // Clothing detection
    else if (lowerName.contains('clothing') ||
        lowerName.contains('cloth') ||
        lowerName.contains('shirt') ||
        lowerName.contains('pants') ||
        lowerName.contains('shoes') ||
        lowerName.contains('衣服')) {
      category = 'Clothing';
      tags.add('clothing');
    }

    return ItemAutoFill(
      name: name,
      brand: '',
      description: '',
      category: category,
      quantity: 1,
      unit: 'pcs',
      expiryDate: null,
      productionDate: null,
      note: '',
      tags: tags,
    );
  }

  // ══════════════════════════════════════════════
  // AI COUNT ITEMS FROM PHOTO (IMPROVED)
  // Supervisor Req 6: Count quantity (PCS) from photo
  //
  // FIX #3: previously ANY count of 0 triggered a retry
  // with a looser prompt, even when 0 was the correct
  // answer (no items visible). That conflated "the model
  // failed to parse" with "the model legitimately found
  // nothing" and could overwrite a correct zero with a
  // wrong nonzero guess from the fallback prompt.
  //
  // Now: _parseAiCount returns null when the response
  // genuinely couldn't be parsed (missing/invalid JSON).
  // We only fall back on that — a parsed, low-confidence,
  // or zero count is trusted and returned as-is.
  // ══════════════════════════════════════════════
  Future<AiCountResult> countItemsFromPhoto(
      File imageFile, String itemName) async {
    _ensureInitializedVision();

    final imageBytes = await imageFile.readAsBytes();
    final mimeType = _getMimeType(imageFile.path);

    final prompt = '''
Look at this image carefully.
Count how many individual "$itemName" items are visible.

Rules:
- Count only clearly visible, complete items
- Do not count partial items unless clearly identifiable
- If stacked, estimate based on visible layers
- If image is unclear, return low confidence
- For small items (pills, tablets), count visible individual units
- For larger items, count each visible unit

Return ONLY this JSON (no markdown, no backticks):
{
  "count": 12,
  "confidence": 0.85,
  "notes": "Counted 12 bottles arranged in 2 rows. Some items partially obscured."
}

Where:
- count: integer number of items visible (0 if none found)
- confidence: float 0.0–1.0 (how confident you are)
- notes: brief explanation of what you saw and how you counted
''';

    try {
      final response = await _visionModel!.generateContent([
        Content.multi([DataPart(mimeType, imageBytes), TextPart(prompt)]),
      ]);
      final result = _parseAiCount(response.text ?? '');

      // Only fall back when the response genuinely could not be parsed —
      // NOT just because the parsed count happens to be zero.
      if (result == null) {
        return _countItemsFromPhotoFallback(imageFile, itemName);
      }

      return result;
    } catch (e) {
      debugPrint('AI count error: $e');
      return AiCountResult(
        count: 0,
        confidence: 0.0,
        notes: 'Unable to count items. Please count manually.',
      );
    }
  }

  // Fallback for counting — only reached on genuine parse/response failure.
  Future<AiCountResult> _countItemsFromPhotoFallback(
      File imageFile, String itemName) async {
    final imageBytes = await imageFile.readAsBytes();
    final mimeType = _getMimeType(imageFile.path);

    final prompt = '''
Can you see any "$itemName" in this image?
If yes, approximately how many? Make your best estimate.
Return ONLY JSON:
{
  "count": 0,
  "confidence": 0.0,
  "notes": "description of what you see"
}
''';

    try {
      final response = await _visionModel!.generateContent([
        Content.multi([DataPart(mimeType, imageBytes), TextPart(prompt)]),
      ]);
      return _parseAiCount(response.text ?? '') ??
          AiCountResult(
            count: 0,
            confidence: 0.0,
            notes: 'Could not parse response.',
          );
    } catch (e) {
      return AiCountResult(
        count: 0,
        confidence: 0.0,
        notes: 'Could not detect items in image.',
      );
    }
  }

  // ══════════════════════════════════════════════
  // HELP & SUPPORT AI ANSWER (ORIGINAL - KEPT)
  // ══════════════════════════════════════════════
  Future<String> getHelpAnswer(String question) async {
    final prompt = '''
You are a helpful support agent for the Smart Cabinet Finder app.
The user asked: "$question"

Smart Cabinet Finder is a Flutter mobile app for managing household/office inventory.
Features: add items with photos, AI autofill, BLE cabinet scanning (ESP32),
expiry tracking, low stock alerts, categories, cabinets, boxes, dark mode, AI chat.

Answer helpfully and concisely. Give step-by-step instructions for app questions.
''';
    return await chat(prompt);
  }

  // ══════════════════════════════════════════════
  // MEDICINE INFO — full structured response (IMPROVED)
  // Bilingual: English + Chinese (中文)
  // ══════════════════════════════════════════════
  Future<MedicineInfo> getMedicineInfo(String medicineName) async {
    _ensureInitialized();

    final prompt = '''
You are a professional pharmacist assistant. Provide comprehensive information
about the medicine: "$medicineName"

The user may have typed in Chinese (中文), Malay, or English. Support all.

Return ONLY this JSON (no markdown, no backticks, no extra text):
{
  "name": "Official English medicine name",
  "chinese_name": "中文药名 (if applicable, empty string if not a common medicine in Chinese)",
  "purpose": "Main purpose and medical uses. Include both English and Chinese (中文) explanation. 2-4 sentences.",
  "dosage": "Standard dosage for adults and children if different. Include frequency and duration. Both English and Chinese (中文).",
  "side_effects": "Common and serious side effects to watch for. Both English and Chinese (中文).",
  "contraindications": "Who should NOT take this medicine. Conditions, allergies, drug interactions. Both English and Chinese (中文).",
  "storage": "How to store this medicine properly. Temperature, light, moisture. Both English and Chinese (中文).",
  "alternatives": "Common alternative medicines or generic names. Both English and Chinese (中文).",
  "warnings": "Critical warnings — pregnancy, driving, alcohol, age restrictions. Both English and Chinese (中文). Empty string if none."
}

Rules:
- If the medicine name is in Chinese, still return full information
- If not a real medicine, return a helpful response in the purpose field and empty strings elsewhere
- Always include both English and Chinese text in each field
- Return ONLY the JSON, absolutely nothing else
''';

    try {
      final response = await _model!.generateContent([Content.text(prompt)]);
      final result = _parseMedicineInfo(response.text ?? '{}', medicineName);

      // If no information found, try a simpler query
      if (result.name == medicineName && result.purpose.isEmpty) {
        return _getMedicineInfoFallback(medicineName);
      }

      return result;
    } catch (e) {
      debugPrint('Medicine info error: $e');
      return _getMedicineInfoFallback(medicineName);
    }
  }

  // Fallback for medicine info
  Future<MedicineInfo> _getMedicineInfoFallback(String medicineName) async {
    final prompt = '''
Tell me about: $medicineName

Return ONLY JSON:
{
  "name": "$medicineName",
  "chinese_name": "",
  "purpose": "brief description of what this medicine is used for",
  "dosage": "typical dosage information",
  "side_effects": "common side effects",
  "contraindications": "who should avoid this medicine",
  "storage": "storage recommendations",
  "alternatives": "similar medicines",
  "warnings": "important warnings"
}
''';

    try {
      final response = await _model!.generateContent([Content.text(prompt)]);
      return _parseMedicineInfo(response.text ?? '{}', medicineName);
    } catch (e) {
      return MedicineInfo(
        name: medicineName,
        chineseName: '',
        purpose: 'Information not available. Please consult a healthcare professional.',
        dosage: 'Please consult a pharmacist or doctor.',
        sideEffects: 'Not available.',
        contraindications: 'Not available.',
        storage: 'Not available.',
        alternatives: 'Not available.',
        warnings: 'Always consult a healthcare professional before taking any medication.',
      );
    }
  }

  MedicineInfo _parseMedicineInfo(String raw, String fallbackName) {
    try {
      String clean = raw.trim().replaceAll(RegExp(r'```json|```'), '').trim();
      final start = clean.indexOf('{');
      final end = clean.lastIndexOf('}');
      if (start == -1 || end == -1) {
        return MedicineInfo(
            name: fallbackName,
            chineseName: '',
            purpose: raw,
            dosage: '',
            sideEffects: '',
            contraindications: '',
            storage: '',
            alternatives: '',
            warnings: '');
      }
      final json =
          jsonDecode(clean.substring(start, end + 1)) as Map<String, dynamic>;
      return MedicineInfo(
        name: (json['name'] as String?) ?? fallbackName,
        chineseName: (json['chinese_name'] as String?) ?? '',
        purpose: (json['purpose'] as String?) ?? '',
        dosage: (json['dosage'] as String?) ?? '',
        sideEffects: (json['side_effects'] as String?) ?? '',
        contraindications: (json['contraindications'] as String?) ?? '',
        storage: (json['storage'] as String?) ?? '',
        alternatives: (json['alternatives'] as String?) ?? '',
        warnings: (json['warnings'] as String?) ?? '',
      );
    } catch (e) {
      debugPrint('Medicine parse error: $e');
      return MedicineInfo(
          name: fallbackName,
          chineseName: '',
          purpose: raw,
          dosage: '',
          sideEffects: '',
          contraindications: '',
          storage: '',
          alternatives: '',
          warnings: '');
    }
  }

  // ══════════════════════════════════════════════
  // PARSE HELPERS (IMPROVED)
  // ══════════════════════════════════════════════
  ItemAutoFill _parseAutoFill(String raw) {
    try {
      String clean = raw.trim().replaceAll(RegExp(r'```json|```'), '').trim();
      final start = clean.indexOf('{');
      final end = clean.lastIndexOf('}');
      if (start == -1 || end == -1) return ItemAutoFill.empty();
      final json =
          jsonDecode(clean.substring(start, end + 1)) as Map<String, dynamic>;
      return ItemAutoFill(
        name: (json['name'] as String?)?.trim() ?? '',
        brand: (json['brand'] as String?)?.trim() ?? '',
        description: (json['description'] as String?)?.trim() ?? '',
        category: (json['category'] as String?)?.trim() ?? '',
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
        unit: (json['unit'] as String?)?.trim() ?? 'pcs',
        expiryDate: _parseDate(json['expiry_date']),
        productionDate: _parseDate(json['production_date']),
        note: (json['note'] as String?)?.trim() ?? '',
        tags: (json['tags'] as List<dynamic>?)
                ?.map((t) => t.toString().trim())
                .where((t) => t.isNotEmpty)
                .toList() ??
            [],
      );
    } catch (e) {
      debugPrint('AutoFill parse error: $e\nRaw: $raw');
      return ItemAutoFill.empty();
    }
  }

  // FIX #3 (parser side): returns null when the response could not be
  // parsed at all (no valid JSON found / decode error), instead of
  // silently returning a zero-count result that looks identical to a
  // legitimate "0 items found" answer. Callers use the null to decide
  // whether a retry is warranted.
  AiCountResult? _parseAiCount(String raw) {
    try {
      String clean = raw.trim().replaceAll(RegExp(r'```json|```'), '').trim();
      final start = clean.indexOf('{');
      final end = clean.lastIndexOf('}');
      if (start == -1 || end == -1) {
        debugPrint('AI count: no JSON object found in response');
        return null;
      }
      final json =
          jsonDecode(clean.substring(start, end + 1)) as Map<String, dynamic>;
      return AiCountResult(
        count: (json['count'] as num?)?.toInt() ?? 0,
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
        notes: (json['notes'] as String?) ?? '',
      );
    } catch (e) {
      debugPrint('AI count parse error: $e');
      return null;
    }
  }

  SmartSearchResult _parseSmartSearch(String raw) {
    try {
      String clean = raw.trim().replaceAll(RegExp(r'```json|```'), '').trim();
      final start = clean.indexOf('{');
      final end = clean.lastIndexOf('}');
      if (start == -1 || end == -1) return SmartSearchResult.empty();

      final json =
          jsonDecode(clean.substring(start, end + 1)) as Map<String, dynamic>;

      final suggestionsRaw = (json['online_suggestions'] as List<dynamic>?) ?? [];
      final suggestions = suggestionsRaw
          .whereType<Map<String, dynamic>>()
          .map((m) => OnlineSuggestion(
                platform: (m['platform'] as String?)?.trim() ?? '',
                note: (m['note'] as String?)?.trim() ?? '',
                searchUrl: (m['search_url'] as String?)?.trim() ?? '',
              ))
          .where((s) => s.platform.isNotEmpty)
          .toList();

      return SmartSearchResult(
        detectedLanguage: (json['detected_language'] as String?)?.trim() ?? '',
        englishTranslation: (json['english_translation'] as String?)?.trim() ?? '',
        matchedItemNames: (json['matched_item_names'] as List<dynamic>?)
                ?.map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList() ??
            [],
        relatedInfo: (json['related_info'] as String?)?.trim() ?? '',
        onlineSuggestions: suggestions,
      );
    } catch (e) {
      debugPrint('SmartSearch parse error: $e\nRaw: $raw');
      return SmartSearchResult.empty();
    }
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null || value.toString().isEmpty) return null;
    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return null;
    }
  }

  String _getMimeType(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }

  void _ensureInitializedVision() {
    if (_visionModel == null) {
      throw Exception(
        'AI model not initialized.'
        '${_initError != null ? ' Reason: $_initError' : ''}',
      );
    }
  }

  // ══════════════════════════════════════════════
  // EXISTING METHODS (KEPT EXACTLY AS ORIGINAL)
  // ══════════════════════════════════════════════

  // ORIGINAL - extractMedicineInfo
  Future<String> extractMedicineInfo(String text) async {
    final prompt = '''
Extract medicine information from the text below.
Return ONLY JSON.
{
  "name": "",
  "dosage": "",
  "expiry": "",
  "manufacturer": "",
  "batch": "",
  "instructions": ""
}
Text:
$text
''';
    return await chat(prompt);
  }

  // ORIGINAL - suggestCategory
  Future<String> suggestCategory(String itemName) async {
    final prompt = '''
Item: $itemName
Choose one category only from:
Medicine, Food, Drinks, Tools, Documents, Others
Return only the category name.
''';
    return await chat(prompt);
  }

  // ORIGINAL - getExpiryPrediction
  Future<String> getExpiryPrediction(String itemName) async {
    final prompt = '''
What is the typical shelf life of: $itemName
Provide:
1. Shelf life
2. Storage recommendation
3. Short explanation
''';
    return await chat(prompt);
  }

  // ORIGINAL - suggestStorage
  Future<String> suggestStorage(String itemName) async {
    final prompt = '''
Suggest the best way to store: $itemName
Include: Temperature, Humidity, Sunlight exposure, Important notes
''';
    return await chat(prompt);
  }

  // ORIGINAL - organizeCabinet
  Future<String> organizeCabinet(List<String> items) async {
    final prompt = '''
These are the current cabinet items: ${items.join(", ")}
Suggest:
1. Better organization.
2. Which items should be grouped together.
3. Special storage precautions.
''';
    return await chat(prompt);
  }

  // ORIGINAL - suggestReplacement
  Future<String> suggestReplacement(String itemName) async {
    final prompt = '''
Suggest alternatives or replacements for: $itemName
Include: Similar items, Uses, Storage recommendations.
''';
    return await chat(prompt);
  }

  // ORIGINAL - explainMedicine
  Future<String> explainMedicine(String medicineName) async {
    final prompt = '''
Explain the medicine: $medicineName
Include: Main purpose, Common uses, Storage advice.
Keep the explanation brief.
''';
    return await chat(prompt);
  }

  // ORIGINAL - summarizeItems
  Future<String> summarizeItems(List<String> items) async {
    final prompt = '''
These are the cabinet contents: ${items.join(", ")}
Provide:
1. Summary.
2. Categories.
3. Storage suggestions.
4. Items that may require special care.
''';
    return await chat(prompt);
  }

  // ORIGINAL - findItem
  Future<String> findItem(
      String itemName, String cabinetName, String boxName) async {
    final prompt = '''
Item: $itemName
Location:
Cabinet: $cabinetName
Box: $boxName
Generate a natural response telling the user where the item is.
''';
    return await chat(prompt);
  }
}

// ══════════════════════════════════════════════
// DATA CLASSES (KEPT EXACTLY AS ORIGINAL)
// ══════════════════════════════════════════════

class ItemAutoFill {
  final String name, brand, description, category, unit, note;
  final int quantity;
  final DateTime? expiryDate, productionDate;
  final List<String> tags;

  const ItemAutoFill({
    required this.name,
    required this.brand,
    required this.description,
    required this.category,
    required this.quantity,
    required this.unit,
    this.expiryDate,
    this.productionDate,
    required this.note,
    required this.tags,
  });

  factory ItemAutoFill.empty() => const ItemAutoFill(
      name: '',
      brand: '',
      description: '',
      category: '',
      quantity: 1,
      unit: 'pcs',
      note: '',
      tags: []);

  bool get isEmpty => name.isEmpty && description.isEmpty;
}

class AiCountResult {
  final int count;
  final double confidence;
  final String notes;

  const AiCountResult({
    required this.count,
    required this.confidence,
    required this.notes,
  });
}

class MedicineInfo {
  final String name;
  final String chineseName;
  final String purpose;
  final String dosage;
  final String sideEffects;
  final String contraindications;
  final String storage;
  final String alternatives;
  final String warnings;

  const MedicineInfo({
    required this.name,
    required this.chineseName,
    required this.purpose,
    required this.dosage,
    required this.sideEffects,
    required this.contraindications,
    required this.storage,
    required this.alternatives,
    required this.warnings,
  });

  // FIX #7 (cosmetic): removed the stray space before the colon on
  // "ALTERNATIVES" and "WARNINGS" so all section headers are consistent.
  String toPlainText() => '''
$name${chineseName.isNotEmpty ? ' ($chineseName)' : ''}

PURPOSE:
$purpose

DOSAGE:
$dosage

SIDE EFFECTS:
$sideEffects

CONTRAINDICATIONS:
$contraindications

STORAGE:
$storage

ALTERNATIVES:
$alternatives

WARNINGS:
$warnings

---
For reference only. Consult a pharmacist or doctor before taking any medication.
''';
}

class SmartSearchResult {
  final String detectedLanguage;
  final String englishTranslation;
  final List<String> matchedItemNames;
  final String relatedInfo;
  final List<OnlineSuggestion> onlineSuggestions;

  const SmartSearchResult({
    required this.detectedLanguage,
    required this.englishTranslation,
    required this.matchedItemNames,
    required this.relatedInfo,
    required this.onlineSuggestions,
  });

  factory SmartSearchResult.empty() => const SmartSearchResult(
        detectedLanguage: '',
        englishTranslation: '',
        matchedItemNames: [],
        relatedInfo: '',
        onlineSuggestions: [],
      );
}

class OnlineSuggestion {
  final String platform;
  final String note;
  final String searchUrl;

  const OnlineSuggestion({
    required this.platform,
    required this.note,
    required this.searchUrl,
  });
}