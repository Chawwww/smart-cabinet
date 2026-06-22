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
        model: 'gemini-3.1-flash-lite',
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
- Be concise.
- Use simple language.
- Return JSON only when requested.
- Keep answers helpful and accurate.
- When returning JSON, return ONLY the JSON with no markdown, no backticks, no explanation.
'''),
      );

      // Vision model — same model, Gemini 3.1 flash lite supports multimodal
      _visionModel = GenerativeModel(
        model: 'gemini-3.1-flash-lite',
        apiKey: AppConstants.geminiApiKey,
      );

      debugPrint('Gemini AI initialized successfully');
    } catch (e) {
      debugPrint('Gemini initialization failed: $e');
    }
  }

  // ═══════════════════════════════════════════════════
  // CORE CHAT
  // ═══════════════════════════════════════════════════

  Future<String> chat(String message) async {
    if (_model == null) throw Exception('AI model not initialized.');
    try {
      final response = await _model!.generateContent([Content.text(message)]);
      return response.text ?? 'No response generated.';
    } catch (e) {
      throw Exception('Failed to get AI response: $e');
    }
  }

  // ═══════════════════════════════════════════════════
  // AUTO-FILL FROM IMAGE
  // Sends the photo to Gemini Vision and returns a
  // structured ItemAutoFill object with all fields.
  // ═══════════════════════════════════════════════════

  Future<ItemAutoFill> autoFillFromImage(File imageFile) async {
    if (_visionModel == null) throw Exception('AI model not initialized.');

    final imageBytes = await imageFile.readAsBytes();
    final mimeType   = _getMimeType(imageFile.path);

    const prompt = '''
Look at this item image carefully.

Extract all visible information and return ONLY a JSON object (no markdown, no backticks):

{
  "name": "item name or product name",
  "brand": "brand or manufacturer name, empty string if not visible",
  "description": "brief description of what this item is",
  "category": "one of: Medicine, Food, Drinks, Tools, Documents, Electronics, Clothing, Others",
  "quantity": 1,
  "unit": "one of: pcs, box, bottle, pack, kg, g, L, ml",
  "expiry_date": "expiry date in YYYY-MM-DD format if visible, empty string if not",
  "production_date": "production/manufacturing date in YYYY-MM-DD format if visible, empty string if not",
  "note": "any other useful notes visible on the label like dosage, warnings, or instructions",
  "tags": ["tag1", "tag2"]
}

Rules:
- name is required, make your best guess from the image
- For medicine/food/drinks, look carefully for expiry dates (EXP, Best Before, BB, Use By)
- tags should reflect the item type (e.g. ["medicine", "tablet", "adult"])
- Return ONLY the JSON, nothing else
''';

    try {
      final response = await _visionModel!.generateContent([
        Content.multi([
          DataPart(mimeType, imageBytes),
          TextPart(prompt),
        ]),
      ]);

      final text = response.text ?? '{}';
      return _parseAutoFill(text);
    } catch (e) {
      throw Exception('Image analysis failed: $e');
    }
  }

  // ═══════════════════════════════════════════════════
  // AUTO-FILL FROM NAME
  // User typed an item name — AI fills in the rest.
  // ═══════════════════════════════════════════════════

  Future<ItemAutoFill> autoFillFromName(String itemName) async {
    if (_model == null) throw Exception('AI model not initialized.');

    final prompt = '''
The user is adding an item called: "$itemName"

Based on this name, return ONLY a JSON object (no markdown, no backticks):

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
  "tags": ["relevant", "tags", "for", "this", "item"]
}

Rules:
- Return ONLY the JSON, nothing else
- Make sensible defaults based on common knowledge of this item type
- For medicines, suggest "Medicine" category and relevant tags
- For food/drinks, suggest appropriate units
''';

    try {
      final response = await _model!.generateContent([Content.text(prompt)]);
      final text = response.text ?? '{}';
      return _parseAutoFill(text);
    } catch (e) {
      throw Exception('Auto-fill from name failed: $e');
    }
  }

  // ═══════════════════════════════════════════════════
  // PARSE AUTO-FILL RESPONSE
  // ═══════════════════════════════════════════════════

  ItemAutoFill _parseAutoFill(String raw) {
    try {
      // Strip any accidental markdown fences
      String clean = raw.trim();
      clean = clean.replaceAll(RegExp(r'```json|```'), '').trim();

      // Find the JSON object boundaries
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
                .toList() ??
            [],
      );
    } catch (e) {
      debugPrint('AutoFill parse error: $e\nRaw: $raw');
      return ItemAutoFill.empty();
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
      case 'jpeg': return 'image/jpeg';
      case 'png':  return 'image/png';
      case 'webp': return 'image/webp';
      case 'heic': return 'image/heic';
      default:     return 'image/jpeg';
    }
  }

  // ═══════════════════════════════════════════════════
  // EXISTING METHODS (unchanged)
  // ═══════════════════════════════════════════════════

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
    return await chat('''
What is the typical shelf life of: $itemName
Provide:
1. Shelf life
2. Storage recommendation
3. Short explanation
''');
  }

  Future<String> suggestStorage(String itemName) async {
    return await chat('''
Suggest the best way to store: $itemName
Include: Temperature, Humidity, Sunlight exposure, Important notes
''');
  }

  Future<String> organizeCabinet(List<String> items) async {
    return await chat('''
These are the current cabinet items: ${items.join(", ")}
Suggest:
1. Better organization.
2. Which items should be grouped together.
3. Special storage precautions.
''');
  }

  Future<String> suggestReplacement(String itemName) async {
    return await chat('''
Suggest alternatives or replacements for: $itemName
Include: Similar items, Uses, Storage recommendations.
''');
  }

  Future<String> explainMedicine(String medicineName) async {
    return await chat('''
Explain the medicine: $medicineName
Include: Main purpose, Common uses, Storage advice.
Keep the explanation brief.
''');
  }

  Future<String> summarizeItems(List<String> items) async {
    return await chat('''
These are the cabinet contents: ${items.join(", ")}
Provide: 1. Summary. 2. Categories. 3. Storage suggestions. 4. Items that may require special care.
''');
  }

  Future<String> findItem(
      String itemName, String cabinetName, String boxName) async {
    return await chat('''
Item: $itemName
Location:
Cabinet: $cabinetName
Box: $boxName
Generate a natural response telling the user where the item is.
''');
  }
}

// ═══════════════════════════════════════════════════
// DATA CLASS — holds auto-filled item fields
// ═══════════════════════════════════════════════════

class ItemAutoFill {
  final String name;
  final String brand;
  final String description;
  final String category;
  final int quantity;
  final String unit;
  final DateTime? expiryDate;
  final DateTime? productionDate;
  final String note;
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
        quantity: 1, unit: 'pcs', note: '', tags: [],
      );

  bool get isEmpty => name.isEmpty && description.isEmpty;
}