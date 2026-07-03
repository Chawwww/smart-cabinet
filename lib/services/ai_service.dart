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

  void initialize() {
    try {
      _model = GenerativeModel(
        model: 'gemini-3.5-flash', // Updated model name
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
        model: 'gemini-3.5-flash',
        apiKey: AppConstants.geminiApiKey,
      );

      debugPrint('✅ Gemini AI initialized successfully');
    } catch (e) {
      debugPrint('❌ Gemini initialization failed: $e');
    }
  }

  // ══════════════════════════════════════════════
  // CORE CHAT
  // ══════════════════════════════════════════════
  Future<String> chat(String message) async {
    if (_model == null) throw Exception('AI model not initialized.');
    try {
      final response = await _model!.generateContent([Content.text(message)]);
      return response.text ?? 'No response generated.';
    } catch (e) {
      throw Exception('Failed to get AI response: $e');
    }
  }

  // ══════════════════════════════════════════════
  // AUTO-FILL FROM IMAGE
  // Supervisor Req 6: AI recognises items from photo
  // ══════════════════════════════════════════════
  Future<ItemAutoFill> autoFillFromImage(File imageFile) async {
    if (_visionModel == null) throw Exception('AI model not initialized.');

    final imageBytes = await imageFile.readAsBytes();
    final mimeType   = _getMimeType(imageFile.path);

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
- Return ONLY the JSON, nothing else
''';

    try {
      final response = await _visionModel!.generateContent([
        Content.multi([DataPart(mimeType, imageBytes), TextPart(prompt)]),
      ]);
      return _parseAutoFill(response.text ?? '{}');
    } catch (e) {
      throw Exception('Image analysis failed: $e');
    }
  }

  // ══════════════════════════════════════════════
  // AUTO-FILL FROM NAME
  // ══════════════════════════════════════════════
  Future<ItemAutoFill> autoFillFromName(String itemName) async {
    if (_model == null) throw Exception('AI model not initialized.');
    final prompt = '''
The user is adding an item called: "$itemName"
Return ONLY this JSON (no markdown, no backticks):
{
  "name": "$itemName",
  "brand": "",
  "description": "brief description of what this item typically is",
  "category": "one of: Medicine, Food, Drinks, Tools, Documents, Electronics, Clothing, Others",
  "quantity": 1,
  "unit": "most typical unit for this item: pcs, box, bottle, pack, kg, g, L, ml",
  "expiry_date": "",
  "production_date": "",
  "note": "brief storage tip or important note for this item type",
  "tags": ["relevant", "tags"]
}
Return ONLY the JSON, nothing else.
''';
    try {
      final response = await _model!.generateContent([Content.text(prompt)]);
      return _parseAutoFill(response.text ?? '{}');
    } catch (e) {
      throw Exception('Auto-fill from name failed: $e');
    }
  }

  // ══════════════════════════════════════════════
  // AI COUNT ITEMS FROM PHOTO
  // Supervisor Req 6: Count quantity (PCS) from photo
  // ══════════════════════════════════════════════
  Future<AiCountResult> countItemsFromPhoto(
      File imageFile, String itemName) async {
    if (_visionModel == null) throw Exception('AI model not initialized.');

    final imageBytes = await imageFile.readAsBytes();
    final mimeType   = _getMimeType(imageFile.path);

    final prompt = '''
Look at this image carefully.
Count how many individual "$itemName" items are visible.

Rules:
- Count only clearly visible, complete items
- Do not count partial items unless clearly identifiable
- If stacked, estimate based on visible layers
- If image is unclear, return low confidence

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
      return _parseAiCount(response.text ?? '{}');
    } catch (e) {
      throw Exception('AI count failed: $e');
    }
  }

  // ══════════════════════════════════════════════
  // HELP & SUPPORT AI ANSWER
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
  // MEDICINE INFO — full structured response
  // Bilingual: English + Chinese (中文)
  // ══════════════════════════════════════════════
  Future<MedicineInfo> getMedicineInfo(String medicineName) async {
    if (_model == null) throw Exception('AI model not initialized.');

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
      return _parseMedicineInfo(response.text ?? '{}', medicineName);
    } catch (e) {
      throw Exception('Medicine info fetch failed: $e');
    }
  }

  MedicineInfo _parseMedicineInfo(String raw, String fallbackName) {
    try {
      String clean = raw.trim()
          .replaceAll(RegExp(r'```json|```'), '').trim();
      final start = clean.indexOf('{');
      final end   = clean.lastIndexOf('}');
      if (start == -1 || end == -1) {
        return MedicineInfo(
          name: fallbackName, chineseName: '', purpose: raw,
          dosage: '', sideEffects: '', contraindications: '',
          storage: '', alternatives: '', warnings: '');
      }
      final json = jsonDecode(clean.substring(start, end + 1))
          as Map<String, dynamic>;
      return MedicineInfo(
        name:              (json['name']              as String?) ?? fallbackName,
        chineseName:       (json['chinese_name']      as String?) ?? '',
        purpose:           (json['purpose']           as String?) ?? '',
        dosage:            (json['dosage']            as String?) ?? '',
        sideEffects:       (json['side_effects']      as String?) ?? '',
        contraindications: (json['contraindications'] as String?) ?? '',
        storage:           (json['storage']           as String?) ?? '',
        alternatives:      (json['alternatives']      as String?) ?? '',
        warnings:          (json['warnings']          as String?) ?? '',
      );
    } catch (e) {
      return MedicineInfo(
        name: fallbackName, chineseName: '', purpose: raw,
        dosage: '', sideEffects: '', contraindications: '',
        storage: '', alternatives: '', warnings: '');
    }
  }

  // ══════════════════════════════════════════════
  // PARSE HELPERS
  // ══════════════════════════════════════════════
  ItemAutoFill _parseAutoFill(String raw) {
    try {
      String clean = raw.trim()
          .replaceAll(RegExp(r'```json|```'), '').trim();
      final start = clean.indexOf('{');
      final end   = clean.lastIndexOf('}');
      if (start == -1 || end == -1) return ItemAutoFill.empty();
      final json = jsonDecode(clean.substring(start, end + 1))
          as Map<String, dynamic>;
      return ItemAutoFill(
        name:           (json['name']        as String?)?.trim() ?? '',
        brand:          (json['brand']       as String?)?.trim() ?? '',
        description:    (json['description'] as String?)?.trim() ?? '',
        category:       (json['category']    as String?)?.trim() ?? '',
        quantity:       (json['quantity'] as num?)?.toInt() ?? 1,
        unit:           (json['unit']        as String?)?.trim() ?? 'pcs',
        expiryDate:     _parseDate(json['expiry_date']),
        productionDate: _parseDate(json['production_date']),
        note:           (json['note']        as String?)?.trim() ?? '',
        tags: (json['tags'] as List<dynamic>?)
                ?.map((t) => t.toString().trim())
                .where((t) => t.isNotEmpty)
                .toList() ?? [],
      );
    } catch (e) {
      debugPrint('AutoFill parse error: $e\nRaw: $raw');
      return ItemAutoFill.empty();
    }
  }

  AiCountResult _parseAiCount(String raw) {
    try {
      String clean = raw.trim()
          .replaceAll(RegExp(r'```json|```'), '').trim();
      final start = clean.indexOf('{');
      final end   = clean.lastIndexOf('}');
      if (start == -1 || end == -1) {
        return AiCountResult(
            count: 0, confidence: 0, notes: 'Could not parse response');
      }
      final json = jsonDecode(clean.substring(start, end + 1))
          as Map<String, dynamic>;
      return AiCountResult(
        count:      (json['count']      as num?)?.toInt()    ?? 0,
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
        notes:      (json['notes']      as String?)          ?? '',
      );
    } catch (e) {
      return AiCountResult(count: 0, confidence: 0, notes: 'Parse error: $e');
    }
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null || value.toString().isEmpty) return null;
    try { return DateTime.parse(value.toString()); }
    catch (_) { return null; }
  }

  String _getMimeType(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg': case 'jpeg': return 'image/jpeg';
      case 'png':              return 'image/png';
      case 'webp':             return 'image/webp';
      case 'heic':             return 'image/heic';
      default:                 return 'image/jpeg';
    }
  }

  // ══════════════════════════════════════════════
  // EXISTING METHODS (kept exactly as original)
  // ══════════════════════════════════════════════
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

  Future<String> suggestCategory(String itemName) async {
    final prompt = '''
Item: $itemName
Choose one category only from:
Medicine, Food, Drinks, Tools, Documents, Others
Return only the category name.
''';
    return await chat(prompt);
  }

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

  Future<String> suggestStorage(String itemName) async {
    final prompt = '''
Suggest the best way to store: $itemName
Include: Temperature, Humidity, Sunlight exposure, Important notes
''';
    return await chat(prompt);
  }

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

  Future<String> suggestReplacement(String itemName) async {
    final prompt = '''
Suggest alternatives or replacements for: $itemName
Include: Similar items, Uses, Storage recommendations.
''';
    return await chat(prompt);
  }

  Future<String> explainMedicine(String medicineName) async {
    final prompt = '''
Explain the medicine: $medicineName
Include: Main purpose, Common uses, Storage advice.
Keep the explanation brief.
''';
    return await chat(prompt);
  }

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
// DATA CLASSES
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
      name: '', brand: '', description: '', category: '',
      quantity: 1, unit: 'pcs', note: '', tags: []);

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

STORAGE / 储存:
$storage

ALTERNATIVES :
$alternatives

WARNINGS :
$warnings

---
For reference only. Consult a pharmacist or doctor before taking any medication.
''';
}