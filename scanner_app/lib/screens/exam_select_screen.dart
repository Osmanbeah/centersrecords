import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/exam.dart';
import '../services/supabase_service.dart';
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
  final TextEditingController _assistantController = TextEditingController();
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
    final name = await SupabaseService.getAssistantName();
    final center = await SupabaseService.getSelectedCenter();
    setState(() {
      _assistantName = name;
      _assistantController.text = name;
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

  void _saveAssistantName() async {
    final name = _assistantController.text.trim();
    if (name.isNotEmpty) {
      await SupabaseService.setAssistantName(name);
      setState(() => _assistantName = name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حفظ اسم المساعد: $name', style: GoogleFonts.cairo()),
            backgroundColor: const Color(0xFF0F766E),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  List<Exam> get _filteredExams {
    if (_selectedCenter == 'All Centers') return _exams;
    return _exams.where((e) => e.center == _selectedCenter || e.center == 'All Centers').toList();
  }

  @override
  Widget build(BuildContext context) {
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
          // Assistant & Center Selector Card
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
                    const Icon(Icons.badge_outlined, color: Color(0xFF0F766E), size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _assistantController,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'اسم المساعد (Assistant)',
                          hintStyle: GoogleFonts.cairo(fontSize: 13, color: Colors.grey),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF0F766E), width: 1.5),
                          ),
                        ),
                        style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w600),
                        onSubmitted: (_) => _saveAssistantName(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _saveAssistantName,
                      child: Text('حفظ', style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Center filter
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, color: Color(0xFF64748B), size: 20),
                    const SizedBox(width: 8),
                    Text('السنتر:', style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF475569))),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 1,
                          ),
                          color: const Color(0xFFF1F5F9),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCenter,
                            isExpanded: true,
                            items: _centers.map((c) {
                              return DropdownMenuItem<String>(
                                value: c,
                                child: Text(c, style: GoogleFonts.cairo(fontSize: 13)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedCenter = val);
                                SupabaseService.setSelectedCenter(val);
                              }
                            },
                          ),
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
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openScanner(exam),
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
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 10),
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
                  Row(
                    children: [
                      Text(
                        'ابدأ المسح',
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F766E),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_ios, size: 12, color: Color(0xFF0F766E)),
                    ],
                  ),
                ],
              ),
            ],
          ),
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
          assistantName: _assistantName,
          centerName: _selectedCenter,
        ),
      ),
    );
  }
}
