import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/exam.dart';
import '../services/supabase_service.dart';
import 'exam_results_screen.dart';
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
  String _assistantCode = '';
  String _assistantPhone = '';
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
    final profile = await SupabaseService.getAssistantProfile();
    final name = profile['name'] ?? '';
    final code = profile['code'] ?? '';
    final phone = profile['phone'] ?? '';
    final center = profile['center'] ?? 'All Centers';

    setState(() {
      _assistantName = name.isNotEmpty ? name : 'Assistant';
      _assistantCode = code;
      _assistantPhone = phone;
      _selectedCenter = center;
    });

    await _refreshExams();

    // Auto-prompt to link account on first open if still default
    if (mounted && (name.isEmpty || name == 'Assistant')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showAssistantLinkingDialog();
      });
    }
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

  void _showAssistantLinkingDialog() {
    final nameCtrl = TextEditingController(text: _assistantName != 'Assistant' ? _assistantName : '');
    final codeCtrl = TextEditingController(text: _assistantCode);
    final phoneCtrl = TextEditingController(text: _assistantPhone);
    String dialogCenter = _selectedCenter;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_pin_outlined, color: Color(0xFF0F766E), size: 24),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'ربط التطبيق بحساب المساعد',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'لتسجيل كل ورقة باسم المساعد الذي قام بتصحيحها ورصدها:',
                  style: GoogleFonts.cairo(fontSize: 12, color: const Color(0xFF64748B)),
                ),
                const SizedBox(height: 14),

                // Assistant Name
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'اسم المساعد الكامل *',
                    labelStyle: GoogleFonts.cairo(fontSize: 13),
                    hintText: 'مثال: أحمد رجب',
                    hintStyle: GoogleFonts.cairo(fontSize: 12, color: Colors.grey),
                    prefixIcon: const Icon(Icons.person, size: 20, color: Color(0xFF0F766E)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    isDense: true,
                  ),
                  style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                // Assistant Code / ID
                TextField(
                  controller: codeCtrl,
                  decoration: InputDecoration(
                    labelText: 'كود المساعد (Assistant ID)',
                    labelStyle: GoogleFonts.cairo(fontSize: 13),
                    hintText: 'مثال: AST-01',
                    hintStyle: GoogleFonts.cairo(fontSize: 12, color: Colors.grey),
                    prefixIcon: const Icon(Icons.tag, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    isDense: true,
                  ),
                  style: GoogleFonts.cairo(fontSize: 13),
                ),
                const SizedBox(height: 12),

                // Assistant Phone
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'رقم الهاتف (اختياري)',
                    labelStyle: GoogleFonts.cairo(fontSize: 13),
                    hintText: '010XXXXXXXX',
                    hintStyle: GoogleFonts.cairo(fontSize: 12, color: Colors.grey),
                    prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    isDense: true,
                  ),
                  style: GoogleFonts.cairo(fontSize: 13),
                ),
                const SizedBox(height: 12),

                // Center dropdown
                Text('السنتر المخصص له:', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF475569))),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                    color: const Color(0xFFF8FAFC),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: dialogCenter,
                      isExpanded: true,
                      items: _centers.map((c) {
                        return DropdownMenuItem<String>(
                          value: c,
                          child: Text(c, style: GoogleFonts.cairo(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => dialogCenter = val);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (_assistantName.isNotEmpty && _assistantName != 'Assistant')
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey)),
              ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('يرجى كتابة اسم المساعد', style: GoogleFonts.cairo()), backgroundColor: Colors.red),
                  );
                  return;
                }

                final code = codeCtrl.text.trim();
                final phone = phoneCtrl.text.trim();

                await SupabaseService.saveAssistantProfile(
                  name: name,
                  code: code,
                  phone: phone,
                  center: dialogCenter,
                );

                setState(() {
                  _assistantName = name;
                  _assistantCode = code;
                  _assistantPhone = phone;
                  _selectedCenter = dialogCenter;
                });

                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('تم ربط حساب المساعد بهذا الجهاز بنجاح! 🟢', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                      backgroundColor: const Color(0xFF0F766E),
                    ),
                  );
                }
              },
              child: Text('ربط وتأكيد الحساب', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
            ),
          ],
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
    final isLinked = _assistantName.isNotEmpty && _assistantName != 'Assistant';

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
        ],
      ),
      body: Column(
        children: [
          // Assistant Account Linked Card
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
                      backgroundColor: isLinked ? const Color(0xFF0F766E) : Colors.amber.shade700,
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
                              Text(
                                isLinked ? _assistantName : 'لم يتم ربط حساب مساعد',
                                style: GoogleFonts.cairo(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isLinked ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isLinked ? 'حساب معتمد' : 'غير مرتبط',
                                  style: GoogleFonts.cairo(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isLinked ? const Color(0xFF15803D) : const Color(0xFFB45309),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            _assistantCode.isNotEmpty
                                ? 'كود: $_assistantCode • السنتر: $_selectedCenter'
                                : 'السنتر المعتمد: $_selectedCenter',
                            style: GoogleFonts.cairo(fontSize: 12, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0F766E),
                        side: const BorderSide(color: Color(0xFF0F766E)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _showAssistantLinkingDialog,
                      icon: const Icon(Icons.badge_outlined, size: 16),
                      label: Text('تعديل', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold)),
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScannerScreen(
          exam: exam,
          assistantName: _assistantCode.isNotEmpty ? '$_assistantName ($_assistantCode)' : _assistantName,
          centerName: _selectedCenter,
        ),
      ),
    );
  }

  void _openResults(Exam exam) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExamResultsScreen(
          exam: exam,
          assistantName: _assistantCode.isNotEmpty ? '$_assistantName ($_assistantCode)' : _assistantName,
          centerName: _selectedCenter,
        ),
      ),
    );
  }
}
