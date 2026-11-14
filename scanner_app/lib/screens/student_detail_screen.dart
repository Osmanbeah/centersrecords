import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/exam.dart';
import '../services/supabase_service.dart';

class StudentDetailScreen extends StatefulWidget {
  final Exam exam;
  final ExamResult initialResult;
  final VoidCallback? onResultUpdated;

  const StudentDetailScreen({
    super.key,
    required this.exam,
    required this.initialResult,
    this.onResultUpdated,
  });

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  late TextEditingController _codeController;
  late TextEditingController _nameController;
  late TextEditingController _writtenScoreController;
  late String _selectedModel;
  late double _writtenScore;
  late Map<int, String?> _answers;
  bool _isSaving = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.initialResult.studentCode);
    _nameController = TextEditingController(text: widget.initialResult.studentName);
    _selectedModel = widget.initialResult.model;
    _writtenScore = widget.initialResult.writtenScore;
    _writtenScoreController = TextEditingController(
      text: _writtenScore == 0.0 ? '0' : (_writtenScore.truncateToDouble() == _writtenScore ? _writtenScore.toInt().toString() : _writtenScore.toStringAsFixed(1)),
    );

    _answers = {};
    for (int q = 1; q <= widget.exam.questionCount; q++) {
      _answers[q] = widget.initialResult.studentAnswers[q.toString()];
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _writtenScoreController.dispose();
    super.dispose();
  }

  int get _correctMcqCount {
    final key = widget.exam.getAnswerKey(_selectedModel);
    if (key == null) return 0;
    int count = 0;
    _answers.forEach((q, ans) {
      if (ans != null && key[q] != null && ans == key[q]) {
        count++;
      }
    });
    return count;
  }

  double get _mcqScore => _correctMcqCount * widget.exam.mcqScorePerQ;

  double get _totalScore => _mcqScore + _writtenScore;

  void _onAnswerTapped(int q, String opt) {
    setState(() {
      _hasChanges = true;
      if (_answers[q] == opt) {
        _answers[q] = null;
      } else {
        _answers[q] = opt;
      }
    });
  }

  Future<void> _saveChanges() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('يرجى إدخال كود الطالب', style: GoogleFonts.cairo()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final finalAnswers = <String, String>{};
    _answers.forEach((k, v) {
      if (v != null) finalAnswers[k.toString()] = v;
    });

    final name = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : 'Student ($code)';

    final updated = widget.initialResult.copyWith(
      studentCode: code,
      studentName: name,
      model: _selectedModel,
      mcqScore: _mcqScore,
      writtenScore: _writtenScore,
      totalScore: _totalScore,
      studentAnswers: finalAnswers,
    );

    final success = await SupabaseService.updateExamResult(updated);

    if (mounted) {
      setState(() {
        _isSaving = false;
        _hasChanges = false;
      });

      widget.onResultUpdated?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'تم حفظ التعديلات بنجاح! ✅' : 'تم الحفظ محلياً (غير متصل) ⚠️',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
          backgroundColor: success ? const Color(0xFF0F766E) : const Color(0xFFD97706),
        ),
      );
    }
  }

  Future<void> _deleteResult() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('تأكيد حذف النتيجة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        content: Text(
          'هل أنت متأكد من حذف نتيجة الطالب (${widget.initialResult.studentCode}) نهائياً؟',
          style: GoogleFonts.cairo(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('حذف', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await SupabaseService.deleteExamResult(
        widget.initialResult.id,
        widget.initialResult.examId,
        widget.initialResult.studentCode,
      );
      widget.onResultUpdated?.call();
      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  Future<void> _shareWhatsApp() async {
    final code = _codeController.text.trim();
    final name = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : 'Student ($code)';

    final msg = '''🌟 *نتيجة اختبار مستر كيلاني (معدلة)* 🌟
👤 *اسم الطالب:* $name
📱 *رقم الهاتف:* $code
🏫 *السنتر:* ${widget.initialResult.center}
📝 *الامتحان:* ${widget.exam.title}
📋 *النموذج:* $_selectedModel
📊 *الدرجة الكلية:* ${_totalScore.toStringAsFixed(1)} / ${widget.exam.totalScore.toStringAsFixed(0)}
✅ *الاختيار من متعدد:* ${_mcqScore.toStringAsFixed(1)} ($_correctMcqCount/${widget.exam.questionCount})
✍️ *المقالي:* ${_writtenScore.toStringAsFixed(1)} / ${widget.exam.writtenMaxScore.toStringAsFixed(0)}
👨‍🏫 *القائم بالرصد:* ${widget.initialResult.assistantName}
''';

    final uri = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(msg)}');
    final webUri = Uri.parse('https://api.whatsapp.com/send?text=${Uri.encodeComponent(msg)}');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر فتح واتساب', style: GoogleFonts.cairo()), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final answerKey = widget.exam.getAnswerKey(_selectedModel);
    final availModels = widget.exam.models.keys.isNotEmpty
        ? widget.exam.models.keys.toList()
        : ['A', 'B'];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'تعديل ومراجعة إجابات الطالب',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0F766E),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            tooltip: 'مشاركة عبر واتساب',
            onPressed: _shareWhatsApp,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            tooltip: 'حذف النتيجة',
            onPressed: _deleteResult,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. Assistant Traceability Card
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDFA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF99F6E4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_user_outlined, color: Color(0xFF0F766E), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'رُصدت بواسطة المساعد: ${widget.initialResult.assistantName}',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF115E59),
                      ),
                    ),
                  ),
                  Text(
                    widget.initialResult.createdAt.length >= 10
                        ? widget.initialResult.createdAt.substring(0, 10)
                        : '',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF0D9488)),
                  ),
                ],
              ),
            ),

            // 2. Student Info & Model
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: TextField(
                          controller: _codeController,
                          keyboardType: TextInputType.phone,
                          maxLength: 11,
                          onChanged: (_) => setState(() => _hasChanges = true),
                          decoration: InputDecoration(
                            labelText: 'رقم هاتف الطالب (Phone No)',
                            hintText: '010XXXXXXXX',
                            counterText: '',
                            labelStyle: GoogleFonts.cairo(fontSize: 12),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            prefixIcon: const Icon(Icons.phone_android, size: 18, color: Color(0xFF0F766E)),
                          ),
                          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 6,
                        child: TextField(
                          controller: _nameController,
                          onChanged: (_) => setState(() => _hasChanges = true),
                          decoration: InputDecoration(
                            labelText: 'اسم الطالب',
                            labelStyle: GoogleFonts.cairo(fontSize: 12),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            prefixIcon: const Icon(Icons.person_outline, size: 18),
                          ),
                          style: GoogleFonts.cairo(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text('نموذج الامتحان:', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF475569))),
                      const SizedBox(width: 10),
                      ...availModels.map((m) {
                        final isSel = _selectedModel == m;
                        return Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: ChoiceChip(
                            label: Text(
                              'نموذج $m',
                              style: GoogleFonts.cairo(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: isSel ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                            selected: isSel,
                            selectedColor: const Color(0xFF0F766E),
                            backgroundColor: const Color(0xFFF1F5F9),
                            onSelected: (val) {
                              if (val) setState(() { _selectedModel = m; _hasChanges = true; });
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),

            // 3. Score Summary Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildScoreItem(
                    'الاختيار من متعدد',
                    '${_mcqScore.toStringAsFixed(1)} / ${(widget.exam.questionCount * widget.exam.mcqScorePerQ).toStringAsFixed(0)}',
                    const Color(0xFF0284C7),
                  ),
                  if (widget.exam.writtenMaxScore > 0)
                    Column(
                      children: [
                        Text(
                          'المقالي (من ${widget.exam.writtenMaxScore.toStringAsFixed(0)})',
                          style: GoogleFonts.cairo(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        SizedBox(
                          width: 72,
                          height: 38,
                          child: TextField(
                            controller: _writtenScoreController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textAlign: TextAlign.center,
                            textInputAction: TextInputAction.done,
                            style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFFD97706)),
                            decoration: InputDecoration(
                              hintText: '0',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                              filled: true,
                              fillColor: const Color(0xFFFFFBEB),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFF59E0B))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD97706), width: 2)),
                            ),
                            onChanged: (val) {
                              final parsed = double.tryParse(val.trim());
                              setState(() {
                                _hasChanges = true;
                                if (parsed == null) {
                                  _writtenScore = 0.0;
                                } else if (parsed > widget.exam.writtenMaxScore) {
                                  _writtenScore = widget.exam.writtenMaxScore;
                                  _writtenScoreController.text = widget.exam.writtenMaxScore.toStringAsFixed(0);
                                  _writtenScoreController.selection = TextSelection.fromPosition(TextPosition(offset: _writtenScoreController.text.length));
                                } else {
                                  _writtenScore = parsed;
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    )
                  else
                    _buildScoreItem('صحيح', '$_correctMcqCount / ${widget.exam.questionCount}', const Color(0xFF16A34A)),
                  _buildScoreItem(
                    'المجموع الكلي',
                    '${_totalScore.toStringAsFixed(1)} / ${widget.exam.totalScore.toStringAsFixed(0)}',
                    const Color(0xFF0F766E),
                    isBold: true,
                  ),
                ],
              ),
            ),

            // 4. Instructions Hint
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.touch_app_outlined, size: 16, color: Color(0xFF0F766E)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'اضغط على أي اختيار (A, B, C, D) لتعديل إجابة الطالب مباشرة',
                      style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
                    ),
                  ),
                ],
              ),
            ),

            // 5. Questions List
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.exam.questionCount,
              itemBuilder: (context, index) {
                final q = index + 1;
                final selected = _answers[q];
                final correctAns = answerKey?[q];
                final isCorrect = selected != null && correctAns != null && selected == correctAns;
                final isWrong = selected != null && correctAns != null && selected != correctAns;

                Color borderColor = Colors.grey.shade200;
                if (isCorrect) {
                  borderColor = const Color(0xFF10B981).withValues(alpha: 0.5);
                } else if (isWrong) {
                  borderColor = const Color(0xFFEF4444).withValues(alpha: 0.5);
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor, width: 1.2),
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
                      const SizedBox(width: 8),

                      // Options A, B, C, D
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: ['A', 'B', 'C', 'D'].map((opt) {
                            final isOptSel = selected == opt;
                            final isKeyOpt = correctAns == opt;

                            Color btnColor = const Color(0xFFF8FAFC);
                            Color textColor = const Color(0xFF334155);
                            Color itemBorderColor = Colors.grey.shade300;

                            if (isOptSel) {
                              if (isCorrect) {
                                btnColor = const Color(0xFF10B981);
                                textColor = Colors.white;
                                itemBorderColor = const Color(0xFF047857);
                              } else {
                                btnColor = const Color(0xFFEF4444);
                                textColor = Colors.white;
                                itemBorderColor = const Color(0xFFB91C1C);
                              }
                            } else if (isKeyOpt && isWrong) {
                              btnColor = const Color(0xFFD1FAE5);
                              itemBorderColor = const Color(0xFF10B981);
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
                                  border: Border.all(color: itemBorderColor, width: isOptSel ? 2 : 1),
                                ),
                                child: Text(
                                  opt,
                                  style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      // Clear Button
                      IconButton(
                        icon: const Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                        tooltip: 'تفريغ الإجابة',
                        onPressed: () {
                          setState(() {
                            _answers[q] = null;
                            _hasChanges = true;
                          });
                        },
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, -2)),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _hasChanges ? const Color(0xFF0F766E) : Colors.grey.shade400,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _isSaving ? null : _saveChanges,
              icon: _isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined),
              label: Text(
                _isSaving ? 'جارِ الحفظ...' : (_hasChanges ? 'حفظ التعديلات' : 'تم الحفظ'),
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
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
}
