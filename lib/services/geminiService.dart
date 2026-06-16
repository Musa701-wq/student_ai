// lib/services/gemini_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/creditService.dart';

class GeminiService {
  // Hosted Backend Configuration
  String get _baseUrl {
    return dotenv.env['MENTOR_AI_BASE_URL'] ?? 'http://localhost:3000';
  }

  String get _accessKey {
    return dotenv.env['MENTOR_AI_ACCESS_KEY'] ?? dotenv.env['SERVER_ACCESS_KEY'] ?? '';
  }

  /// Estimated token count from the last API call (prompt + response) / 4
  int _lastEstimatedTokens = 0;
  int get lastEstimatedTokens => _lastEstimatedTokens;

  /// Centralized method to call the hosted Gemini API
  Future<String> _ask(String prompt, {String endpoint = '/api/mentorai/chat'}) async {
    final url = Uri.parse('$_baseUrl$endpoint');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': _accessKey,
        },
        body: jsonEncode({'prompt': prompt}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = _cleanResponse(data['result'] ?? "No result from AI.");

        if (data['total_tokens'] != null && data['total_tokens'] is num) {
          _lastEstimatedTokens = (data['total_tokens'] as num).toInt();
        } else {
          // Token estimation: 1 token ≈ 4 characters
          final inputTokens  = prompt.length ~/ 4;
          final outputTokens = result.length ~/ 4;
          _lastEstimatedTokens = inputTokens + outputTokens;
        }

        // Credit cost based on total tokens
        final creditCost = _calcCredits(_lastEstimatedTokens);

        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('📤 Endpoint       : $endpoint');
        print('🔢 TOTAL  tokens  : $_lastEstimatedTokens');
        print('💳 CREDITS to deduct: $creditCost');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

        return result;
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Invalid API key');
      } else if (response.statusCode == 422) {
        throw Exception('Blocked by safety filters');
      } else {
        debugPrint('❌ Hosted API Error: ${response.statusCode} - ${response.body}');
        throw Exception('Error calling hosted model: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Network / API Exception: $e');
      rethrow;
    }
  }

  /// Credit cost tiers (mirrors CreditsService.calcCreditsFromTokens)
  num _calcCredits(int tokens) {
    return CreditsService.calcCreditsFromTokens(tokens);
  }

  /// Get the credit cost of the last API call
  num get lastCallCreditCost => _calcCredits(_lastEstimatedTokens);

  /// Removes unwanted formatting like asterisks and extra spaces
  String _cleanResponse(String text) {
    return text
        .replaceAll(RegExp(r'\*+'), '') // Remove any number of asterisks
        .replaceAll(RegExp(r'\s{2,}'), ' ') // Normalize spaces
        .trim();
  }

  /// Summarize text
  Future<String> summarize(String text) async {
    final prompt = """
Summarize the following text professionally and concisely. 
Focus on key takeaways and main arguments. 
Ensure the output is easy to read and structured logically.

Text to summarize:
$text

Guidelines:
1. Do NOT use asterisks (*) for bullet points or emphasis.
2. Use clear, concise language.
3. If using bullets, use a dash (-) or a bullet point (•).
4. Keep the structure clean and readable.
""";
    return await _ask(prompt, endpoint: '/api/mentorai/summarize');
  }

  /// Chat with Gemini (Study Assistant mode)
  Future<String> chat(String query) async {
    final prompt = """
You are a helpful Study Buddy AI. 
- Use the following STRICT format for your response:

Question: [Specific part of the user's query/image being addressed]
Answer: [Correct Option/Final Answer]
Explanation: [Clear and detailed reasoning]

- IMPORTANT: Do NOT use '*' (asterisks) for bullet points or lists.
- You can use '**' (bold) for headers like **Question:**, **Answer:**, and **Explanation:**.
- If multiple questions are present, repeat this block for each.
- Maintain a highly professional and clean layout.
- If the question is unrelated to studies, politely decline.

User: $query
""";
    return await _ask(prompt);
  }

  /// Chat with context (Study Assistant mode)
  Future<String> chatWithContext(String query, List<Map<String, String>> context) async {
    final conversation = context.map((m) {
      final role = (m["role"] == "user") ? "user" : "model";
      return "$role: ${m["text"]}";
    }).join("\n");

    final prompt = """
You are a helpful Study Buddy AI.
Use a clean and professional layout using ONLY the headers below:

**Question:** [Text]
**Answer:** [Text]
**Explanation:** [Text]

- Strictly avoid all '*' (asterisks) for bullets.
- Separate each section clearly.

user: $query
""";
    return await _ask(prompt);
  }

  /// Chat with strict document context (AI Tutor Mode)
  Future<String> tutorChatWithContext(String query, List<Map<String, String>> chatHistory, String documentContext) async {
    // Truncate document context if it's too massive, to prevent payload errors.
    final String truncatedDocContext = documentContext.length > 25000 
        ? "${documentContext.substring(0, 25000)}... [Truncated for brevity]"
        : documentContext;

    final conversation = chatHistory.map((m) {
      final role = (m["role"] == "user") ? "user" : "model";
      return "$role: ${m["text"]}";
    }).join("\n");

    final prompt = """
You are an expert AI Tutor. Your prime directive is to analyze the user's specific study material and answer their questions STRICTLY based on that content.

--- START OF USER'S STUDY MATERIAL (CONTEXT) ---
$truncatedDocContext
--- END OF USER'S STUDY MATERIAL (CONTEXT) ---

Rules for your response:
1. Try your absolute best to answer the user's question using the provided context.
2. If the user's question is NOT covered by the study material, politely inform them: "This specific question is not covered in your uploaded material, but here is a brief general explanation:" and provide a short, helpful generic answer.
3. Be friendly, encouraging, and break down complex concepts to make them easy to learn.
4. Maintain a clean, professional layout.
5. STRICTLY avoid using asterisks (*) for bullet points or lists; use a dash (-) or a bullet symbol (•). You may use '**' for bolding.

Conversation History:
$conversation
user: $query
""";
    return await _ask(prompt);
  }

  /// Generate MCQs from notes
  Future<List<Map<String, dynamic>>> generateQuizFromNotes(String notes) async {
    final prompt = """
Generate exactly 5 multiple-choice quiz questions (MCQs) from the following notes:
$notes

Return the output STRICTLY as a JSON array, no explanations, no markdown.
Each object must look like this:
{
  "question": "string",
  "options": [
    {"text": "option A", "correct": false},
    {"text": "option B", "correct": true},
    {"text": "option C", "correct": false},
    {"text": "option D", "correct": false}
  ]
}
""";
    
    String result = await _ask(prompt);
    final jsonObj = tryExtractJson(result);
    
    if (jsonObj != null && jsonObj is List) {
       return List<Map<String, dynamic>>.from(jsonObj);
    }

    debugPrint("❌ Failed to parse quiz JSON. Raw text: $result");
    return [];
  }

  /// Validate correct option text
  Future<String> validateCorrectOption(String question, List<String> options) async {
    final prompt = "Here is a question: \"$question\" with options: ${options.join(", ")}. Return only the correct option text.";
    return await _ask(prompt);
  }

  /// Generate complex Study Plan
  Future<String> generateStudyPlan({
    required String goal,
    required String examDate,
    required String startDate,
    required List<String> selectedNotes,
    required int studyDaysPerWeek,
    required int hoursPerDay,
  }) async {
    final notesText = selectedNotes.join("\n");
    final prompt = """
You are a Study Planner AI. Create a detailed study plan based on the following inputs:

- Goal: $goal
- Exam Date: $examDate (YYYY-MM-DD)
- Start Date: $startDate (YYYY-MM-DD)
- Study Days Per Week: $studyDaysPerWeek
- Study Hours Per Day: $hoursPerDay
- Selected Notes: $notesText

Return the study plan **strictly in valid JSON only**, with no explanations, comments, or extra text. The JSON must have this exact structure:

{
  "goal": "<goal>",
  "examDate": "<examDate>",
  "startDate": "<startDate>",
  "studyDaysPerWeek": <int>,
  "studyHoursPerDay": <int>,
  "topics": [
    {
      "name": "<topic name>",
      "description": "<short description of topic>",
      "estimatedTime": <hours as number>,
      "assignedDays": ["YYYY-MM-DD", "YYYY-MM-DD", ...]
    }
  ],
  "studySchedule": [
    {
      "day": "YYYY-MM-DD",
      "topics": ["topic1", "topic2", ...],
      "hours": <total hours for the day>
    }
  ],
  "reminders": ["<reminder1>", "<reminder2>", ...]
}
""";

    return await _ask(prompt, endpoint: '/api/mentorai/study-plan');
  }

  /// Generate Topic Dependency Graph from a topic
  Future<Map<String, dynamic>> generateDependencyGraph(String topic) async {
    final prompt = """
You are a Curriculum Architect AI. Generates a Topic Dependency Graph focusing on the learning order (prerequisites) for the topic: "$topic".
Break it down into subtopics and sequential concepts.
Create edges strictly in a "Learn A before B" format (directed from prerequisite to the next topic).

STRICT INSTRUCTION: Return ONLY a valid JSON object. Do NOT include any introductory text, explanations, or conversational filler.
The JSON must have this exact structure:
{
  "nodes": [
    {"id": "1", "label": "Basic Concept"},
    {"id": "2", "label": "Advanced Concept"}
  ],
  "edges": [
    {"from": "1", "to": "2"}
  ]
}
Make sure 'id' is a string. Ensure the graph represents a chronological learning path.
""";

    String result = await _ask(prompt);
    final jsonObj = tryExtractJson(result);
    
    if (jsonObj != null && jsonObj is Map<String, dynamic>) {
       return jsonObj;
    }

    debugPrint("❌ Failed to extract valid JSON for Dependency Graph. Raw text: $result");
    return {"nodes": [], "edges": []};
  }

  /// Generate Mindmap data from text
  Future<Map<String, dynamic>> generateMindmap(String text) async {
    final prompt = """
You are a Mindmap AI. Analyze the following text and create a mindmap structure.
Extract the main topic and its subtopics, and define relationships (edges) between them.

STRICT INSTRUCTION: Return ONLY a valid JSON object. Do NOT include any introductory text, explanations, or conversational filler.
The JSON must have this exact structure:
{
  "nodes": [
    {"id": "1", "label": "Main Topic"},
    {"id": "2", "label": "Subtopic A"}
  ],
  "edges": [
    {"from": "1", "to": "2"}
  ]
}
Make sure 'id' is a string. Ensure the graph is logically connected like a tree.

Text to analyze:
$text
""";

    String result = await _ask(prompt);
    final jsonObj = tryExtractJson(result);
    
    if (jsonObj != null && jsonObj is Map<String, dynamic>) {
       return jsonObj;
    }

    debugPrint("❌ Failed to extract valid JSON for Mindmap. Raw text: $result");
    return {"nodes": [], "edges": []};
  }

  /// Breakdown Syllabus into a Roadmap
  Future<Map<String, dynamic>> breakdownSyllabus(String syllabusText) async {
    // Truncate text if it's too long to avoid payload issues
    final String truncatedText = syllabusText.length > 30000 
        ? "${syllabusText.substring(0, 30000)}... [Truncated for brevity]"
        : syllabusText;

    final prompt = """
You are an Elite Academic Advisor and Curriculum Specialist. Your mission is to decompose the following syllabus into a master-class level study roadmap.

Syllabus Text:
$truncatedText

Requirements:
1. **Strategic Overview**: Professional title, high-level summary, difficulty, and prerequisites.
2. **Day-wise Breakdown**: Organize into clear "Day X" or "Chapter X" milestones.
3. **Structured Content**: For each milestone, provide:
   - A clear **Learning Goal**.
   - **detailedTopics**: A list of objects, each containing:
     - `topicTitle`: Short, punchy name.
     - `explanation`: Clear, sufficient study material.
     - `example`: A real-time, practical example.
     - `formulaOrRule`: Any relevant formula, grammar rule, or key takeaway (optional).
   - **keyTerms**: Essential vocabulary.
   - **estimatedHours**.

Ensure the content is vibrant, easy to read, and formatted specifically for a modern mobile learning app.

STRICT INSTRUCTION: Return ONLY a valid JSON object. Do NOT include any introductory text, explanations, or conversational filler.
The JSON must have this exact structure:
{
  "title": "Master Roadmap Title",
  "description": "Short, professional summary.",
  "difficulty": "Intermediate",
  "prerequisites": ["Prereq 1"],
  "roadmap": [
    {
      "topic": "Day 1: Topic Name",
      "learningGoal": "Goal summary.",
      "estimatedHours": 2,
      "detailedTopics": [
        {
          "topicTitle": "Sub-topic 1",
          "explanation": "Detailed explanation...",
          "example": "Practical example...",
          "formulaOrRule": "Rule or Formula (if applicable)"
        }
      ],
      "keyTerms": ["Term 1"],
    }
  ],
  "studyTip": "A professional tip."
}
""";

    String result = await _ask(prompt);
    final jsonObj = tryExtractJson(result);
    
    if (jsonObj != null && jsonObj is Map<String, dynamic>) {
       return jsonObj;
    }

    debugPrint("❌ Failed to extract valid JSON for Syllabus Breakdown. Raw text: $result");
    return {"title": "Error", "roadmap": [], "totalEstimatedHours": 0};
  }

  /// 🧹 Notes Cleaner: Converts messy notes into structured study notes
  Future<String> cleanNotes(String messyNotes) async {
    final prompt = """
You are a Professional Note-Taking Expert. Your task is to transform the following messy, unorganized, or redundant notes into a clean, highly structured, and professional study document.

Messy Notes:
$messyNotes

Guidelines for Transformation:
1. **Clarity & Conciseness**: Remove all redundant words, irrelevant filler, and conversational fluff.
2. **Formatting (Clean View)**: 
   - Do NOT use symbols like #, ##, or * for emphasis or headers.
   - For **Headings**, use UPPERCASE text on a new line followed by a blank line.
   - For **Subheadings**, use Title Case text on a new line followed by a blank line.
   - Use bullet points (•) for lists.
3. **Structure**: 
   - Start with a clear Title in ALL CAPS.
   - Organize logically into sections with clear spacing between them.
   - Include a "KEY CONCEPTS" section at the end if applicable.
4. **Tone**: Maintain a professional, educational tone throughout.

STRICT INSTRUCTION: Do NOT include any introductory or concluding remarks. Provide ONLY the structured notes content.
""";

    String response = await _ask(prompt);
    // Extra safety: remove any stray hashes or asterisks the model might still produce
    return response.replaceAll('#', '').replaceAll('*', '').trim();
  }

  /// ✍️ Handwriting Optimizer: Refines messy OCR from handwritten notes
  Future<String> polishHandwritingOCR(String messyOcrText) async {
    final prompt = """
You are an expert at deciphering and organizing handwritten notes. The following text was extracted using OCR from a photo of handwritten notes. It likely contains many misread characters, spelling errors, and missing logical flow.

Messy OCR Text:
$messyOcrText

Your Mission:
1. **Decode & Correct**: Use the context to fix misread words and spelling errors.
2. **Structure**: Organize the corrected text into a clean, professional format.
3. **Format**: 
   - For **Headings**, use UPPERCASE text.
   - Use bullet points (•) for lists.
   - NO symbols like #, ##, or * should be used.
4. **Style**: If some parts are unintelligible, try to logically bridge them or focus on the clear parts to maintain useful information.

STRICT INSTRUCTION: Provide ONLY the corrected and structured notes. Do not include any meta-comments or introductory text.
""";

    String response = await _ask(prompt);
    return response.replaceAll('#', '').replaceAll('*', '').trim();
  }

  /// 📇 Flashcard Generator: Creates Q&A pairs from content
  Future<List<Map<String, String>>> generateFlashcards(String content, String difficulty) async {
    final prompt = """
You are an expert Educational Content Creator. Your task is to generate high-quality study flashcards from the provided content.

Content:
$content

Difficulty Level: $difficulty

Instructions:
1. **Q&A Pairs**: Create clear, concise question-answer pairs.
2. **Focus**: Target key concepts, definitions, formulas, and historical dates.
3. **Format**: Return ONLY a valid JSON array of objects. Each object must have "question" and "answer" keys.
4. **Quantity**: Aim for 5-10 cards depending on content depth.
5. **No Markup**: Do not include any introductory text or markdown code blocks (like ```json). Just the raw JSON.

Example Output:
[
  {"question": "What is Photosynthesis?", "answer": "The process by which plants use sunlight, water, and CO2 to create oxygen and energy in the form of sugar."},
  {"question": "Who discovered Penicillin?", "answer": "Alexander Fleming in 1928."}
]
""";

    String response = await _ask(prompt);
    final jsonObj = tryExtractJson(response);
    
    if (jsonObj != null && jsonObj is List) {
       return jsonObj.map((item) => {
        "question": (item["question"] ?? "").toString(),
        "answer": (item["answer"] ?? "").toString(),
      }).toList();
    }
    
    debugPrint('Flashcard generation parsing error. Raw response: $response');
    return [];
  }

  /// 📊 Quiz Analysis: Analyzes quiz performance and provides insights
  Future<Map<String, dynamic>> analyzeQuizPerformance({
    required List<Map<String, dynamic>> questions,
    required List<String> userAnswers,
  }) async {
    final performanceData = questions.asMap().entries.map((entry) {
      final idx = entry.key;
      final q = entry.value;
      final userAnswer = userAnswers[idx];
      return {
        "question": q["question"],
        "userAnswer": userAnswer,
        "correctAnswer": q["correctAnswer"],
        "isCorrect": userAnswer == q["correctAnswer"],
      };
    }).toList();

    final prompt = """
You are an Advanced Learning Strategist AI. Analyze the following quiz performance data and provide a concise, high-impact feedback report focused on improvement.

Quiz Data:
${jsonEncode(performanceData)}

Instructions:
1. **Mistake Analysis**: For each wrong answer, explain the core concept missed and provide a brief, helpful explanation.
2. **Key Weaknesses**: Identify the primary areas where the user struggled.
3. **Topics to Re-visit**: Identify 3-5 specific topics or subtopics for immediate review.
4. **Actionable Recommendations**: Provide sharp, actionable steps for improvement.

STRICT INSTRUCTION: Return ONLY a valid JSON object. Do NOT include any introductory text, explanations, or conversational filler.
The JSON must have this exact structure:
{
  "mistakeAnalysis": [
    {"question": "...", "conceptMissed": "...", "explanation": "..."}
  ],
  "weaknesses": ["topicA", "topicB"],
  "topicsToRevisit": ["Detailed topic 1", "Detailed topic 2"],
  "recommendations": ["Action step 1", "Action step 2"]
}
""";

    String result = await _ask(prompt);
    final jsonObj = tryExtractJson(result);
    
    if (jsonObj != null && jsonObj is Map<String, dynamic>) {
       return jsonObj;
    }

    debugPrint("❌ Failed to parse quiz JSON. Raw text: $result");
    return {
        "mistakeAnalysis": [],
        "weaknesses": [],
        "topicsToRevisit": ["Review your primary materials."],
        "recommendations": ["Review your incorrect answers for deeper understanding."]
      };
  }

  /// 👶 ELI5: Explain Like I'm 5 (Structured Upgrade)
  Future<Map<String, dynamic>> getELI5Explanation(String topic, String level) async {
    final prompt = """
Topic: "$topic"
Target Audience Level: $level

You are an expert educator. Explain the topic above in an "Explain Like I'm 5" style, but tailored to the requested technical level ($level).

STRUCTURE YOUR RESPONSE AS A VALID JSON OBJECT WITH THESE KEYS:
- "definition": A 1-sentence crystal clear definition.
- "explanation": A detailed but simple multi-paragraph explanation using analogies.
- "example": A relatable real-life example or scenario.
- "useCase": A practical use case of this concept in the real world.
- "imageRequired": (bool) true if an image would significantly help visualize this topic (e.g. for "Photosynthesis" or "Black Hole"), false if purely conceptual (e.g. "Patience").
- "imageSearchQuery": (string) If imageRequired is true, provide a 3-word descriptive search query for a high-quality educational image. Otherwise, leave empty.

IMPORTANT:
1. Return ONLY the JSON object. No other text.
2. Ensure the JSON is valid and escaped properly.
3. Use simple, engaging, and professional language.
4. For level Beginner: Use extremely simple analogies.
5. For level Intermediate/Advanced: Use correct terminology but explain it intuitively.
""";
    
    // We use the production Gemini endpoint which handles the model selection internally.
    final response = await _ask(prompt);
    final jsonObj = tryExtractJson(response);
    
    if (jsonObj != null && jsonObj is Map<String, dynamic>) {
       return jsonObj;
    }

    // Fallback in case of parsing error
    return {
      "definition": "Could not parse detailed response.",
      "explanation": response,
      "example": "N/A",
      "useCase": "N/A",
      "imageRequired": false,
      "imageSearchQuery": ""
    };
  }

  /// 🛠️ Robust JSON Extractor: Handles markdown and conversational filler
  dynamic tryExtractJson(String text) {
    if (text.isEmpty) return null;

    try {
      // 1. Fast Path: Direct parse
      String cleaned = text.trim();
      try {
        return jsonDecode(cleaned);
      } catch (_) {}

      // 2. Clean common markdown pollution
      cleaned = cleaned.replaceAll(RegExp(r'```(?:json)?', caseSensitive: false), '')
                       .replaceAll('```', '')
                       .trim();
      try {
        return jsonDecode(cleaned);
      } catch (_) {}

      // 3. Robust Fallback: Extract between first and last curly braces (Objects)
      int firstBrace = cleaned.indexOf('{');
      int lastBrace = cleaned.lastIndexOf('}');
      if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
        String possibleJson = cleaned.substring(firstBrace, lastBrace + 1);
        try {
          return jsonDecode(possibleJson);
        } catch (_) {}
      }

      // 4. Robust Fallback: Extract between first and last square brackets (Arrays)
      int firstBracket = cleaned.indexOf('[');
      int lastBracket = cleaned.lastIndexOf(']');
      if (firstBracket != -1 && lastBracket != -1 && lastBracket > firstBracket) {
        String possibleJson = cleaned.substring(firstBracket, lastBracket + 1);
        try {
          return jsonDecode(possibleJson);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint("❌ Error in tryExtractJson: $e");
    }
    
    return null;
  }

  String _getMimeType(String path) {
    if (path.toLowerCase().endsWith('.png'))  return 'image/png';
    if (path.toLowerCase().endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  /// 🎨 Generate Image via MentorAI API Server
  Future<String?> generateImage(String prompt, {File? referenceImage}) async {
    final url = Uri.parse('$_baseUrl/api/mentorai/generate-image');

    debugPrint('🖼️ Generating image for: $prompt');
    debugPrint('🔗 URL: $url');

    try {
      final Map<String, dynamic> body = {'prompt': prompt};

      if (referenceImage != null) {
        final bytes = await referenceImage.readAsBytes();
        body['image_base64'] = base64Encode(bytes);
        body['mime_type'] = _getMimeType(referenceImage.path);
      }

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': _accessKey,
        },
        body: jsonEncode(body),
      );

      debugPrint('📡 Status Code: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('✅ Response Received');
        
        if (data['total_tokens'] != null && data['total_tokens'] is num) {
          _lastEstimatedTokens = (data['total_tokens'] as num).toInt();
        }

        return data['result'] as String?; // Pure base64 string provided by proxy
      } else if (response.statusCode == 401) {
        debugPrint('❌ Unauthorized: Invalid API key');
      } else if (response.statusCode == 422) {
        debugPrint('❌ Blocked by safety filters');
      } else {
        debugPrint('❌ HTTP Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('🚨 Exception generating image: $e');
    }
    return null;
  }

  /// 📖 Get Word Meaning
  Future<String> getWordMeaning(String word) async {
    final prompt = "Provide a short and clear English meaning for the word: \"$word\". Only return the meaning, nothing else.";
    return await _ask(prompt);
  }

  /// 🧠 Explain Excerpt
  Future<String> getExcerptExplanation(String text) async {
    final prompt = """
Explain the following text snippet from a learning context in a simple and clear way. 
Focus on explaining any complex terms or concepts mentioned in this specific excerpt.

Excerpt:
"$text"

Guidelines:
1. Be concise but informative.
2. Use an encouraging, teacher-like tone.
3. If it's a single word, provide its definition and usage.
4. If it's a phrase, explain what it means in simple terms.
""";
    return await _ask(prompt);
  }

  /// 📝 Summarize Excerpt
  Future<String> getExcerptSummary(String text) async {
    final prompt = """
Provide a very brief summary of the following text snippet. 
Keep it under 30 words if possible.

Snippet:
"$text"
""";
    return await _ask(prompt, endpoint: '/api/mentorai/summarize');
  }
}

