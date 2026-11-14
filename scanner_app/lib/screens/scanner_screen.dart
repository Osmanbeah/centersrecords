import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import '../models/exam.dart';
import '../services/omr_engine.dart';
import 'review_screen.dart';

class ScannerScreen extends StatefulWidget {
  final Exam exam;
  final String assistantName;
  final String centerName;

  const ScannerScreen({
    super.key,
    required this.exam,
    required this.assistantName,
    required this.centerName,
  });

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  bool _isTorchOn = false;
  bool _isAutoCaptureEnabled = true;
  bool _isAligned = false;
  int _consecutiveAlignedFrames = 0;
  int _lastFrameTime = 0;
  String _statusMessage = 'وجّه المربعات السوداء الأربعة داخل الإطار للمسح التلقائي';
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _cameraController;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _statusMessage = 'لا توجد كاميرا متوفرة - استخدم اختيار صورة';
        });
        return;
      }

      final backCamera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      final controller = CameraController(
        backCamera,
        ResolutionPreset.veryHigh,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      _cameraController = controller;
      await controller.initialize();

      try {
        await controller.setFocusMode(FocusMode.auto);
        await controller.setFlashMode(FlashMode.off);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _statusMessage = 'اضبط ورقة الإجابة داخل الإطار للالتقاط الفوري';
        });

        if (_isAutoCaptureEnabled) {
          _startLiveStream();
        }
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
      if (mounted) {
        setState(() {
          _statusMessage = 'فشل تشغيل الكاميرا - يمكنك اختيار صورة من المعرض';
        });
      }
    }
  }

  void _startLiveStream() {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isStreamingImages) return;

    _lastFrameTime = 0;
    _consecutiveAlignedFrames = 0;

    try {
      controller.startImageStream((CameraImage image) {
        if (_isProcessing || !mounted) return;
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - _lastFrameTime < 180) return; // run at ~5-6 fps
        _lastFrameTime = now;

        try {
          if (image.planes.isEmpty) return;
          final yPlane = image.planes[0];
          final status = OMREngine.checkAlignmentFromYPlane(
            yPlane.bytes,
            image.width,
            image.height,
            yPlane.bytesPerRow,
          );

          if (!mounted) return;

          if (status.isAligned) {
            _consecutiveAlignedFrames++;
            if (!_isAligned) {
              setState(() {
                _isAligned = true;
                _statusMessage = 'تم تطابق النقاط والزوايا بنجاح 🟢';
              });
            }

            // Auto-capture like EvalBee when aligned stably for ~300ms
            if (_isAutoCaptureEnabled && _consecutiveAlignedFrames >= 2 && !_isProcessing) {
              _triggerAutoCapture();
            }
          } else {
            _consecutiveAlignedFrames = 0;
            if (_isAligned || _statusMessage != status.message) {
              setState(() {
                _isAligned = false;
                _statusMessage = status.message;
              });
            }
          }
        } catch (_) {}
      });
    } catch (e) {
      debugPrint('startImageStream warning: $e');
    }
  }

  Future<void> _triggerAutoCapture() async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _statusMessage = 'تم التطابق! جارِ التقاط الورقة وتصحيحها...';
    });

    try {
      if (_cameraController != null && _cameraController!.value.isStreamingImages) {
        await _cameraController!.stopImageStream();
      }
      final XFile photo = await _cameraController!.takePicture();
      final bytes = await photo.readAsBytes();
      await _processImageBytes(bytes);
    } catch (e) {
      debugPrint('Auto-capture error: $e');
      if (mounted) {
        setState(() => _isProcessing = false);
        _startLiveStream();
      }
    }
  }

  Future<void> _toggleTorch() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    try {
      if (_isTorchOn) {
        await _cameraController!.setFlashMode(FlashMode.off);
        setState(() => _isTorchOn = false);
      } else {
        await _cameraController!.setFlashMode(FlashMode.torch);
        setState(() => _isTorchOn = true);
      }
    } catch (e) {
      debugPrint('Torch error: $e');
    }
  }

  void _toggleAutoCapture() {
    setState(() {
      _isAutoCaptureEnabled = !_isAutoCaptureEnabled;
      _isAligned = false;
      _consecutiveAlignedFrames = 0;
    });

    if (_isAutoCaptureEnabled) {
      _startLiveStream();
    } else {
      if (_cameraController != null && _cameraController!.value.isStreamingImages) {
        _cameraController!.stopImageStream();
      }
      setState(() {
        _statusMessage = 'الوضع اليدوي: اضبط الورقة واضغط زر الكاميرا';
      });
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        _processImageBytes(bytes);
      }
    } catch (e) {
      _showError('خطأ أثناء اختيار الصورة: $e');
    }
  }

  Future<void> _takePictureAndScan() async {
    if (_isProcessing) return;
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      _pickFromGallery();
      return;
    }

    try {
      setState(() {
        _isProcessing = true;
        _statusMessage = 'جارِ التقاط صورة عالية الدقة...';
      });

      if (_cameraController!.value.isStreamingImages) {
        await _cameraController!.stopImageStream();
      }

      final XFile photo = await _cameraController!.takePicture();
      final bytes = await photo.readAsBytes();

      await _processImageBytes(bytes);
    } catch (e) {
      setState(() => _isProcessing = false);
      _showError('فشل التقاط الصورة: $e');
      _startLiveStream();
    }
  }

  Future<void> _processImageBytes(Uint8List rawBytes) async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'جارِ فحص الجودة وتصحيح المنظور OMR...';
    });

    try {
      final scanResult = await compute(_runOmrScanIsolate, _OmrParam(
        imageBytes: rawBytes,
        questionCount: widget.exam.questionCount,
        answerKey: widget.exam.getAnswerKey('A'),
      ));

      setState(() => _isProcessing = false);

      if (!scanResult.success) {
        _showScanErrorDialog(scanResult);
        return;
      }

      // Successfully detected! Navigate to ReviewScreen
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReviewScreen(
              exam: widget.exam,
              scanResult: scanResult,
              originalBytes: rawBytes,
              assistantName: widget.assistantName,
              centerName: widget.centerName,
            ),
          ),
        );

        // Returned from ReviewScreen: re-arm live stream for next scan
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _isAligned = false;
            _consecutiveAlignedFrames = 0;
            _statusMessage = 'اضبط ورقة الإجابة داخل الإطار للالتقاط الفوري';
          });
          if (_isAutoCaptureEnabled) {
            _startLiveStream();
          }
        }
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      _showError('حدث خطأ أثناء معالجة الورقة: $e');
      _startLiveStream();
    }
  }

  void _showScanErrorDialog(OMRScanResult result) {
    String arTitle = 'تعذر قراءة الورقة';
    String arMessage = '';
    String enMessage = result.message ?? '';

    switch (result.error) {
      case 'SHEET_NOT_FOUND':
        arMessage = 'لم نتمكن من تحديد زوايا الورقة.\nتأكد أن المربعات السوداء الأربعة في أطراف الورقة ظاهرة بالكامل، والورقة مفرودة، والهاتف عمودي.';
        break;
      case 'NOT_PORTRAIT':
        arMessage = 'يرجى حمل الهاتف في الوضع الرأسي (عمودي) بحيث تملأ الورقة الشاشة.';
        break;
      case 'LOW_RESOLUTION':
        arMessage = 'دقة الصورة منخفضة جداً (الحد الأدنى 600x800). اقترب أكثر من الورقة.';
        break;
      case 'TOO_DARK':
        arMessage = 'الإضاءة معتمة جداً. يرجى تشغيل فلاش الهاتف أو زيادة إضاءة الغرفة.';
        break;
      case 'TOO_BLURRY':
        arMessage = 'الصورة مهتزة أو غير واضحة. يرجى تثبيت الهاتف جيداً وإعادة الالتقاط.';
        break;
      default:
        arMessage = result.message ?? 'فشل التعرف على الورقة';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 26),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$arTitle / Scan Failed',
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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      arMessage,
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF991B1B),
                      ),
                    ),
                    if (enMessage.isNotEmpty && enMessage != arMessage) ...[
                      const SizedBox(height: 6),
                      Text(
                        enMessage,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF7F1D1D),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'نصائح لقراءة دقيقة 100% / Tips for best result:\n• وجّه الكاميرا رأسياً وتأكد من ثبات اليد.\n• تأكد من ظهور العلامات السوداء الأربع في زوايا الورقة.\n• اضغط زر الفلاش ⚡ إذا كانت الإضاءة ضعيفة.',
                style: GoogleFonts.cairo(fontSize: 12, color: const Color(0xFF475569), height: 1.5),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _startLiveStream();
            },
            icon: const Icon(Icons.camera_alt_outlined, size: 18),
            label: Text(
              'إعادة المحاولة / Retake',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.cairo()),
        backgroundColor: const Color(0xFFDC2626),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'مسح ورقة: ${widget.exam.title}',
              style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              _isAutoCaptureEnabled ? '⚡ وضع الالتقاط التلقائي (EvalBee Mode)' : '🖐️ وضع الالتقاط اليدوي',
              style: GoogleFonts.cairo(fontSize: 11, color: _isAutoCaptureEnabled ? const Color(0xFF34D399) : const Color(0xFF94A3B8)),
            ),
          ],
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          // Auto / Manual Toggle
          InkWell(
            onTap: _toggleAutoCapture,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _isAutoCaptureEnabled ? const Color(0xFF10B981).withValues(alpha: 0.25) : Colors.white12,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _isAutoCaptureEnabled ? const Color(0xFF10B981) : Colors.white30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isAutoCaptureEnabled ? Icons.bolt : Icons.touch_app,
                    size: 14,
                    color: _isAutoCaptureEnabled ? const Color(0xFF34D399) : Colors.white70,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isAutoCaptureEnabled ? 'تلقائي' : 'يدوي',
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _isAutoCaptureEnabled ? const Color(0xFF34D399) : Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Icon(_isTorchOn ? Icons.flash_on : Icons.flash_off, color: _isTorchOn ? Colors.amber : Colors.white),
            tooltip: 'تشغيل الفلاش',
            onPressed: _toggleTorch,
          ),
          IconButton(
            icon: const Icon(Icons.photo_library, color: Colors.white),
            tooltip: 'اختيار من المعرض',
            onPressed: _pickFromGallery,
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera Preview or Fallback
          if (_isCameraInitialized && _cameraController != null)
            CameraPreview(_cameraController!)
          else
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.camera_alt_outlined, size: 64, color: Colors.white54),
                  const SizedBox(height: 16),
                  Text(
                    _statusMessage,
                    style: GoogleFonts.cairo(color: Colors.white, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F766E)),
                    onPressed: _pickFromGallery,
                    icon: const Icon(Icons.photo_library, color: Colors.white),
                    label: Text('اختيار صورة من المعرض', style: GoogleFonts.cairo(color: Colors.white)),
                  ),
                ],
              ),
            ),

          // Viewfinder Overlay Frame (Guides user to frame the sheet)
          CustomPaint(
            painter: _ViewfinderOverlayPainter(
              questionCount: widget.exam.questionCount,
              isAligned: _isAligned,
            ),
          ),

          // Guidance Prompt Bar at Top
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _isAligned
                    ? const Color(0xFF064E3B).withValues(alpha: 0.90)
                    : Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isAligned ? const Color(0xFF10B981) : const Color(0xFF0F766E),
                  width: _isAligned ? 2.0 : 1.2,
                ),
                boxShadow: _isAligned
                    ? [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.45),
                          blurRadius: 12,
                          spreadRadius: 1,
                        )
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Icon(
                    _isAligned ? Icons.check_circle : Icons.info_outline,
                    color: _isAligned ? const Color(0xFF34D399) : const Color(0xFF38BDF8),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusMessage,
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Controls (Shutter Button)
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Column(
              children: [
                GestureDetector(
                  onTap: _isProcessing ? null : _takePictureAndScan,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isAligned ? const Color(0xFF34D399) : Colors.white,
                        width: _isAligned ? 5 : 4,
                      ),
                      color: _isProcessing
                          ? Colors.grey
                          : (_isAligned ? const Color(0xFF10B981) : const Color(0xFF0F766E)),
                      boxShadow: [
                        BoxShadow(
                          color: (_isAligned ? const Color(0xFF10B981) : const Color(0xFF0F766E))
                              .withValues(alpha: 0.6),
                          blurRadius: _isAligned ? 22 : 16,
                          spreadRadius: _isAligned ? 4 : 2,
                        ),
                      ],
                    ),
                    child: _isProcessing
                        ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                        : Icon(
                            _isAligned ? Icons.auto_awesome : Icons.camera_alt,
                            color: Colors.white,
                            size: 36,
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isProcessing
                      ? 'جارِ التحليل...'
                      : (_isAutoCaptureEnabled
                          ? (_isAligned ? '⚡ تم التطابق! جارِ الالتقاط...' : 'وجّه الورقة للالتقاط التلقائي')
                          : 'اضغط لالتقاط الورقة'),
                  style: GoogleFonts.cairo(
                    color: _isAligned ? const Color(0xFF34D399) : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom Viewfinder Painter with Dynamic Alignment Highlighting
class _ViewfinderOverlayPainter extends CustomPainter {
  final int questionCount;
  final bool isAligned;
  final SheetBubbleLayout layout;

  _ViewfinderOverlayPainter({
    required this.questionCount,
    this.isAligned = false,
  }) : layout = OMREngine.computeBubbleLayout(questionCount);

  @override
  void paint(Canvas canvas, Size size) {
    final targetW = size.width * 0.82;
    final targetH = targetW * (1509.0 / 1006.0); // Exact 1.500 ratio
    final targetLeft = (size.width - targetW) / 2.0;
    final targetTop = (size.height - targetH) / 2.0;
    final targetRight = targetLeft + targetW;
    final targetBottom = targetTop + targetH;

    // Dark semi-transparent background around viewfinder
    final bgPaint = Paint()..color = Colors.black.withValues(alpha: 0.45);
    final outerRect = Rect.fromLTRB(targetLeft - 20, targetTop - 20, targetRight + 20, targetBottom + 20);
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(outerRect, const Radius.circular(16)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, bgPaint);

    // Frame border around active scanning area (turns green when aligned!)
    final borderColor = isAligned ? const Color(0xFF10B981) : const Color(0xFF0F766E).withValues(alpha: 0.5);
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = isAligned ? 2.5 : 1.5;
    canvas.drawRRect(RRect.fromRectAndRadius(outerRect, const Radius.circular(16)), borderPaint);

    // 4 Corner Alignment Target Brackets (turns green when aligned!)
    final targetColor = isAligned ? const Color(0xFF10B981) : const Color(0xFF38BDF8);
    final cornerTargetPaint = Paint()
      ..color = targetColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = isAligned ? 4.5 : 3.5
      ..strokeCap = StrokeCap.round;

    const cornerBracketLen = 22.0;
    const boxR = 12.0;

    double mapX(int canonX) => targetLeft + ((canonX - 103) / 1006.0) * targetW;
    double mapY(int canonY) => targetTop + ((canonY - 88) / 1509.0) * targetH;

    final corners = [
      Offset(targetLeft, targetTop),
      Offset(targetRight, targetTop),
      Offset(targetRight, targetBottom),
      Offset(targetLeft, targetBottom),
    ];

    for (int i = 0; i < 4; i++) {
      final c = corners[i];
      // Target center box
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: c, width: boxR * 2, height: boxR * 2),
          const Radius.circular(4),
        ),
        Paint()
          ..color = targetColor.withValues(alpha: isAligned ? 0.40 : 0.20)
          ..style = PaintingStyle.fill,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: c, width: boxR * 2, height: boxR * 2),
          const Radius.circular(4),
        ),
        Paint()
          ..color = targetColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );

      // Outer guide bracket
      final sx = (i == 0 || i == 3) ? -1.0 : 1.0;
      final sy = (i == 0 || i == 1) ? -1.0 : 1.0;
      canvas.drawLine(Offset(c.dx, c.dy + sy * (boxR + 4)), Offset(c.dx, c.dy + sy * (boxR + 4 + cornerBracketLen)), cornerTargetPaint);
      canvas.drawLine(Offset(c.dx + sx * (boxR + 4), c.dy), Offset(c.dx + sx * (boxR + 4 + cornerBracketLen), c.dy), cornerTargetPaint);
    }

    // Small Holo Bubble Circles (turns bright green when aligned!)
    final holoCirclePaint = Paint()
      ..color = targetColor.withValues(alpha: isAligned ? 0.85 : 0.60)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isAligned ? 1.5 : 1.3;

    final circleRadius = (13.0 / 1006.0) * targetW;

    // Model hollow circles (4 bubbles)
    for (final pt in layout.modelCoords.values) {
      canvas.drawCircle(Offset(mapX(pt.x), mapY(pt.y)), circleRadius * 1.05, holoCirclePaint);
    }

    // Roll number hollow circles (all columns)
    for (final col in layout.rollCoords) {
      for (final pt in col) {
        canvas.drawCircle(Offset(mapX(pt.x), mapY(pt.y)), circleRadius * 0.95, holoCirclePaint);
      }
    }

    // MCQ Question hollow circles
    for (final opts in layout.questionCoords.values) {
      for (final pt in opts.values) {
        canvas.drawCircle(Offset(mapX(pt.x), mapY(pt.y)), circleRadius, holoCirclePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ViewfinderOverlayPainter oldDelegate) =>
      oldDelegate.questionCount != questionCount || oldDelegate.isAligned != isAligned;
}

/// Helper class for Isolate
class _OmrParam {
  final Uint8List imageBytes;
  final int questionCount;
  final Map<int, String>? answerKey;

  _OmrParam({
    required this.imageBytes,
    required this.questionCount,
    this.answerKey,
  });
}

OMRScanResult _runOmrScanIsolate(_OmrParam param) {
  final decoded = img.decodeImage(param.imageBytes);
  if (decoded == null) {
    return OMRScanResult(
      success: false,
      error: 'LOW_RESOLUTION',
      message: 'فشل فك تشفير الصورة، يرجى إعادة المحاولة / Failed to decode image, please retake',
    );
  }

  return OMREngine.scanImage(
    decoded,
    param.questionCount,
    param.answerKey,
  );
}
