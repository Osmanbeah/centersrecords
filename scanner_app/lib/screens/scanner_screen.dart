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
  String _statusMessage = 'اضبط ورقة الإجابة داخل الإطار';
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

      // Pick back camera
      final backCamera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      final controller = CameraController(
        backCamera,
        ResolutionPreset.veryHigh,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      _cameraController = controller;
      await controller.initialize();

      // Configure autofocus & auto exposure
      try {
        await controller.setFocusMode(FocusMode.auto);
        await controller.setFlashMode(FlashMode.off);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _statusMessage = 'اضبط ورقة الإجابة داخل الإطار واقترب كفاية';
        });
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

      final XFile photo = await _cameraController!.takePicture();
      final bytes = await photo.readAsBytes();

      await _processImageBytes(bytes);
    } catch (e) {
      setState(() => _isProcessing = false);
      _showError('فشل التقاط الصورة: $e');
    }
  }

  Future<void> _processImageBytes(Uint8List rawBytes) async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'جارِ فحص الجودة وتصحيح المنظور OMR...';
    });

    try {
      // Decode image
      final decoded = await compute(_decodeImageIsolate, rawBytes);
      if (decoded == null) {
        setState(() => _isProcessing = false);
        _showError('فشل فك تشفير الصورة، يرجى المحاولة مرة أخرى.');
        return;
      }

      // Quality check
      final quality = OMREngine.checkQuality(decoded);
      if (quality['passed'] != true) {
        setState(() => _isProcessing = false);
        _showQualityWarning(quality['message'] ?? 'جودة الصورة غير كافية', rawBytes, decoded);
        return;
      }

      // Execute OMR Scan
      final scanResult = await compute(_runOmrScanIsolate, _OmrParam(
        imageBytes: rawBytes,
        questionCount: widget.exam.questionCount,
        answerKey: widget.exam.getAnswerKey('A'),
      ));

      setState(() => _isProcessing = false);

      if (!scanResult.success) {
        _showScanErrorDialog(scanResult.error ?? 'لم نتمكن من تحديد الورقة', rawBytes);
        return;
      }

      // Successfully detected! Navigate to ReviewScreen
      if (mounted) {
        Navigator.push(
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
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      _showError('حدث خطأ أثناء معالجة الورقة: $e');
    }
  }

  void _showQualityWarning(String reason, Uint8List rawBytes, img.Image decoded) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B)),
            const SizedBox(width: 8),
            Text('تنبيه جودة الصورة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          '$reason\n\nيُفضل الاقتراب أكثر من الورقة وتوفير إضاءة واضحة ومستقيمة للحصول على أدق نتيجة.',
          style: GoogleFonts.cairo(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F766E)),
            onPressed: () {
              Navigator.pop(ctx);
              // Force scan anyway
              _forceScan(rawBytes);
            },
            child: Text('المتابعة على أي حال', style: GoogleFonts.cairo(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _forceScan(Uint8List rawBytes) async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'جارِ المعالجة الإجبارية...';
    });

    final scanResult = await compute(_runOmrScanIsolate, _OmrParam(
      imageBytes: rawBytes,
      questionCount: widget.exam.questionCount,
      answerKey: widget.exam.getAnswerKey('A'),
    ));

    setState(() => _isProcessing = false);

    if (!scanResult.success) {
      _showScanErrorDialog(scanResult.error ?? 'فشل التعرف على الورقة', rawBytes);
      return;
    }

    if (mounted) {
      Navigator.push(
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
    }
  }

  void _showScanErrorDialog(String error, Uint8List rawBytes) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFEF4444)),
            const SizedBox(width: 8),
            Text('تعذر قراءة الورقة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          '$error\n\nنصائح للحصول على قراءة مثالية 100%:\n• اقترب من الورقة بحيث تملأ الشاشة.\n• تأكد أن المربعات السوداء الأربعة في أطراف الورقة ظاهرة بالكامل.\n• تجنب الظلال الكثيفة أو الإمالة الحادة.',
          style: GoogleFonts.cairo(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إعادة التصوير', style: GoogleFonts.cairo(color: const Color(0xFF0F766E), fontWeight: FontWeight.bold)),
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
        title: Text(
          'مسح ورقة: ${widget.exam.title}',
          style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
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
            painter: _ViewfinderOverlayPainter(),
          ),

          // Guidance Prompt Bar at Top
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF0F766E), width: 1.2),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFF38BDF8), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _statusMessage,
                      style: GoogleFonts.cairo(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Controls (Shutter Button)
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Column(
              children: [
                GestureDetector(
                  onTap: _isProcessing ? null : _takePictureAndScan,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      color: _isProcessing ? Colors.grey : const Color(0xFF0F766E),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F766E).withValues(alpha: 0.5),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: _isProcessing
                        ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                        : const Icon(Icons.camera_alt, color: Colors.white, size: 36),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _isProcessing ? 'جارِ التحليل...' : 'اضغط لالتقاط وتصحيح الورقة',
                  style: GoogleFonts.cairo(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom Viewfinder Painter with Corner Brackets
class _ViewfinderOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final frameW = size.width * 0.88;
    final frameH = frameW * 1.414; // A4 Sheet ratio
    final left = (size.width - frameW) / 2.0;
    final top = (size.height - frameH) / 2.0 - 20;
    final rect = Rect.fromLTWH(left, top, frameW, frameH);

    // Dark semi-transparent background around viewfinder
    final bgPaint = Paint()..color = Colors.black.withValues(alpha: 0.45);
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, bgPaint);

    // Frame border
    final borderPaint = Paint()
      ..color = const Color(0xFF0F766E).withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16)), borderPaint);

    // Corner brackets
    final cornerPaint = Paint()
      ..color = const Color(0xFF14B8A6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;

    const cornerLen = 28.0;

    // Top-Left
    canvas.drawLine(Offset(left, top + cornerLen), Offset(left, top), cornerPaint);
    canvas.drawLine(Offset(left, top), Offset(left + cornerLen, top), cornerPaint);

    // Top-Right
    canvas.drawLine(Offset(left + frameW - cornerLen, top), Offset(left + frameW, top), cornerPaint);
    canvas.drawLine(Offset(left + frameW, top), Offset(left + frameW, top + cornerLen), cornerPaint);

    // Bottom-Left
    canvas.drawLine(Offset(left, top + frameH - cornerLen), Offset(left, top + frameH), cornerPaint);
    canvas.drawLine(Offset(left, top + frameH), Offset(left + cornerLen, top + frameH), cornerPaint);

    // Bottom-Right
    canvas.drawLine(Offset(left + frameW - cornerLen, top + frameH), Offset(left + frameW, top + frameH), cornerPaint);
    canvas.drawLine(Offset(left + frameW, top + frameH - cornerLen), Offset(left + frameW, top + frameH), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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

img.Image? _decodeImageIsolate(Uint8List bytes) {
  return img.decodeImage(bytes);
}

OMRScanResult _runOmrScanIsolate(_OmrParam param) {
  final decoded = img.decodeImage(param.imageBytes);
  if (decoded == null) {
    return OMRScanResult(success: false, error: 'فشل فك تشفير الصورة');
  }

  return OMREngine.scanImage(
    decoded,
    param.questionCount,
    param.answerKey,
  );
}
