import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/exam.dart';
import '../services/supabase_service.dart';
import 'exam_results_screen.dart';
import 'login_screen.dart';
import 'scanner_screen.dart';

class ExamSelectScreen extends StatefulWidget {
  const ExamSelectScreen({super.key});

  @override
  State<ExamSelectScreen> createState() => _ExamSelectScreenState();
}

class _ExamSelectScreenState extends State<ExamSelectScreen> {
  List<Exam> _exams = [];
  bool _isLoading = true;
  String _assistantName = 'Assistant';
  String _assistantEmail = '';
  String _selectedCenter = 'All Centers';

  final List<String> _centers = [
    'All Centers',
    'Center 1',
    'Center 2',
    'Center 3',
    'El Tagamoa',
    'Nasr City',
    'Maadi',
    'Dokki',
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final user = SupabaseService.currentUser;
    if (user == null) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
      return;
    }

    final email = SupabaseService.currentUserEmail ?? '';
    final name = SupabaseService.currentUserName;
    final center = await SupabaseService.getSelectedCenter();

    setState(() {
      _assistantName = name;
      _assistantEmail = email;
      _selectedCenter = center;
    });

    await _refreshExams();
  }

  Future<void> _refreshExams() async {
    setState(() => _isLoading = true);
    final exams = await SupabaseService.fetchActiveExams();
    if (mounted) {
      setState(() {
        _exams = exams;
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.logout, color: Color(0xFFDC2626)),
            const SizedBox(width: 8),
            Text('تسجيل الخروج', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'هل تريد بالتأكيد تسجيل الخروج من حساب $_assistantEmail؟\n\nلن تفقد درجاتك السابقة، ويمكنك الدخول في أي وقت.',
          style: GoogleFonts.cairo(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('خروج', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await SupabaseService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  void _showCenterSelectDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.location_on_outlined, color: Color(0xFF0F766E)),
            const SizedBox(width: 8),
            Text('تحديد السنتر النشط', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _centers.map((c) {
              final isSelected = _selectedCenter == c;
              return ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                tileColor: isSelected ? const Color(0xFFCCFBF1) : null,
                title: Text(
                  c == 'All Centers' ? 'كل السناتر (All Centers)' : c,
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? const Color(0xFF0F766E) : const Color(0xFF1E293B),
                  ),
                ),
                trailing: isSelected ? const Icon(Icons.check_circle, color: Color(0xFF0F766E)) : null,
                onTap: () async {
                  await SupabaseService.setSelectedCenter(c);
                  setState(() => _selectedCenter = c);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  List<Exam> get _filteredExams {
    if (_selectedCenter == 'All Centers') return _exams;
    return _exams.where((e) => e.center == _selectedCenter || e.center == 'All Centers').toList();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = SupabaseService.isAdmin;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kelany OMR Scanner',
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold,
                fontSize: 19,
                color: Colors.white,
              ),
            ),
            Text(
              'نظام التصحيح الذكي فائق الدقة',
              style: GoogleFonts.cairo(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F766E),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'تحديث الامتحانات',
            onPressed: _refreshExams,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'تسجيل الخروج',
            onPressed: _confirmSignOut,
          ),
        ],
      ),
      body: Column(
        children: [
          // Assistant Account Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: isAdmin ? const Color(0xFF7C3AED) : const Color(0xFF0F766E),
                      child: Text(
                        _assistantName.isNotEmpty ? _assistantName.characters.first : 'A',
                        style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  _assistantName,
                                  style: GoogleFonts.cairo(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0F172A),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isAdmin ? const Color(0xFFF3E8FF) : const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isAdmin ? 'مسؤول (Admin)' : 'مساعد معتمد',
                                  style: GoogleFonts.cairo(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isAdmin ? const Color(0xFF6B21A8) : const Color(0xFF15803D),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            _assistantEmail.isNotEmpty ? _assistantEmail : 'مسجل الدخول',
                            style: GoogleFonts.cairo(fontSize: 11, color: const Color(0xFF64748B)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Change active center button
                    InkWell(
                      onTap: _showCenterSelectDialog,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on, size: 14, color: Color(0xFF0F766E)),
                            const SizedBox(width: 4),
                            Text(
                              _selectedCenter == 'All Centers' ? 'كل السناتر' : _selectedCenter,
                              style: GoogleFonts.cairo(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF334155),
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down, size: 16, color: Color(0xFF64748B)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Exams List Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'الامتحانات المتاحة للرصد (${_filteredExams.length})',
                  style: GoogleFonts.cairo(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                if (_isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F766E)),
                  ),
              ],
            ),
          ),

          // Exams List
          Expanded(
            child: _isLoading && _exams.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF0F766E)),
                  )
                : _filteredExams.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.assignment_outlined, size: 56, color: Color(0xFF94A3B8)),
                            const SizedBox(height: 12),
                            Text(
                              'لا توجد امتحانات نشطة حالياً',
                              style: GoogleFonts.cairo(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'أنشئ امتحاناً جديداً من لوحة تحكم المستر',
                              style: GoogleFonts.cairo(
                                fontSize: 13,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: _refreshExams,
                              icon: const Icon(Icons.refresh, size: 18),
                              label: Text('إعادة المحاولة', style: GoogleFonts.cairo()),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _refreshExams,
                        color: const Color(0xFF0F766E),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          itemCount: _filteredExams.length,
                          itemBuilder: (context, index) {
                            final exam = _filteredExams[index];
                            return _buildExamCard(exam);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamCard(Exam exam) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.description, color: Color(0xFF0284C7), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exam.title,
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      if (exam.subject.isNotEmpty)
                        Text(
                          exam.subject,
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Text(
                    '${exam.questionCount} سؤال',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF047857),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star_outline, size: 16, color: Color(0xFFD97706)),
                    const SizedBox(width: 4),
                    Text(
                      'الدرجة: ${exam.totalScore.toStringAsFixed(0)}',
                      style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                    ),
                  ],
                ),
                if (exam.models.isNotEmpty)
                  Text(
                    'النماذج: ${exam.models.keys.join(', ')}',
                    style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),

            // Two Action Buttons: Scan vs View Results & Edit MCQs
            Row(
              children: [
                // 1. View Results & Edit MCQs
                Expanded(
                  flex: 5,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0284C7),
                      side: const BorderSide(color: Color(0xFF0284C7), width: 1.2),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _openResults(exam),
                    icon: const Icon(Icons.people_alt_outlined, size: 18),
                    label: Text(
                      'النتائج والطلاب',
                      style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // 2. Start Scanner
                Expanded(
                  flex: 6,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 1,
                    ),
                    onPressed: () => _openScanner(exam),
                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    label: Text(
                      'بدء المسح OMR',
                      style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openScanner(Exam exam) {
    final effectiveAssistant = _assistantEmail.isNotEmpty ? _assistantEmail : _assistantName;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScannerScreen(
          exam: exam,
          assistantName: effectiveAssistant,
          centerName: _selectedCenter,
        ),
      ),
    );
  }

  void _openResults(Exam exam) {
    final effectiveAssistant = _assistantEmail.isNotEmpty ? _assistantEmail : _assistantName;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExamResultsScreen(
          exam: exam,
          assistantName: effectiveAssistant,
          centerName: _selectedCenter,
        ),
      ),
    );
  }
}
