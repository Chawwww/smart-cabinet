import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../config/app_constants.dart';

class AIService {
  static final AIService _instance = AIService._internal();

  factory AIService() => _instance;

  AIService._internal();

  GenerativeModel? _model;

  /// Initialize Gemini model
  void initialize() {
    try {
      _model = GenerativeModel(
        model: 'gemini-3.1-flash-lite',
        apiKey: AppConstants.geminiApiKey,
        systemInstruction: Content.text(
          '''
You are Smart Cabinet AI Assistant.

Responsibilities:
- Help users locate stored items.
- Suggest categories for new items.
- Predict shelf life.
- Give storage recommendations.
- Extract medicine information.
- Organize cabinet contents.

Rules:
- Be concise.
- Use simple language.
- Return JSON only when requested.
- Keep answers helpful and accurate.
''',
        ),
      );

      debugPrint('Gemini AI initialized successfully');
    } catch (e) {
      debugPrint('Gemini initialization failed: $e');
    }
  }

  /// General chat
  Future<String> chat(String message) async {
    if (_model == null) {
      throw Exception('AI model not initialized.');
    }

    try {
      final response = await _model!.generateContent([
        Content.text(message),
      ]);

      return response.text ?? 'No response generated.';
    } catch (e) {
      throw Exception('Failed to get AI response: $e');
    }
  }

  /// Extract medicine information
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

  /// Suggest category
  Future<String> suggestCategory(String itemName) async {
    final prompt = '''
Item:

$itemName

Choose one category only from:

Medicine
Food
Drinks
Tools
Documents
Others

Return only the category name.
''';

    return await chat(prompt);
  }

  /// Predict shelf life
  Future<String> getExpiryPrediction(String itemName) async {
    final prompt = '''
What is the typical shelf life of:

$itemName

Provide:

1. Shelf life
2. Storage recommendation
3. Short explanation
''';

    return await chat(prompt);
  }

  /// Storage recommendation
  Future<String> suggestStorage(String itemName) async {
    final prompt = '''
Suggest the best way to store:

$itemName

Include:

- Temperature
- Humidity
- Sunlight exposure
- Important notes
''';

    return await chat(prompt);
  }

  /// Organize cabinet items
  Future<String> organizeCabinet(List<String> items) async {
    final prompt = '''
These are the current cabinet items:

${items.join(", ")}

Suggest:

1. Better organization.
2. Which items should be grouped together.
3. Special storage precautions.
''';

    return await chat(prompt);
  }

  /// Low stock replacement suggestions
  Future<String> suggestReplacement(String itemName) async {
    final prompt = '''
Suggest alternatives or replacements for:

$itemName

Include:

- Similar items.
- Uses.
- Storage recommendations.
''';

    return await chat(prompt);
  }

  /// Explain medicine usage
  Future<String> explainMedicine(String medicineName) async {
    final prompt = '''
Explain the medicine:

$medicineName

Include:

- Main purpose.
- Common uses.
- Storage advice.

Keep the explanation brief.
''';

    return await chat(prompt);
  }

  /// Summarize all items
  Future<String> summarizeItems(List<String> items) async {
    final prompt = '''
These are the cabinet contents:

${items.join(", ")}

Provide:

1. Summary.
2. Categories.
3. Storage suggestions.
4. Items that may require special care.
''';

    return await chat(prompt);
  }

  /// Find item location
  Future<String> findItem(
    String itemName,
    String cabinetName,
    String boxName,
  ) async {
    final prompt = '''
Item:

$itemName

Location:

Cabinet: $cabinetName
Box: $boxName

Generate a natural response telling the user where the item is.
''';

    return await chat(prompt);
  }
}