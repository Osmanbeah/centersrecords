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

  static User? get currentUser => client.auth.currentUser;
  static String? get currentUserEmail => client.auth.currentUser?.email;
  static String get currentUserName {
    final metaName = client.auth.currentUser?.userMetadata?['name']?.toString();
    if (metaName != null && metaName.trim().isNotEmpty) {
      return metaName.trim();
    }
    final email = currentUserEmail;
    if (email != null && email.isNotEmpty) {
      return email.split('@')[0];
    }
    return 'Assistant';
  }

  static bool get isAdmin {
    final role = client.auth.currentUser?.userMetadata?['role']?.toString().toLowerCase();
    if (role == 'admin') return true;
    final email = currentUserEmail?.toLowerCase() ?? '';
    if (email.contains('admin') || email.contains('kelany')) return true;
    return false;
  }

  static Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  /// Checks whether a record belongs to the given assistant email or name.
  /// If admin, matches all.
  static bool matchesCurrentAssistant(
    String recordAssistantName, {
    String? targetEmail,
    String? targetName,
  }) {
    if (isAdmin) return true;
    final email = (targetEmail ?? currentUserEmail ?? '').trim().toLowerCase();
    final name = (targetName ?? currentUserName).trim().toLowerCase();
    final rec = recordAssistantName.trim().toLowerCase();
    if (rec.isEmpty) return false;
    if (email.isNotEmpty && (rec == email || rec.contains(email))) return true;
    if (name.isNotEmpty && (rec == name || rec.contains(name))) return true;
    return false;
  }

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
  /// If [forAssistantEmail] or [forAssistantName] is provided (and user is not admin),
  /// filters strictly to only that assistant's scanned papers.
  static Future<List<ExamResult>> fetchExamResults(
    String examId, {
    String? forAssistantEmail,
    String? forAssistantName,
  }) async {
    final emailFilter = forAssistantEmail ?? (isAdmin ? null : currentUserEmail);
    final nameFilter = forAssistantName ?? (isAdmin ? null : currentUserName);

    try {
      final List<dynamic> response = await client
          .from('exam_results')
          .select('*')
          .eq('exam_id', examId)
          .order('created_at', ascending: false);

      final allResults = response
          .map((item) => ExamResult.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();

      if (emailFilter == null || emailFilter.isEmpty || isAdmin) {
        return allResults;
      }

      return allResults.where((r) {
        return matchesCurrentAssistant(
          r.assistantName,
          targetEmail: emailFilter,
          targetName: nameFilter,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching exam results: $e');
    }

    // Fallback to local cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('local_results_$examId');
      if (cached != null) {
        final List list = jsonDecode(cached);
        final allResults = list
            .map((item) => ExamResult.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();

        if (emailFilter == null || emailFilter.isEmpty || isAdmin) {
          return allResults;
        }

        return allResults.where((r) {
          return matchesCurrentAssistant(
            r.assistantName,
            targetEmail: emailFilter,
            targetName: nameFilter,
          );
        }).toList();
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

  /// Update an existing exam result in Supabase and local cache
  static Future<bool> updateExamResult(ExamResult result) async {
    bool cloudSaved = false;
    try {
      if (result.id != null && result.id!.isNotEmpty) {
        await client
            .from('exam_results')
            .update(result.toJson())
            .eq('id', result.id!);
      } else {
        await client
            .from('exam_results')
            .update(result.toJson())
            .eq('exam_id', result.examId)
            .eq('student_code', result.studentCode);
      }
      cloudSaved = true;
    } catch (e) {
      debugPrint('Error updating exam result in Supabase: $e');
    }

    // Update local cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'local_results_${result.examId}';
      final cached = prefs.getString(key);
      if (cached != null) {
        final List list = jsonDecode(cached);
        final updatedList = list.map((item) {
          final res = ExamResult.fromJson(Map<String, dynamic>.from(item as Map));
          if ((result.id != null && res.id == result.id) ||
              (res.examId == result.examId && res.studentCode == result.studentCode)) {
            return result.toJson(includeId: true);
          }
          return item;
        }).toList();
        await prefs.setString(key, jsonEncode(updatedList));
      }
    } catch (_) {}

    return cloudSaved;
  }

  /// Delete an exam result from Supabase and local cache
  static Future<bool> deleteExamResult(String? id, String examId, String studentCode) async {
    bool cloudDeleted = false;
    try {
      if (id != null && id.isNotEmpty) {
        await client.from('exam_results').delete().eq('id', id);
      } else {
        await client
            .from('exam_results')
            .delete()
            .eq('exam_id', examId)
            .eq('student_code', studentCode);
      }
      cloudDeleted = true;
    } catch (e) {
      debugPrint('Error deleting exam result from Supabase: $e');
    }

    // Update local cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'local_results_$examId';
      final cached = prefs.getString(key);
      if (cached != null) {
        final List list = jsonDecode(cached);
        final filteredList = list.where((item) {
          final res = ExamResult.fromJson(Map<String, dynamic>.from(item as Map));
          if (id != null && res.id == id) return false;
          if (res.examId == examId && res.studentCode == studentCode) return false;
          return true;
        }).toList();
        await prefs.setString(key, jsonEncode(filteredList));
      }
    } catch (_) {}

    return cloudDeleted;
  }

  /// Persistent Assistant Profile
  static Future<Map<String, String>> getAssistantProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString('assistant_name') ?? '',
      'code': prefs.getString('assistant_code') ?? '',
      'phone': prefs.getString('assistant_phone') ?? '',
      'center': prefs.getString('selected_center') ?? 'All Centers',
    };
  }

  static Future<void> saveAssistantProfile({
    required String name,
    String code = '',
    String phone = '',
    String center = 'All Centers',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('assistant_name', name);
    await prefs.setString('assistant_code', code);
    await prefs.setString('assistant_phone', phone);
    await prefs.setString('selected_center', center);
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
