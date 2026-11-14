import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/exam.dart';
import '../services/supabase_service.dart';
import 'scanner_screen.dart';
import 'student_detail_screen.dart';

class ExamResultsScreen extends StatefulWidget {
  final Exam exam;
  final String assistantName;
  final String centerName;

  const ExamResultsScreen({
    super.key,
    required this.exam,
    required this.assistantName,
    required this.centerName,
  });

  @override
  State<ExamResultsScreen> createState() => _ExamResultsScreenState();
}

class _ExamResultsScreenState extends State<ExamResultsScreen> {
  List<ExamResult> _results = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedModelFilter = 'All';
  String _selectedAssistantFilter = 'All';

  @override
  void initState() {
    super.initState();
    _fetchResults();
  }

  Future<void> _fetchResults() async {
    setState(() => _isLoading = true);
    final results = await SupabaseService.fetchExamResults(widget.exam.id);
    if (mounted) {
      setState(() {
        _results = results;
        _isLoading = false;
      });
    }
  }

  List<String> get _availableAssistants {
    final set = <String>{};
    for (final r in _results) {
      if (r.assistantName.isNotEmpty) {
        set.add(r.assistantName);
      }
    }
    return ['All', ...set];
  }

  List<ExamResult> get _filteredResults {
    return _results.where((r) {
      final matchesSearch = _searchQuery.isEmpty ||
          r.studentCode.contains(_searchQuery) ||
          r.studentName.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesModel = _selectedModelFilter == 'All' || r.model == _selectedModelFilter;
      final matchesAssistant = _selectedAssistantFilter == 'All' || r.assistantName == _selectedAssistantFilter;
      return matchesSearch && matchesModel && matchesAssistant;
    }).toList();
  }

  double get _averageScore {
    if (_results.isEmpty) return 0.0;
    final sum = _results.fold(0.0, (prev, r) => prev + r.totalScore);
    return sum / _results.length;
  }

  double get _maxScore {
    if (_results.isEmpty) return 0.0;
    return _results.map((r) => r.totalScore).reduce((a, b) => a > b ? a : b);
  }

  void _openScanner() async {
    final scanned = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ScannerScreen(
          exam: widget.exam,
          assistantName: widget.assistantName,
          centerName: widget.centerName,
        ),
      ),
    );
    if (scanned == true) {
      _fetchResults();
    }
  }

  void _openStudentDetail(ExamResult res) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => StudentDetailScreen(
          exam: widget.exam,
          initialResult: res,
          onResultUpdated: _fetchResults,
        ),
      ),
    );
    if (updated == true) {
      _fetchResults();
    }
  }

  Future<void> _shareWhatsApp(ExamResult res) async {
    final msg = '''🌟 *نتيجة اختبار مستر كيلاني* 🌟
👤 *اسم الطالب:* ${res.studentName}
🆔 *كود الطالب:* ${res.studentCode}
🏫 *السنتر:* ${res.center}
📝 *الامتحان:* ${widget.exam.title}
📋 *النموذج:* ${res.model}
📊 *الدرجة الكلية:* ${res.totalScore.toStringAsFixed(1)} / ${widget.exam.totalScore.toStringAsFixed(0)}
✅ *الاختيار من متعدد:* ${res.mcqScore.toStringAsFixed(1)}
✍️ *المقالي:* ${res.writtenScore.toStringAsFixed(1)}
👨‍🏫 *القائم بالرصد:* ${res.assistantName}
''';

    final uri = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(msg)}');
    final webUri = Uri.parse('https://api.whatsapp.com/send?text=${Uri.encodeComponent(msg)}');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredResults;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'سجل طلاب: ${widget.exam.title}',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
            ),
            Text(
              'استعراض وتعديل إجابات الـ MCQ والدرجات',
              style: GoogleFonts.cairo(fontSize: 11, color: Colors.white.withValues(alpha: 0.85)),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F766E),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'تحديث النتائج',
            onPressed: _fetchResults,
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Stats Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('إجمالي المرصود', '${_results.length} طالب', const Color(0xFF0F766E)),
                _buildStatItem('متوسط الدرجات', '${_averageScore.toStringAsFixed(1)} / ${widget.exam.totalScore.toStringAsFixed(0)}', const Color(0xFF0284C7)),
                _buildStatItem('أعلى درجة', '${_maxScore.toStringAsFixed(1)} / ${widget.exam.totalScore.toStringAsFixed(0)}', const Color(0xFF16A34A)),
              ],
            ),
          ),

          // 2. Search & Filter Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    decoration: InputDecoration(
                      hintText: 'بحث بكود الطالب أو اسمه...',
                      hintStyle: GoogleFonts.cairo(fontSize: 12, color: Colors.grey),
                      prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF0F766E)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    style: GoogleFonts.cairo(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          // 3. Filter Chips (Model & Assistant)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text('النموذج:', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                  const SizedBox(width: 6),
                  ...['All', ...widget.exam.models.keys].map((m) {
                    final isSel = _selectedModelFilter == m;
                    return Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: FilterChip(
                        label: Text(m == 'All' ? 'الكل' : m, style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold)),
                        selected: isSel,
                        selectedColor: const Color(0xFFCCFBF1),
                        checkmarkColor: const Color(0xFF0F766E),
                        onSelected: (_) => setState(() => _selectedModelFilter = m),
                      ),
                    );
                  }),
                  if (_availableAssistants.length > 2) ...[
                    const SizedBox(width: 12),
                    Text('المساعد:', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                    const SizedBox(width: 6),
                    ..._availableAssistants.map((ast) {
                      final isSel = _selectedAssistantFilter == ast;
                      return Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: FilterChip(
                          label: Text(ast == 'All' ? 'كل المساعدين' : ast, style: GoogleFonts.cairo(fontSize: 11)),
                          selected: isSel,
                          selectedColor: const Color(0xFFE0F2FE),
                          onSelected: (_) => setState(() => _selectedAssistantFilter = ast),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),

          // 4. Students Results List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F766E)))
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.people_outline, size: 54, color: Color(0xFF94A3B8)),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isEmpty ? 'لم يتم رصد أي طالب لهذا الامتحان حتى الآن' : 'لا يوجد طالب يطابق البحث',
                              style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F766E), foregroundColor: Colors.white),
                              onPressed: _openScanner,
                              icon: const Icon(Icons.camera_alt_outlined, size: 18),
                              label: Text('بدء مسح أول ورقة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final res = filtered[index];
                          return _buildStudentCard(res);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0F766E),
        foregroundColor: Colors.white,
        onPressed: _openScanner,
        icon: const Icon(Icons.camera_alt_outlined),
        label: Text('مسح ورقة جديدة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildStudentCard(ExamResult res) {
    final pct = widget.exam.totalScore > 0 ? (res.totalScore / widget.exam.totalScore) : 0.0;
    Color gradeColor = const Color(0xFF16A34A);
    if (pct < 0.50) {
      gradeColor = const Color(0xFFDC2626);
    } else if (pct < 0.75) {
      gradeColor = const Color(0xFFD97706);
    }

    final dateStr = res.createdAt.length >= 16
        ? res.createdAt.substring(0, 16).replaceAll('T', ' ')
        : res.createdAt;

    return Card(
      elevation: 0.8,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openStudentDetail(res),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  // Code Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      res.studentCode,
                      style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFF0F766E)),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Name & Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          res.studentName,
                          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF1E293B)),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('نموذج ${res.model}', style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF475569))),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'رصد: ${res.assistantName}',
                                style: GoogleFonts.cairo(fontSize: 11, color: const Color(0xFF64748B)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Total Grade
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${res.totalScore.toStringAsFixed(1)} / ${widget.exam.totalScore.toStringAsFixed(0)}',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 16, color: gradeColor),
                      ),
                      Text(
                        'MCQ: ${res.mcqScore.toStringAsFixed(1)}',
                        style: GoogleFonts.cairo(fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(dateStr, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                  Row(
                    children: [
                      InkWell(
                        onTap: () => _shareWhatsApp(res),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.share, size: 12, color: Color(0xFF15803D)),
                              const SizedBox(width: 4),
                              Text('واتساب', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF15803D))),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _openStudentDetail(res),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.edit_outlined, size: 12, color: Color(0xFF0369A1)),
                              const SizedBox(width: 4),
                              Text('تعديل الإجابات', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF0369A1))),
                            ],
                          ),
                        ),
                      ),
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

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.cairo(fontSize: 11, color: const Color(0xFF64748B))),
        const SizedBox(height: 2),
        Text(value, style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
