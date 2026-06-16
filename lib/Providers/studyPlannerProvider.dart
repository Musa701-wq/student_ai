// lib/providers/studyPlannerProvider.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/geminiService.dart';
import '../services/Firestore_service.dart';
import '../services/creditService.dart';
import 'dart:convert';

class StudyPlannerProvider with ChangeNotifier {
  final GeminiService geminiService;
  final _creditsService = CreditsService();
  FirestoreService firestoreService = FirestoreService();

  bool isLoading = false;
  String? studyPlan;
  String? error;

  StudyPlannerProvider({required this.geminiService});

  Future<void> generatePlan({
    required String goal,
    required String examDate,
    required String startDate,
    required List<String> selectedNotes,
    required int studyDaysPerWeek,
    required int hoursPerDay,
  }) async {
    try {
      isLoading = true;
      error = null;
      notifyListeners();

      studyPlan = await geminiService.generateStudyPlan(
        goal: goal,
        examDate: examDate,
        startDate: startDate,
        selectedNotes: selectedNotes,
        studyDaysPerWeek: studyDaysPerWeek,
        hoursPerDay: hoursPerDay,
      );

      // ─── Dynamic credit deduction based on token usage ─────────────────
      final tokens = geminiService.lastEstimatedTokens;
      final cost = CreditsService.calcCreditsFromTokens(tokens);
      await _creditsService.deductCredits(cost);
      debugPrint('💳 StudyPlan: deducted $cost credits ($tokens tokens)');

      // Save to Firestore
      await firestoreService.saveStudyPlan({
        "goal": goal,
        "examDate": examDate,
        "startDate": startDate,
        "selectedNotes": selectedNotes,
        "studyDaysPerWeek": studyDaysPerWeek,
        "hoursPerDay": hoursPerDay,
        "plan": studyPlan,
        "createdAt": DateTime.now().toIso8601String(),
        "uid": FirebaseAuth.instance.currentUser?.uid,
      });

    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Map<String, dynamic>? parsePlan(String rawPlan) {
    final jsonObj = geminiService.tryExtractJson(rawPlan);
    if (jsonObj != null && jsonObj is Map<String, dynamic>) {
       return jsonObj;
    }
    return null;
  }

}
