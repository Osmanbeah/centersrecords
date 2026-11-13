import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/exam.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://mwposurgahrcdexfvywa.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im13cG9zdXJnYWhyY2RleGZ2eXdhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE2NDE2NDAsImV4cCI6MjEwNzIxNzY0MH0.fxr7qxygr5Fl8urhcFWC1oYYqAxtYiObf5kNGnInPfk';

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      // ignore: deprecated_member_use
      anonKey: supabaseAnonKey,
    );
  }

  /// Fetch active exams from Supabase with offline fallback
  static Future<List<Exam>> fetchActiveExams() async {
    try {
      final List<dynamic> response = await client
          .from('exams')
          .select('*')
          .order('created_at', ascending: false);

      final exams = response
          .map((item) => Exam.fromJson(Map<String, dynamic>.from(item as Map)))
          .where((e) => e.status == 'active')
          .toList();

      // Save to offline cache
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_exams', jsonEncode(response));
      } catch (_) {}

      return exams;
    } catch (e) {
      debugPrint('Error fetching exams from Supabase: $e');
    }

    // Fallback to offline cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('cached_exams');
      if (cached != null) {
        final List list = jsonDecode(cached);
        return list
            .map((item) => Exam.fromJson(Map<String, dynamic>.from(item as Map)))
            .where((e) => e.status == 'active')
            .toList();
      }
    } catch (_) {}

    return [];
  }

  /// Fetch results for a specific exam
  static Future<List<ExamResult>> fetchExamResults(String examId) async {
    try {
      final List<dynamic> response = await client
          .from('exam_results')
          .select('*')
          .eq('exam_id', examId)
          .order('created_at', ascending: false);

      return response
          .map((item) => ExamResult.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (e) {
      debugPrint('Error fetching exam results: $e');
    }

    // Fallback to local cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('local_results_$examId');
      if (cached != null) {
        final List list = jsonDecode(cached);
        return list
            .map((item) => ExamResult.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      }
    } catch (_) {}

    return [];
  }

  /// Save exam result to Supabase and local cache
  static Future<bool> saveExamResult(ExamResult result) async {
    bool cloudSaved = false;
    try {
      await client.from('exam_results').insert([result.toJson()]);
      cloudSaved = true;
    } catch (e) {
      debugPrint('Error saving exam result to Supabase: $e');
    }

    // Always update local cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'local_results_${result.examId}';
      final cached = prefs.getString(key);
      List<dynamic> list = [];
      if (cached != null) {
        try {
          list = jsonDecode(cached);
        } catch (_) {}
      }
      list.insert(0, result.toJson());
      await prefs.setString(key, jsonEncode(list));
    } catch (_) {}

    return cloudSaved;
  }

  /// Persistent Assistant Name
  static Future<String> getAssistantName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('assistant_name') ?? 'Assistant';
  }

  static Future<void> setAssistantName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('assistant_name', name);
  }

  /// Persistent Center Filter
  static Future<String> getSelectedCenter() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('selected_center') ?? 'All Centers';
  }

  static Future<void> setSelectedCenter(String center) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_center', center);
  }
}
