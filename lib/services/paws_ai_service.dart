import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/report_model.dart';
import '../config/secrets.dart'; // 🔐 Secure API key import

/// 🤖 Paws AI Service - Secured version with no exposed API keys
class PawsAIService {
  // 🔐 API key now loaded from secure secrets file
  static const String _geminiEndpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  bool _aiAvailable = true;
  DateTime? _quotaExceededUntil;
  int _requestCount = 0;

  final List<Map<String, String>> _conversationHistory = [];
  final Map<String, String> _exactMatchCache = {};

  PawsAIService() {
    debugPrint('✅ Gemini 2.5 Flash ready (API key secured)');
  }

  String? _normalizeLocation(String message) {
    final text = message.toLowerCase();

    final Map<String, List<String>> aliases = {
      'Academic Block 1': ['academic block 1', 'ab1', 'block 1', 'academic 1'],
      'Academic Block 2': ['academic block 2', 'ab2', 'block 2', 'academic 2'],
      'Academic Block 3': ['academic block 3', 'ab3', 'block 3', 'academic 3'],
      'Sports Complex': ['sports complex', 'sports area', 'stadium', 'ground'],
      'Main Canteen': ['main canteen', 'canteen', 'food court'],
      'Clock Tower': ['clock tower', 'clock', 'tower'],
    };

    for (final entry in aliases.entries) {
      for (final alias in entry.value) {
        if (text.contains(alias)) return entry.key;
      }
    }
    return null;
  }

  bool _containsLocationName(String message) {
    return _normalizeLocation(message) != null;
  }

  Future<String> chat({
    required String userMessage,
    required List<DogReport> recentReports,
    String? userLocation,
  }) async {
    final lowerMsg = userMessage.toLowerCase();

    if (_quotaExceededUntil != null &&
        DateTime.now().isBefore(_quotaExceededUntil!)) {
      final remaining = _quotaExceededUntil!.difference(DateTime.now());
      debugPrint('⏳ Quota cooldown: ${remaining.inSeconds}s remaining');
      return _getSmartFallback(userMessage, recentReports);
    }

    if (_exactMatchCache.containsKey(lowerMsg)) {
      debugPrint('💾 Cache hit!');
      final cached = _exactMatchCache[lowerMsg]!;
      _addToHistory(userMessage, cached);
      return cached;
    }

    String? patternResponse;

    if (_containsAny(lowerMsg, ['hello', 'hi', 'hey']) &&
        lowerMsg.split(' ').length <= 3) {
      patternResponse = _getGreeting();
    } else if (_containsAny(lowerMsg, ['thank'])) {
      patternResponse = 'You\'re welcome! 🐾 Happy to help keep campus safe.';
    } else if (_containsAny(lowerMsg, ['fact'])) {
      patternResponse = _getRandomDogFact();
    } else if (_containsAny(lowerMsg, ['approach', 'coming'])) {
      patternResponse = _getApproachingTips();
    } else if (_containsAny(lowerMsg, ['safe', 'tips'])) {
      patternResponse = _getSafetyTips();
    } else if (_containsAny(lowerMsg, ['feed', 'food'])) {
      patternResponse = _getFeedingInfo();
    } else if (_containsAny(lowerMsg, ['how are you', 'whats up'])) {
      patternResponse = 'I\'m doing great! Ready to help keep campus safe 🐾';
    }

    if (patternResponse != null) {
      _exactMatchCache[lowerMsg] = patternResponse;
      _addToHistory(userMessage, patternResponse);
      debugPrint('✅ Pattern match (no API call)');
      return patternResponse;
    }

    if (_isFollowUpQuestion(lowerMsg) || _containsLocationName(lowerMsg)) {
      final response = await _getAIResponse(userMessage, recentReports);
      _addToHistory(userMessage, response);
      return response;
    }

    final aiResponse = await _getAIResponse(userMessage, recentReports);
    _addToHistory(userMessage, aiResponse);
    return aiResponse;
  }

  bool _isFollowUpQuestion(String message) {
    return ['it', 'that', 'they', 'also', 'what about'].any(message.contains) &&
        _conversationHistory.isNotEmpty;
  }

  Future<String> _getAIResponse(
      String userMessage, List<DogReport> reports) async {
    if (!_aiAvailable) {
      return _getSmartFallback(userMessage, reports);
    }

    try {
      _requestCount++;
      debugPrint('📊 API Request #$_requestCount');

      final normalizedLocation = _normalizeLocation(userMessage);

      final locationReports = normalizedLocation == null
          ? <DogReport>[]
          : reports
              .where((r) =>
                  r.location.toLowerCase() == normalizedLocation.toLowerCase())
              .toList();

      final context = _buildDetailedContextFromReports(locationReports);

      // Enhanced prompt for better, complete responses
      final prompt = '''You are Paws 🐾, a friendly campus safety AI assistant.

User question: "$userMessage"

Campus location asked about: ${normalizedLocation ?? 'General question'}

Recent dog reports for this location:
$context

Instructions:
- Provide a complete, helpful answer (3-5 sentences)
- Include specific safety advice when relevant
- Be friendly and reassuring
- Always finish your thoughts completely
- Don't cut off mid-sentence

Answer the user's question thoroughly:''';

      debugPrint('📤 Calling Gemini 2.5 Flash...');

      // 🔐 Using secure API key from secrets file
      final response = await http.post(
        Uri.parse('$_geminiEndpoint?key=${Secrets.geminiApiKey}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": prompt}
              ]
            }
          ],
          "generationConfig": {
            "temperature": 0.7,
            "maxOutputTokens": 800,
            "topP": 0.9,
            "topK": 40,
            "stopSequences": [],
          }
        }),
      );

      debugPrint('📥 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['candidates'] != null &&
            data['candidates'].isNotEmpty &&
            data['candidates'][0]['content'] != null &&
            data['candidates'][0]['content']['parts'] != null &&
            data['candidates'][0]['content']['parts'].isNotEmpty) {
          final text =
              data['candidates'][0]['content']['parts'][0]['text'] as String;

          debugPrint('✅ AI response received (${text.length} chars)');
          debugPrint('📝 Full response: $text');

          // Check if response seems truncated and handle it
          if (text.length < 50 || !_isCompleteSentence(text)) {
            debugPrint('⚠️ Response seems incomplete, using enhanced fallback');
            return _getSmartFallback(userMessage, reports);
          }

          _exactMatchCache[userMessage.toLowerCase()] = text;

          return text.trim();
        } else {
          debugPrint('⚠️ Unexpected response structure');
          return _getSmartFallback(userMessage, reports);
        }
      } else if (response.statusCode == 429) {
        debugPrint('❌ Quota exceeded!');
        final data = jsonDecode(response.body);

        try {
          final details = data['error']['details'] as List;
          final retryInfo = details.firstWhere(
            (d) => d['@type']?.toString().contains('RetryInfo') ?? false,
            orElse: () => null,
          );

          if (retryInfo != null) {
            final retryDelay = retryInfo['retryDelay'] as String;
            final seconds =
                int.parse(retryDelay.replaceAll(RegExp(r'[^0-9]'), ''));
            _quotaExceededUntil =
                DateTime.now().add(Duration(seconds: seconds));
            debugPrint('⏳ Cooldown: $seconds seconds');
          }
        } catch (e) {
          _quotaExceededUntil = DateTime.now().add(const Duration(minutes: 1));
        }

        return _getSmartFallback(userMessage, reports);
      } else if (response.statusCode == 403) {
        debugPrint('❌ API key invalid or API not enabled');
        _aiAvailable = false;
        return _getSmartFallback(userMessage, reports);
      } else if (response.statusCode == 404) {
        debugPrint('❌ Model not found');
        _aiAvailable = false;
        return _getSmartFallback(userMessage, reports);
      }

      debugPrint('❌ Error ${response.statusCode}');
      return _getSmartFallback(userMessage, reports);
    } catch (e) {
      debugPrint('❌ Exception: $e');
      return _getSmartFallback(userMessage, reports);
    }
  }

  // Check if text ends with proper sentence termination
  bool _isCompleteSentence(String text) {
    final trimmed = text.trim();
    return trimmed.endsWith('.') ||
        trimmed.endsWith('!') ||
        trimmed.endsWith('?') ||
        trimmed.endsWith('🐾');
  }

  void _addToHistory(String user, String paws) {
    _conversationHistory.insert(0, {'user': user, 'paws': paws});
    if (_conversationHistory.length > 10) {
      _conversationHistory.removeLast();
    }
  }

  bool _containsAny(String text, List<String> words) =>
      words.any(text.contains);

  String _getGreeting() =>
      'Hey there! 🐾 I\'m Paws, your campus safety buddy. Ask me about dog locations, safety tips, or anything campus-related!';

  String _getRandomDogFact() {
    final facts = [
      'Dogs remember friendly students and calm behavior! They can recognize you even weeks later. Stay calm and they\'ll remember you as a friend 🐕',
      'Campus dogs can recognize regular faces and friendly voices. They learn the routes students take and adapt their behavior accordingly 🐾',
      'Dogs understand body language better than words. Your posture and movements tell them more about your intentions than what you say 🐕',
      'A calm, confident posture helps dogs feel safe around you. Stand tall but relaxed, and they\'ll sense you\'re not a threat 🐾',
      'Dogs remember people who feed them and are kind to them. Consistency in feeding times helps build trust with campus dogs 🐕',
    ];
    return facts[DateTime.now().millisecond % facts.length];
  }

  String _getSafetyTips() =>
      'Here are key safety tips: Stay calm and breathe normally, avoid direct eye contact (it can seem threatening), give dogs plenty of space (at least 6 feet), never run away (triggers chase instinct), and speak softly if you need to. Remember, most dogs are just curious! 🐾';

  String _getApproachingTips() =>
      'If a dog approaches you: Stand completely still like a tree, look away to the side (not at the dog), keep your arms at your sides or crossed, and back away very slowly if needed. Never turn your back suddenly - move sideways instead. The dog will likely lose interest and move on 🐾';

  String _getFeedingInfo() =>
      'Check the Feeding tab to see which locations need help today! Regular feeding helps keep campus dogs calm and healthy. You can also see feeding schedules and volunteer opportunities there 🍖';

  /// Enhanced fallback system with contextual responses
  String _getSmartFallback(String message, List<DogReport> reports) {
    final lowerMsg = message.toLowerCase();

    // Location-specific queries
    final location = _normalizeLocation(message);
    if (location != null) {
      final locationReports = reports
          .where((r) => r.location.toLowerCase() == location.toLowerCase())
          .toList();

      if (locationReports.isNotEmpty) {
        final totalDogs =
            locationReports.fold<int>(0, (total, r) => total + r.dogCount);
        final latestCondition = locationReports.first.condition;
        final latestReport = locationReports.first;

        // Enhanced location report with time info
        final dynamic timestampData = latestReport.timestamp;
        final DateTime timestamp = timestampData is Timestamp
            ? timestampData.toDate()
            : timestampData as DateTime;
        final timeAgo = DateTime.now().difference(timestamp);
        final timeStr = timeAgo.inHours > 0
            ? '${timeAgo.inHours} hours ago'
            : '${timeAgo.inMinutes} minutes ago';

        String advice = '';
        if (latestCondition.toLowerCase().contains('aggressive')) {
          advice =
              ' I recommend taking an alternate route if possible, or waiting a few minutes before passing through.';
        } else if (latestCondition.toLowerCase().contains('calm')) {
          advice =
              ' The dogs seem calm, but still maintain awareness and give them space.';
        } else {
          advice = ' Exercise normal caution when passing through.';
        }

        return 'At $location, there are $totalDogs dogs reported recently (last report: $timeStr). Latest condition: $latestCondition.$advice Stay safe! 🐾';
      } else {
        return '$location appears calm right now with no recent dog reports. This doesn\'t mean there are no dogs there, so stay alert and follow basic safety guidelines. Let us know if you see any dogs by submitting a report! 🐾';
      }
    }

    // Behavior and safety queries
    if (_containsAny(lowerMsg, ['aggressive', 'angry', 'barking', 'growl'])) {
      return 'If you encounter aggressive dogs: Don\'t run or make sudden movements, avoid eye contact, stand sideways to appear smaller, back away slowly, and use a firm voice to say "no" or "stay". If available, place something between you and the dog (bag, jacket). Report aggressive behavior immediately! 🐾';
    }

    if (_containsAny(lowerMsg, ['bite', 'attack', 'emergency'])) {
      return 'In case of a dog bite: Immediately wash the wound with soap and water, seek medical attention right away, report the incident to campus security, and document the location and time. Your safety is the top priority. Campus health services can help with proper treatment 🐾';
    }

    if (_containsAny(lowerMsg, ['safe', 'safety', 'dangerous', 'avoid'])) {
      return _getSafetyTips();
    }

    if (_containsAny(lowerMsg, ['feed', 'food', 'feeding', 'hungry'])) {
      return _getFeedingInfo();
    }

    if (_containsAny(lowerMsg, ['approach', 'coming', 'towards'])) {
      return _getApproachingTips();
    }

    if (_containsAny(lowerMsg, ['report', 'submit', 'tell'])) {
      return 'To report a dog sighting, tap the "Report" button on the home screen. Include the location, number of dogs, and their behavior. This helps keep everyone safe and informed! Your reports make a real difference 🐾';
    }

    if (_containsAny(lowerMsg, ['help', 'what can', 'how to'])) {
      return 'I can help you with several things: Check dog locations and safety status, provide safety tips for encountering dogs, share feeding information and schedules, answer questions about dog behavior, and guide you on reporting sightings. What would you like to know? 🐾';
    }

    if (_containsAny(lowerMsg, ['where', 'location', 'which'])) {
      final hasReports = reports.isNotEmpty;
      if (hasReports) {
        final locations = reports.map((r) => r.location).toSet().toList();
        final locationList = locations.take(3).join(', ');
        return 'Recent reports show dog activity at: $locationList. Check the map for detailed locations and current status. You can also ask about specific locations like "Is Academic Block 1 safe?" 🐾';
      }
      return 'No recent reports available right now. This could mean the campus is calm! You can still check specific locations by asking "Is [location name] safe?" or submit a report if you see any dogs 🐾';
    }

    // General fallback with helpful guidance
    return 'I can help with location safety info, dog behavior tips, feeding schedules, and campus guidance. Try asking: "Is [location] safe?", "What should I do if a dog approaches?", "Tell me a dog fact", or "Where are the dogs today?" Feel free to ask anything about staying safe on campus! 🐾';
  }

  String _buildDetailedContextFromReports(List<DogReport> reports) {
    if (reports.isEmpty) return 'No recent reports at this location.';

    return reports.map((r) {
      final dynamic timestampData = r.timestamp;
      final DateTime timestamp = timestampData is Timestamp
          ? timestampData.toDate()
          : timestampData as DateTime;

      final timeAgo = DateTime.now().difference(timestamp);
      final timeStr = timeAgo.inHours > 0
          ? '${timeAgo.inHours}h ago'
          : '${timeAgo.inMinutes}m ago';
      return '- ${r.dogCount} dogs (${r.condition}) reported $timeStr';
    }).join('\n');
  }

  void clearHistory() {
    _conversationHistory.clear();
    _exactMatchCache.clear();
    _quotaExceededUntil = null;
    _requestCount = 0;
    debugPrint('🔄 AI service reset');
  }
}
