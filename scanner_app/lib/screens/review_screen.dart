import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:url_launcher/url_launcher.dart';
import '../models/exam.dart';
import '../services/omr_engine.dart';
import '../services/supabase_service.dart';

class ReviewScreen extends StatefulWidget {
  final Exam exam;
  final OMRScanResult scanResult;
  final Uint8List originalBytes;
  final String assistantName;
  final String centerName;

  const ReviewScreen({
    super.key,
    required this.exam,
    required this.scanResult,
    required this.originalBytes,
    required this.assistantName,
    required this.centerName,
  });

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late TextEditingController _studentCodeController;
  late TextEditingController _studentNameController;
  String? _selectedModel;
  late double _writtenScore;
  late Map<int, String?> _answers;
  late Map<int, QuestionState> _states;
  bool _isSaving = false;
  Uint8List? _annotatedPngBytes;
  bool _showOriginal = false;

  @override
  void initState() {
    super.initState();
    _studentCodeController = TextEditingController(text: widget.scanResult.studentCode);
    _studentNameController = TextEditingController();

    // If model was detected by engine, pre-select it; otherwise leave null so user MUST choose
    if (widget.scanResult.modelDetected) {
      final availModels = widget.exam.models.keys.toList();
      if (availModels.contains(widget.scanResult.model)) {
        _selectedModel = widget.scanResult.model;
      } else if (availModels.isNotEmpty) {
        _selectedModel = availModels.first;
      } else {
        _selectedModel = widget.scanResult.model;
      }
    } else {
      _selectedModel = null;
    }

    _writtenScore = 0.0;
    _answers = {};
    _states = {};

    for (int q = 1; q <= widget.exam.questionCount; q++) {
      final qRes = widget.scanResult.answers[q];
      if (qRes != null) {
        _states[q] = qRes.state;
        // The student's answer is selected for states SELECTED and UNCERTAIN
        // For MULTIPLE and EMPTY there is no answer (counts as wrong)
        if (qRes.state == QuestionState.selected || qRes.state == QuestionState.uncertain) {
          _answers[q] = qRes.selected;
        } else {
          _answers[q] = null;
        }
      } else {
        _answers[q] = null;
        _states[q] = QuestionState.empty;
      }
    }

    // Convert annotated image to PNG bytes for display
    if (widget.scanResult.annotatedImage != null) {
      _annotatedPngBytes = Uint8List.fromList(img.encodePng(widget.scanResult.annotatedImage!));
    }
  }

  @override
  void dispose() {
    _studentCodeController.dispose();
    _studentNameController.dispose();
    super.dispose();
  }

  int get _correctMcqCount {
    if (_selectedModel == null) return 0;
    final key = widget.exam.getAnswerKey(_selectedModel!);
    if (key == null) return 0;
    int count = 0;
    _answers.forEach((q, ans) {
      if (ans != null && key[q] != null && ans == key[q]) {
        count++;
      }
    });
    return count;
  }

  double get _mcqScore {
    if (_selectedModel == null) return 0.0;
    return _correctMcqCount * widget.exam.mcqScorePerQ;
  }

  double get _totalScore {
    return _mcqScore + _writtenScore;
  }

  int get _uncertainCount {
    return _states.values.where((s) => s == QuestionState.uncertain).length;
  }

  void _onAnswerTapped(int q, String option) {
    setState(() {
      if (_answers[q] == option) {
        // Unselect
        _answers[q] = null;
        _states[q] = QuestionState.empty;
      } else {
        _answers[q] = option;
        _states[q] = QuestionState.selected;
      }
    });
  }

  Future<void> _saveResult() async {
    if (_selectedModel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('يرجى اختيار نموذج الامتحان أولاً في الخطوة الأولى', style: GoogleFonts.cairo()),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
      return;
    }
    final code = _studentCodeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('يرجى إدخال كود الطالب أولاً', style: GoogleFonts.cairo()),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final finalAnswers = <String, String>{};
    _answers.forEach((k, v) {
      if (v != null) finalAnswers[k.toString()] = v;
    });

    final name = _studentNameController.text.trim().isNotEmpty
        ? _studentNameController.text.trim()
        : 'Student ($code)';

    final result = ExamResult(
      examId: widget.exam.id,
      studentCode: code,
      studentName: name,
      center: widget.centerName != 'All Centers' ? widget.centerName : widget.exam.center,
      model: _selectedModel!,
      mcqScore: _mcqScore,
      writtenScore: _writtenScore,
      totalScore: _totalScore,
      studentAnswers: finalAnswers,
      assistantName: widget.assistantName,
      createdAt: DateTime.now().toIso8601String(),
    );

    final cloudSaved = await SupabaseService.saveExamResult(result);

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            cloudSaved ? 'تم حفظ الدرجة في السحابة بنجاح! ✅' : 'تم الحفظ محلياً (غير متصل) ⚠️',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
          backgroundColor: cloudSaved ? const Color(0xFF0F766E) : const Color(0xFFD97706),
        ),
      );
      Navigator.pop(context, true); // Pop back to camera
    }
  }

  Future<void> _shareWhatsApp() async {
    final code = _studentCodeController.text.trim();
    final name = _studentNameController.text.trim().isNotEmpty
        ? _studentNameController.text.trim()
        : 'Student ($code)';
    final center = widget.centerName != 'All Centers' ? widget.centerName : widget.exam.center;

    final msg = '''🌟 *نتيجة اختبار مستر كيلاني* 🌟
👤 *اسم الطالب:* $name
🆔 *كود الطالب:* $code
🏫 *السنتر:* $center
📝 *الامتحان:* ${widget.exam.title}
📋 *النموذج:* ${_selectedModel ?? "غير محدد"}
📊 *الدرجة الكلية:* ${_totalScore.toStringAsFixed(1)} / ${widget.exam.totalScore.toStringAsFixed(0)}
✅ *الاختيار من متعدد:* ${_mcqScore.toStringAsFixed(1)} ($_correctMcqCount/${widget.exam.questionCount})
✍️ *المقالي:* ${_writtenScore.toStringAsFixed(1)} / ${widget.exam.writtenMaxScore.toStringAsFixed(0)}
''';

    final uri = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(msg)}');
    final webUri = Uri.parse('https://api.whatsapp.com/send?text=${Uri.encodeComponent(msg)}');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر فتح تطبيق واتساب', style: GoogleFonts.cairo()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final answerKey = _selectedModel != null ? widget.exam.getAnswerKey(_selectedModel!) : null;
    final availModels = widget.exam.models.keys.isNotEmpty ? widget.exam.models.keys.toList() : ['A', 'B'];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'مراجعة وتأكيد الإجابات',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0F766E),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            tooltip: 'إرسال عبر واتساب',
            onPressed: _shareWhatsApp,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. Model Card (أولاً: نموذج الامتحان المكتشف)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _selectedModel == null
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF0F766E).withValues(alpha: 0.3),
                  width: _selectedModel == null ? 1.5 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '1️⃣ الخطوة الأولى',
                              style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF0F766E)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'نموذج الامتحان',
                            style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF1E293B)),
                          ),
                        ],
                      ),
                      if (_selectedModel != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF10B981)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle, color: Color(0xFF047857), size: 14),
                              const SizedBox(width: 4),
                              Text(
                                widget.scanResult.modelDetected && _selectedModel == widget.scanResult.model
                                    ? 'تم الكشف: $_selectedModel'
                                    : 'النموذج: $_selectedModel',
                                style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12, color: const Color(0xFF047857)),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFF59E0B)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309), size: 14),
                              const SizedBox(width: 4),
                              Text(
                                'لم يتم الكشف عن الموديل - اختر الموديل',
                                style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 11, color: const Color(0xFFB45309)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Text(
                        'تأكيد النموذج:',
                        style: GoogleFonts.cairo(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
                      ),
                      ...availModels.map((m) {
                        final isSel = _selectedModel == m;
                        return ChoiceChip(
                          label: Text(
                            'نموذج $m',
                            style: GoogleFonts.cairo(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isSel ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                          selected: isSel,
                          selectedColor: const Color(0xFF0F766E),
                          backgroundColor: const Color(0xFFF1F5F9),
                          onSelected: (val) {
                            if (val) setState(() => _selectedModel = m);
                          },
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),

            // 2. Student ID Card (ثانياً: كود الطالب المستخرج)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _studentCodeController.text.contains('?')
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '2️⃣ الخطوة الثانية',
                              style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF0284C7)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'كود الطالب (Roll No)',
                            style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF1E293B)),
                          ),
                        ],
                      ),
                      if (_studentCodeController.text.contains('?'))
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFF59E0B)),
                          ),
                          child: Text(
                            '⚠️ يرجى تصحيح الرقم',
                            style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFB45309)),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF10B981)),
                          ),
                          child: Text(
                            '✅ مستخرج من التظليل',
                            style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF047857)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: TextField(
                          controller: _studentCodeController,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: 'كود الطالب (5 أرقام)',
                            labelStyle: GoogleFonts.cairo(fontSize: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            prefixIcon: const Icon(Icons.tag, size: 20, color: Color(0xFF0F766E)),
                          ),
                          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 6,
                        child: TextField(
                          controller: _studentNameController,
                          decoration: InputDecoration(
                            labelText: 'اسم الطالب (اختياري)',
                            labelStyle: GoogleFonts.cairo(fontSize: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            prefixIcon: const Icon(Icons.person_outline, size: 20),
                          ),
                          style: GoogleFonts.cairo(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 3. Scores & Status Card (ثالثاً: درجات الطالب)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '3️⃣ الخطوة الثالثة',
                              style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF7C3AED)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'تصحيح الاختيارات والدرجات',
                            style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF1E293B)),
                          ),
                        ],
                      ),
                      // Uncertainty indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _uncertainCount > 0 ? const Color(0xFFFEF3C7) : const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _uncertainCount > 0 ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _uncertainCount > 0 ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                              size: 14,
                              color: _uncertainCount > 0 ? const Color(0xFFB45309) : const Color(0xFF047857),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _uncertainCount > 0 ? '$_uncertainCount للمراجعة' : 'جميع الإجابات مؤكدة',
                              style: GoogleFonts.cairo(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _uncertainCount > 0 ? const Color(0xFFB45309) : const Color(0xFF047857),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                  if (_selectedModel == null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFF59E0B)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Color(0xFFB45309), size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'اختر نموذج الامتحان في الخطوة الأولى لبدء التصحيح وحساب الدرجات',
                              style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFB45309)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Score summary row
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildScoreItem(
                          'الاختيار من متعدد',
                          _selectedModel != null
                              ? '${_mcqScore.toStringAsFixed(1)} / ${(widget.exam.questionCount * widget.exam.mcqScorePerQ).toStringAsFixed(0)}'
                              : '-- / ${(widget.exam.questionCount * widget.exam.mcqScorePerQ).toStringAsFixed(0)}',
                          const Color(0xFF0284C7),
                        ),
                        if (widget.exam.writtenMaxScore > 0)
                          _buildWrittenScoreStepper()
                        else
                          _buildScoreItem(
                            'الإجابات الصحيحة',
                            _selectedModel != null ? '$_correctMcqCount / ${widget.exam.questionCount}' : '-- / ${widget.exam.questionCount}',
                            const Color(0xFF16A34A),
                          ),
                        _buildScoreItem(
                          'المجموع الكلي',
                          _selectedModel != null
                              ? '${_totalScore.toStringAsFixed(1)} / ${widget.exam.totalScore.toStringAsFixed(0)}'
                              : '-- / ${widget.exam.totalScore.toStringAsFixed(0)}',
                          const Color(0xFF0F766E),
                          isBold: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Toggle Image / Questions View
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    'الأسئلة والإجابات (${widget.exam.questionCount})',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFF1E293B)),
                  ),
                  const Spacer(),
                  if (_annotatedPngBytes != null || widget.originalBytes.isNotEmpty)
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFF0F766E)),
                      icon: Icon(_showOriginal ? Icons.grid_view : Icons.image_outlined, size: 18),
                      label: Text(_showOriginal ? 'عرض الأسئلة' : 'عرض الصورة المصححة', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () => setState(() => _showOriginal = !_showOriginal),
                    ),
                ],
              ),
            ),

            // Main Content: either Image Viewer or Questions List
            if (_showOriginal)
              _buildImageViewer()
            else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.touch_app_outlined, size: 16, color: Color(0xFF0F766E)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'اضغط على أي اختيار (A, B, C, D) لتعديل أو تغيير إجابة الطالب مباشرة',
                        style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              _buildQuestionsList(answerKey),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF25D366),
                    side: const BorderSide(color: Color(0xFF25D366), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _shareWhatsApp,
                  icon: const Icon(Icons.share, size: 18),
                  label: Text('واتساب', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 6,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 2,
                  ),
                  onPressed: _isSaving ? null : _saveResult,
                  icon: _isSaving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check, size: 20),
                  label: Text(
                    _isSaving ? 'جارِ الحفظ...' : 'اعتماد وحفظ الدرجة',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreItem(String label, String value, Color color, {bool isBold = false}) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.cairo(fontSize: 11, color: const Color(0xFF64748B))),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.cairo(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildWrittenScoreStepper() {
    return Column(
      children: [
        Text('المقالي', style: GoogleFonts.cairo(fontSize: 11, color: const Color(0xFF64748B))),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () {
                if (_writtenScore > 0) setState(() => _writtenScore -= 0.5);
              },
              child: const Icon(Icons.remove_circle_outline, size: 18, color: Color(0xFF64748B)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                _writtenScore.toStringAsFixed(1),
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFFD97706)),
              ),
            ),
            InkWell(
              onTap: () {
                if (_writtenScore < widget.exam.writtenMaxScore) setState(() => _writtenScore += 0.5);
              },
              child: const Icon(Icons.add_circle_outline, size: 18, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImageViewer() {
    final bytes = _annotatedPngBytes ?? widget.originalBytes;
    return Container(
      margin: const EdgeInsets.all(16),
      height: 480,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: InteractiveViewer(
          maxScale: 5.0,
          child: Center(
            child: Image.memory(bytes, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionsList(Map<int, String>? answerKey) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: widget.exam.questionCount,
      itemBuilder: (context, index) {
        final q = index + 1;
        final selected = _answers[q];
        final state = _states[q] ?? QuestionState.empty;
        final correctAns = answerKey?[q];
        final isGraded = answerKey != null;
        final isCorrect = isGraded && selected != null && correctAns != null && selected == correctAns;
        final isWrong = isGraded && selected != null && correctAns != null && selected != correctAns;

        Color tileBorderColor = Colors.grey.shade200;
        if (state == QuestionState.uncertain) {
          tileBorderColor = const Color(0xFFF59E0B);
        } else if (state == QuestionState.multiple) {
          tileBorderColor = const Color(0xFFEF4444);
        } else if (isCorrect) {
          tileBorderColor = const Color(0xFF10B981).withValues(alpha: 0.5);
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: tileBorderColor, width: 1.2),
          ),
          child: Row(
            children: [
              // Question Number Badge
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isCorrect
                      ? const Color(0xFFECFDF5)
                      : (isWrong ? const Color(0xFFFEF2F2) : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Q$q',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isCorrect
                        ? const Color(0xFF047857)
                        : (isWrong ? const Color(0xFFB91C1C) : const Color(0xFF475569)),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Badges: UNCERTAIN = Orange, MULTIPLE = Red, EMPTY = Gray
              if (state == QuestionState.uncertain)
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFF59E0B)),
                  ),
                  child: Text('شك', style: GoogleFonts.cairo(fontSize: 10, color: const Color(0xFFB45309), fontWeight: FontWeight.bold)),
                )
              else if (state == QuestionState.multiple)
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFEF4444)),
                  ),
                  child: Text('متعدد', style: GoogleFonts.cairo(fontSize: 10, color: const Color(0xFFB91C1C), fontWeight: FontWeight.bold)),
                )
              else if (state == QuestionState.empty)
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF94A3B8)),
                  ),
                  child: Text('فارغ', style: GoogleFonts.cairo(fontSize: 10, color: const Color(0xFF64748B), fontWeight: FontWeight.bold)),
                ),

              // Options A, B, C, D
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: ['A', 'B', 'C', 'D'].map((opt) {
                    final isOptSel = selected == opt;
                    final isKeyOpt = correctAns == opt;

                    Color btnColor = const Color(0xFFF8FAFC);
                    Color textColor = const Color(0xFF334155);
                    Color borderColor = Colors.grey.shade300;

                    if (isOptSel) {
                      if (!isGraded) {
                        btnColor = const Color(0xFF0F766E);
                        textColor = Colors.white;
                        borderColor = const Color(0xFF0F766E);
                      } else if (isCorrect) {
                        btnColor = const Color(0xFF10B981);
                        textColor = Colors.white;
                        borderColor = const Color(0xFF047857);
                      } else {
                        btnColor = const Color(0xFFEF4444);
                        textColor = Colors.white;
                        borderColor = const Color(0xFFB91C1C);
                      }
                    } else if (isKeyOpt && isWrong) {
                      // Show correct key hint
                      btnColor = const Color(0xFFD1FAE5);
                      borderColor = const Color(0xFF10B981);
                      textColor = const Color(0xFF065F46);
                    }

                    return InkWell(
                      onTap: () => _onAnswerTapped(q, opt),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: btnColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor, width: isOptSel ? 2 : 1),
                        ),
                        child: Text(
                          opt,
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // Clear Answer Button
              IconButton(
                icon: const Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                tooltip: 'تفريغ الإجابة',
                onPressed: () {
                  setState(() {
                    _answers[q] = null;
                    _states[q] = QuestionState.empty;
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
