import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// State of an individual multiple-choice question
enum QuestionState {
  selected,
  empty,
  multiple,
  uncertain,
}

/// Analysis metrics of a single bubble
class BubbleAnalysis {
  final double fillRatio;
  final double netContrast; // 0..255 darkness above paper
  final double normDarkness; // 0..1 darkness relative to local paper
  final double variance;
  final double paperLevel;
  final int snappedX;
  final int snappedY;

  BubbleAnalysis({
    required this.fillRatio,
    required this.netContrast,
    this.normDarkness = 0,
    required this.variance,
    required this.paperLevel,
    this.snappedX = 0,
    this.snappedY = 0,
  });
}

/// Classification result for a question
class QuestionResult {
  final QuestionState state;
  final String? selected;
  final List<String>? multipleSelected;
  final double confidence;
  final Map<String, double> scores;
  final Map<String, math.Point<int>> snappedCoords;

  QuestionResult({
    required this.state,
    this.selected,
    this.multipleSelected,
    required this.confidence,
    required this.scores,
    this.snappedCoords = const {},
  });

  Map<String, dynamic> toJson() => {
        'state': state.name.toUpperCase(),
        'selected': selected,
        'multipleSelected': multipleSelected,
        'confidence': confidence,
      };
}

/// Overall OMR Scan Result
class OMRScanResult {
  final bool success;
  final String? error;
  final String? message;
  final String model;
  final bool modelDetected; // false => model bubble was not found, ask the user
  final String studentCode;
  final Map<int, QuestionResult> answers;
  final int mcqScore;
  final int totalQuestions;
  final int correctCount;
  final int uncertainCount;
  final int multipleCount;
  final int emptyCount;
  final double overallConfidence;
  final img.Image? rectifiedImage;
  final img.Image? annotatedImage;

  OMRScanResult({
    required this.success,
    this.error,
    this.message,
    this.model = 'A',
    this.modelDetected = false,
    this.studentCode = '',
    this.answers = const {},
    this.mcqScore = 0,
    this.totalQuestions = 30,
    this.correctCount = 0,
    this.uncertainCount = 0,
    this.multipleCount = 0,
    this.emptyCount = 0,
    this.overallConfidence = 0.0,
    this.rectifiedImage,
    this.annotatedImage,
  });
}

/// Summed-area table for O(1) box-mean queries
class _Integral {
  final int w, h;
  final Int32List s;

  _Integral(Uint8List gray, this.w, this.h) : s = Int32List((w + 1) * (h + 1)) {
    for (int y = 0; y < h; y++) {
      int rowSum = 0;
      for (int x = 0; x < w; x++) {
        rowSum += gray[y * w + x];
        s[(y + 1) * (w + 1) + x + 1] = s[y * (w + 1) + x + 1] + rowSum;
      }
    }
  }

  double mean(int cx, int cy, int r) {
    final x0 = cx - r, y0 = cy - r, x1 = cx + r + 1, y1 = cy + r + 1;
    final sum = s[y1 * (w + 1) + x1] -
        s[y0 * (w + 1) + x1] -
        s[y1 * (w + 1) + x0] +
        s[y0 * (w + 1) + x0];
    final n = (2 * r + 1) * (2 * r + 1);
    return sum / n;
  }
}

/// High-Precision Pure Dart OMR Computer Vision Engine
class OMREngine {
  static const int targetW = 1200;
  static const int targetH = 1697;

  // Margin (px) a bubble center must keep from the canvas edge.
  static const int _edgeMargin = 25;

  // ---------------------------------------------------------------------------
  // QUALITY GATE
  // ---------------------------------------------------------------------------
  static Map<String, dynamic> checkQuality(img.Image image) {
    final w = image.width;
    final h = image.height;

    if (math.min(w, h) < 600 || math.max(w, h) < 800) {
      return {
        'passed': false,
        'reason': 'LOW_RESOLUTION',
        'message': 'Resolution is too low (minimum 600x800). Hold camera closer.',
      };
    }

    final sampleW = math.min(w, 400);
    final sampleH = math.max(1, (h * sampleW / w).round());
    final sample = img.copyResize(image,
        width: sampleW, height: sampleH, interpolation: img.Interpolation.average);

    double sumLum = 0;
    final pixelCount = sampleW * sampleH;
    final gray = Uint8List(pixelCount);

    for (int y = 0; y < sampleH; y++) {
      for (int x = 0; x < sampleW; x++) {
        final pixel = sample.getPixel(x, y);
        final lum = (pixel.r * 299 + pixel.g * 587 + pixel.b * 114) ~/ 1000;
        gray[y * sampleW + x] = lum;
        sumLum += lum;
      }
    }

    final meanLum = sumLum / pixelCount;
    if (meanLum < 38) {
      return {
        'passed': false,
        'reason': 'TOO_DARK',
        'message': 'Lighting is too dark. Turn on room lights or device flash.',
      };
    }

    double lapSum = 0;
    double lapSqSum = 0;
    int edgeCount = 0;

    for (int y = 2; y < sampleH - 2; y += 2) {
      final row = y * sampleW;
      for (int x = 2; x < sampleW - 2; x += 2) {
        final center = gray[row + x];
        final lap = gray[row + x - 1] +
            gray[row + x + 1] +
            gray[row - sampleW + x] +
            gray[row + sampleW + x] -
            (center * 4);
        lapSum += lap;
        lapSqSum += (lap * lap);
        edgeCount++;
      }
    }

    final lapMean = lapSum / math.max(1, edgeCount);
    final lapVar = (lapSqSum / math.max(1, edgeCount)) - (lapMean * lapMean);

    if (lapVar < 28.0) {
      return {
        'passed': false,
        'reason': 'TOO_BLURRY',
        'message': 'Image is blurry. Hold camera steady and capture again.',
      };
    }

    return {'passed': true};
  }

  // ---------------------------------------------------------------------------
  // HOMOGRAPHY
  // ---------------------------------------------------------------------------
  static List<double>? getPerspectiveTransform(
      List<math.Point<double>> src, List<math.Point<double>> dst) {
    final a = List.generate(8, (_) => List.filled(8, 0.0));
    final b = List.filled(8, 0.0);

    for (int i = 0; i < 4; i++) {
      final sx = src[i].x, sy = src[i].y;
      final dx = dst[i].x, dy = dst[i].y;

      a[i * 2] = [sx, sy, 1.0, 0.0, 0.0, 0.0, -dx * sx, -dx * sy];
      b[i * 2] = dx;

      a[i * 2 + 1] = [0.0, 0.0, 0.0, sx, sy, 1.0, -dy * sx, -dy * sy];
      b[i * 2 + 1] = dy;
    }

    const n = 8;
    for (int i = 0; i < n; i++) {
      int maxRow = i;
      for (int k = i + 1; k < n; k++) {
        if (a[k][i].abs() > a[maxRow][i].abs()) maxRow = k;
      }
      final tmpA = a[i];
      a[i] = a[maxRow];
      a[maxRow] = tmpA;
      final tmpB = b[i];
      b[i] = b[maxRow];
      b[maxRow] = tmpB;

      final pivot = a[i][i];
      if (pivot.abs() < 1e-10) return null; // degenerate quad
      for (int j = i; j < n; j++) {
        a[i][j] /= pivot;
      }
      b[i] /= pivot;

      for (int k = 0; k < n; k++) {
        if (k == i) continue;
        final factor = a[k][i];
        for (int j = i; j < n; j++) {
          a[k][j] -= factor * a[i][j];
        }
        b[k] -= factor * b[i];
      }
    }

    return [b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7], 1.0];
  }

  static List<int> _regX(int numMcqCols) {
    if (numMcqCols == 1) return [100, 480, 1100];
    if (numMcqCols == 2) return [100, 420, 800, 1100];
    if (numMcqCols == 3) return [80, 340, 620, 900, 1120];
    return [60, 290, 530, 770, 1010, 1140];
  }

  // ---------------------------------------------------------------------------
  // RECTIFICATION
  // ---------------------------------------------------------------------------

  /// Public wrapper kept for compatibility. Falls back to a plain resize
  /// (coordinates will NOT line up) - scanImage never uses the fallback.
  static img.Image rectifySheet(img.Image source, int questionCount) {
    return _rectify(source, questionCount) ??
        img.copyResize(source, width: targetW, height: targetH);
  }

  /// Returns null when the sheet could not be located reliably.
  static img.Image? _rectify(img.Image source, int questionCount) {
    final srcW = source.width;
    final srcH = source.height;

    // --- detection runs on a downscaled copy for speed ---
    final detW = math.min(900, srcW);
    final det = detW == srcW
        ? source
        : img.copyResize(source, width: detW, interpolation: img.Interpolation.average);
    final dW = det.width;
    final dH = det.height;
    final sc = srcW / dW;

    final gray = Uint8List(dW * dH);
    double sumLum = 0;
    for (int y = 0; y < dH; y++) {
      for (int x = 0; x < dW; x++) {
        final p = det.getPixel(x, y);
        final lum = (p.r * 299 + p.g * 587 + p.b * 114) ~/ 1000;
        gray[y * dW + x] = lum;
        sumLum += lum;
      }
    }
    final meanLum = sumLum / (dW * dH);

    final minBlob = math.max(5, (dW * 0.006).round());
    final maxBlob = math.max(45, (dW * 0.050).round());
    final visited = Uint8List(dW * dH);
    final candidateDots = <math.Point<double>>[];
    final step = math.max(2, minBlob ~/ 2);
    final darkThresh = math.min(160, math.max(85, (meanLum * 0.65).toInt()));

    for (int y = step; y < dH - step; y += step) {
      for (int x = step; x < dW - step; x += step) {
        final idx = y * dW + x;
        if (visited[idx] == 1 || gray[idx] >= darkThresh) continue;

        int minX = x, maxX = x, minY = y, maxY = y;
        int blobPixels = 0;
        final stack = <int>[idx];
        visited[idx] = 1;

        while (stack.isNotEmpty && blobPixels < 4000) {
          final curr = stack.removeLast();
          final cy = curr ~/ dW;
          final cx = curr - cy * dW;
          blobPixels++;

          if (cx < minX) minX = cx;
          if (cx > maxX) maxX = cx;
          if (cy < minY) minY = cy;
          if (cy > maxY) maxY = cy;

          if (cx > 0) {
            final n = curr - 1;
            if (visited[n] == 0) {
              visited[n] = 1;
              if (gray[n] < darkThresh) stack.add(n);
            }
          }
          if (cx < dW - 1) {
            final n = curr + 1;
            if (visited[n] == 0) {
              visited[n] = 1;
              if (gray[n] < darkThresh) stack.add(n);
            }
          }
          if (cy > 0) {
            final n = curr - dW;
            if (visited[n] == 0) {
              visited[n] = 1;
              if (gray[n] < darkThresh) stack.add(n);
            }
          }
          if (cy < dH - 1) {
            final n = curr + dW;
            if (visited[n] == 0) {
              visited[n] = 1;
              if (gray[n] < darkThresh) stack.add(n);
            }
          }
        }

        final bw = maxX - minX + 1;
        final bh = maxY - minY + 1;
        final aspect = bw / math.max(1, bh);
        final fillDensity = blobPixels / (bw * bh);
        final touchesBorder = minX <= 1 || minY <= 1 || maxX >= dW - 2 || maxY >= dH - 2;

        if (!touchesBorder &&
            bw >= minBlob &&
            bw <= maxBlob &&
            bh >= minBlob &&
            bh <= maxBlob &&
            aspect >= 0.65 &&
            aspect <= 1.45 &&
            fillDensity >= 0.70) {
          candidateDots.add(math.Point((minX + maxX) / 2.0 * sc, (minY + maxY) / 2.0 * sc));
        }
      }
    }

    final bestQuad = _findBestFiducialQuad(candidateDots);
    if (bestQuad == null) return null;

    final tl = bestQuad[0];
    final tr = bestQuad[1];
    final br = bestQuad[2];
    final bl = bestQuad[3];

    double hypot(num dx, num dy) => math.sqrt(dx * dx + dy * dy);
    final boxW = math.max(hypot(tr.x - tl.x, tr.y - tl.y), hypot(br.x - bl.x, br.y - bl.y));
    final boxH = math.max(hypot(bl.x - tl.x, bl.y - tl.y), hypot(br.x - tr.x, br.y - tr.y));
    final aspect = boxW / math.max(1.0, boxH);
    if (aspect < 0.45 || aspect > 1.35) return null;

    final numMcqCols = questionCount <= 20
        ? 1
        : (questionCount <= 40 ? 2 : (questionCount <= 75 ? 3 : 4));
    final regX = _regX(numMcqCols);

    final gridTopY = numMcqCols == 1 ? 566.0 : 480.0;
    final gridBotY = numMcqCols == 1 ? 1473.0 : 1550.0;
    final gridLeftX = numMcqCols == 1 ? 107.0 : regX.first.toDouble();
    final gridRightX = numMcqCols == 1 ? 1103.0 : regX.last.toDouble();

    final List<math.Point<double>> dstCorners;
    // Outer page markers span almost full height from near top (tl.y < srcH * 0.18, aspect < 0.76)
    final isPageCorners = (aspect < 0.76) && (tl.y < srcH * 0.18);
    if (isPageCorners) {
      final pageLeftX = numMcqCols == 1 ? 103.0 : 60.0;
      final pageRightX = numMcqCols == 1 ? 1109.0 : targetW - 60.0;
      final pageTopY = numMcqCols == 1 ? 88.0 : 60.0;
      final pageBotY = numMcqCols == 1 ? 1597.0 : targetH - 60.0;

      dstCorners = [
        math.Point(pageLeftX, pageTopY),
        math.Point(pageRightX, pageTopY),
        math.Point(pageRightX, pageBotY),
        math.Point(pageLeftX, pageBotY),
      ];
    } else {
      dstCorners = [
        math.Point(gridLeftX, gridTopY),
        math.Point(gridRightX, gridTopY),
        math.Point(gridRightX, gridBotY),
        math.Point(gridLeftX, gridBotY),
      ];
    }

    final hInv = getPerspectiveTransform(dstCorners, [tl, tr, br, bl]);
    if (hInv == null) return null;

    // Copy source pixels once into a flat RGB buffer (much faster than getPixel in the loop)
    final rgb = Uint8List(srcW * srcH * 3);
    for (int y = 0; y < srcH; y++) {
      for (int x = 0; x < srcW; x++) {
        final p = source.getPixel(x, y);
        final o = (y * srcW + x) * 3;
        rgb[o] = p.r.toInt();
        rgb[o + 1] = p.g.toInt();
        rgb[o + 2] = p.b.toInt();
      }
    }

    final outImg = img.Image(width: targetW, height: targetH);
    for (int dy = 0; dy < targetH; dy++) {
      for (int dx = 0; dx < targetW; dx++) {
        final denom = hInv[6] * dx + hInv[7] * dy + hInv[8];
        final sx = (hInv[0] * dx + hInv[1] * dy + hInv[2]) / denom;
        final sy = (hInv[3] * dx + hInv[4] * dy + hInv[5]) / denom;

        final px = sx.floor();
        final py = sy.floor();

        if (px >= 0 && px < srcW - 1 && py >= 0 && py < srcH - 1) {
          final fx = sx - px;
          final fy = sy - py;
          final o00 = (py * srcW + px) * 3;
          final o10 = o00 + 3;
          final o01 = o00 + srcW * 3;
          final o11 = o01 + 3;

          double lerp(int c) =>
              (rgb[o00 + c] * (1 - fx) + rgb[o10 + c] * fx) * (1 - fy) +
              (rgb[o01 + c] * (1 - fx) + rgb[o11 + c] * fx) * fy;

          outImg.setPixelRgb(dx, dy, lerp(0).round(), lerp(1).round(), lerp(2).round());
        } else {
          outImg.setPixelRgb(dx, dy, 250, 250, 250);
        }
      }
    }
    return outImg;
  }

  // ---------------------------------------------------------------------------
  // BUBBLE MEASUREMENT (row-level alignment + paper-relative darkness)
  // ---------------------------------------------------------------------------

  /// Robust local paper brightness: mean of the brightest 60% of an annulus.
  static double _paperLevel(Uint8List gray, int cx, int cy, int w) {
    final vals = <int>[];
    for (int dy = -18; dy <= 18; dy += 2) {
      final row = (cy + dy) * w;
      for (int dx = -18; dx <= 18; dx += 2) {
        final d2 = dx * dx + dy * dy;
        if (d2 >= 169 && d2 <= 324) vals.add(gray[row + cx + dx]);
      }
    }
    if (vals.isEmpty) return 240.0;
    vals.sort();
    final start = (vals.length * 0.4).floor();
    double sum = 0;
    for (int i = start; i < vals.length; i++) {
      sum += vals[i];
    }
    return sum / (vals.length - start);
  }

  /// Analyzes a group of bubbles that share one alignment error (one question row,
  /// or one roll-number column). One shared offset is found for the whole group,
  /// which is far more stable than snapping every bubble on its own.
  static List<BubbleAnalysis> _analyzePoints(
    Uint8List gray,
    _Integral ii,
    List<math.Point<int>> pts,
    int w,
    int h, {
    int searchR = 10,
    int rCore = 6,
  }) {
    for (final p in pts) {
      if (p.x < _edgeMargin || p.x >= w - _edgeMargin || p.y < _edgeMargin || p.y >= h - _edgeMargin) {
        return [
          for (final p in pts)
            BubbleAnalysis(
                fillRatio: 0,
                netContrast: 0,
                normDarkness: 0,
                variance: 0,
                paperLevel: 245,
                snappedX: p.x,
                snappedY: p.y)
        ];
      }
    }

    // 1. shared offset: the one that exposes the darkest core in the group,
    //    with a small penalty so empty rows do not drift.
    int bdx = 0, bdy = 0;
    double bestObj = -1e9;
    for (int dy = -searchR; dy <= searchR; dy++) {
      for (int dx = -searchR; dx <= searchR; dx++) {
        double minMean = 255;
        for (final p in pts) {
          final m = ii.mean(p.x + dx, p.y + dy, 4);
          if (m < minMean) minMean = m;
        }
        final obj = (255 - minMean) - 0.5 * math.sqrt((dx * dx + dy * dy).toDouble());
        if (obj > bestObj) {
          bestObj = obj;
          bdx = dx;
          bdy = dy;
        }
      }
    }

    // 2. paper level per bubble, then the median for the group
    final papers = <double>[
      for (final p in pts) _paperLevel(gray, p.x + bdx, p.y + bdy, w),
    ];
    final sortedP = List<double>.from(papers)..sort();
    final mid = sortedP.length ~/ 2;
    final groupPaper = sortedP.length.isOdd ? sortedP[mid] : (sortedP[mid - 1] + sortedP[mid]) / 2;
    final fillThresh = groupPaper * 0.82;

    // 3. core statistics
    final r2 = rCore * rCore;
    final out = <BubbleAnalysis>[];
    for (final p in pts) {
      final cx = p.x + bdx;
      final cy = p.y + bdy;
      double sum = 0, sqSum = 0;
      int count = 0, filled = 0;
      for (int dy = -rCore; dy <= rCore; dy++) {
        final row = (cy + dy) * w;
        for (int dx = -rCore; dx <= rCore; dx++) {
          if (dx * dx + dy * dy <= r2) {
            final lum = gray[row + cx + dx];
            sum += lum;
            sqSum += lum * lum;
            count++;
            if (lum < fillThresh) filled++;
          }
        }
      }
      final mean = count > 0 ? sum / count : 255.0;
      final variance = count > 0 ? math.max(0.0, sqSum / count - mean * mean) : 0.0;
      final norm = math.max(0.0, (groupPaper - mean) / math.max(1.0, groupPaper));
      out.add(BubbleAnalysis(
        fillRatio: count > 0 ? filled / count : 0.0,
        netContrast: math.max(0.0, groupPaper - mean),
        normDarkness: norm,
        variance: variance,
        paperLevel: groupPaper,
        snappedX: cx,
        snappedY: cy,
      ));
    }
    return out;
  }

  static double _rawScore(BubbleAnalysis a) =>
      0.5 * a.fillRatio + 0.5 * math.min(1.0, a.normDarkness / 0.30);

  /// Scores relative to the least-marked bubble of the group, so printed letters
  /// or faint rings inside the bubble do not count as marks.
  static List<double> _adjustedScores(List<BubbleAnalysis> an) {
    final raw = [for (final a in an) _rawScore(a)];
    final base = raw.reduce(math.min);
    return [for (final r in raw) math.max(0.0, r - base)];
  }

  static QuestionResult _classify(
      Uint8List gray, _Integral ii, Map<String, math.Point<int>> coords, int w, int h) {
    const opts = ['A', 'B', 'C', 'D'];
    final an = _analyzePoints(gray, ii, [for (final o in opts) coords[o]!], w, h);
    final raw = [for (final a in an) _rawScore(a)];
    final base = raw.reduce(math.min);
    final adj = [for (final r in raw) math.max(0.0, r - base)];

    final scoreMap = {for (int i = 0; i < 4; i++) opts[i]: adj[i]};
    final snapped = {
      for (int i = 0; i < 4; i++) opts[i]: math.Point(an[i].snappedX, an[i].snappedY)
    };

    // all four bubbles dark -> scribbled / fully shaded
    if (base >= 0.50) {
      return QuestionResult(
        state: QuestionState.multiple,
        selected: 'A',
        multipleSelected: List<String>.from(opts),
        confidence: 0.5,
        scores: scoreMap,
        snappedCoords: snapped,
      );
    }

    final order = [0, 1, 2, 3]..sort((a, b) => adj[b].compareTo(adj[a]));
    final bi = order[0], si = order[1];
    final best = adj[bi], second = adj[si];
    final margin = best - second;

    // EMPTY
    if (best < 0.18) {
      return QuestionResult(
        state: QuestionState.empty,
        confidence: (1.0 - best).clamp(0.0, 1.0),
        scores: scoreMap,
        snappedCoords: snapped,
      );
    }

    // MULTIPLE: two clearly marked bubbles
    if (second >= 0.35 && second >= 0.65 * best) {
      return QuestionResult(
        state: QuestionState.multiple,
        selected: opts[bi],
        multipleSelected: [opts[bi], opts[si]],
        confidence: second,
        scores: scoreMap,
        snappedCoords: snapped,
      );
    }

    // UNCERTAIN: faint mark or small margin. The best guess is still returned.
    if (best < 0.30 || margin < 0.12) {
      return QuestionResult(
        state: QuestionState.uncertain,
        selected: opts[bi],
        confidence: best.clamp(0.0, 1.0),
        scores: scoreMap,
        snappedCoords: snapped,
      );
    }

    // SELECTED
    return QuestionResult(
      state: QuestionState.selected,
      selected: opts[bi],
      confidence: (0.70 + margin * 0.5).clamp(0.80, 0.99),
      scores: scoreMap,
      snappedCoords: snapped,
    );
  }

  /// Public wrapper (same signature as before)
  static QuestionResult classifyQuestion(
      Uint8List gray, Map<String, math.Point<int>> coords, int w, int h) {
    return _classify(gray, _Integral(gray, w, h), coords, w, h);
  }

  // ---------------------------------------------------------------------------
  // MASTER PIPELINE
  // ---------------------------------------------------------------------------
  static OMRScanResult scanImage(img.Image rawImage, int questionCount,
      [Map<int, String>? answerKey]) {
    // Apply EXIF rotation, then require a portrait photo
    var image = img.bakeOrientation(rawImage);

    if (math.min(image.width, image.height) < 600 || math.max(image.width, image.height) < 800) {
      return OMRScanResult(
        success: false,
        error: 'LOW_RESOLUTION',
        message: 'Resolution is too low (minimum 600x800). Hold camera closer.',
      );
    }
    if (image.width > image.height) {
      return OMRScanResult(
        success: false,
        error: 'NOT_PORTRAIT',
        message: 'Hold the phone upright (portrait) so the sheet fills the screen.',
      );
    }
    if (image.width > 1800) {
      image = img.copyResize(image, width: 1800, interpolation: img.Interpolation.average);
    }

    final quality = checkQuality(image);
    if (quality['passed'] != true) {
      return OMRScanResult(
        success: false,
        error: quality['reason'],
        message: quality['message'],
      );
    }

    // Rectify to canonical 1200x1697. NO silent fallback: if the sheet is not found, fail.
    final rectified = _rectify(image, questionCount);
    if (rectified == null) {
      return OMRScanResult(
        success: false,
        error: 'SHEET_NOT_FOUND',
        message:
            'Could not find the sheet corners. Make sure all 4 black corner squares are visible, the sheet is flat and the phone is upright.',
      );
    }

    final gray = Uint8List(targetW * targetH);
    for (int y = 0; y < targetH; y++) {
      for (int x = 0; x < targetW; x++) {
        final p = rectified.getPixel(x, y);
        // Weights red/green so blue ink and graphite both give strong contrast
        gray[y * targetW + x] = (p.r * 500 + p.g * 400 + p.b * 100) ~/ 1000;
      }
    }
    final ii = _Integral(gray, targetW, targetH);

    final qCount = questionCount.clamp(1, 100);
    final numMcqCols = qCount <= 20 ? 1 : (qCount <= 40 ? 2 : (qCount <= 75 ? 3 : 4));
    final qPerCol = (qCount / numMcqCols).ceil();

    // 1. Model detection (band search) - needs ONE clear mark and three clean bubbles
    String detectedModel = 'A';
    bool modelDetected = false;
    double bestModelMargin = -1.0;
    int detectedModelX = 360;
    int detectedModelY = 476;

    const candidateModelYs = [
      476, 460, 490, 505, // Primary: True template position (~476)
      240, 255, 265, 280, 300, 320, 340, 360, // Secondary: older/custom headers
    ];
    const candidateXConfigs = [
      [357, 452, 545, 640], // Primary: True single-column template spacing
      [360, 440, 520, 600], // wide table spacing
      [250, 290, 330, 370], // narrow table spacing
    ];
    const opts = ['A', 'B', 'C', 'D'];

    for (final my in candidateModelYs) {
      for (final xs in candidateXConfigs) {
        final coords = {
          for (int i = 0; i < 4; i++) opts[i]: math.Point(xs[i], my),
        };
        final res = _classify(gray, ii, coords, targetW, targetH);
        if (res.selected == null) continue;
        if (res.state != QuestionState.selected && res.state != QuestionState.uncertain) continue;
        final sc = res.scores.values.toList()..sort((a, b) => b.compareTo(a));
        final best = sc[0], second = sc[1];
        if (best < 0.22 || second > 0.65 * best) continue;
        final margin = best - second;
        if (margin > bestModelMargin) {
          bestModelMargin = margin;
          detectedModel = res.selected!;
          modelDetected = true;
          final snapped = res.snappedCoords[res.selected!];
          detectedModelX = snapped?.x ?? xs[opts.indexOf(res.selected!)];
          detectedModelY = snapped?.y ?? my;
        }
      }
    }

    // 2. Student roll number (5 digits)
    final rollRowYs = numMcqCols == 1
        ? const [691, 734, 778, 822, 866, 909, 953, 997, 1041, 1083]
        : const [604, 655, 706, 757, 808, 859, 910, 961, 1012, 1063];
    final rollColXs = numMcqCols == 1
        ? const [197, 240, 282, 325, 367]
        : const [196, 242, 289, 335, 382];
    final detectedRollCoords = <math.Point<int>>[];
    final idDigits = <String>[];

    for (final cx in rollColXs) {
      final an = _analyzePoints(
          gray, ii, [for (final cy in rollRowYs) math.Point(cx, cy)], targetW, targetH);
      final adj = _adjustedScores(an);
      final order = List<int>.generate(10, (i) => i)..sort((a, b) => adj[b].compareTo(adj[a]));
      final best = adj[order[0]];
      final second = adj[order[1]];
      if (best > 0.20 && (best - second) > 0.06) {
        idDigits.add(order[0].toString());
        detectedRollCoords.add(math.Point(an[order[0]].snappedX, an[order[0]].snappedY));
      } else {
        idDigits.add('?');
      }
    }
    final detectedCode = idDigits.join();

    // 3. MCQ questions
    final answers = <int, QuestionResult>{};
    const optOffsets = [0.32, 0.49, 0.66, 0.83];

    final qYs15 = [
      634, 680, 728, 774, 820,
      925, 971, 1017, 1065, 1111,
      1214, 1261, 1307, 1353, 1401,
    ];
    final optXs15 = [683, 752, 825, 895];

    final regX = _regX(numMcqCols);
    final gridTopY = numMcqCols == 1 ? 566.0 : 480.0;
    final isSpacious = qPerCol <= 16;
    final isMedium = qPerCol > 16 && qPerCol <= 24;
    final rowStepY = isSpacious ? 48.0 : (isMedium ? 42.0 : 36.0);
    final blockHeaderH = isSpacious ? 42.0 : (isMedium ? 36.0 : 30.0);
    final blockSpacerH = isSpacious ? 38.0 : (isMedium ? 28.0 : 20.0);
    final colStartY = gridTopY + (isSpacious ? 25.0 : 18.0);

    int uncertainCount = 0;
    int multipleCount = 0;
    int emptyCount = 0;
    int correctCount = 0;
    double totalConfidence = 0.0;

    final questionCoords = <int, Map<String, math.Point<int>>>{};

    for (int q = 1; q <= qCount; q++) {
      final Map<String, math.Point<int>> coords;
      if (numMcqCols == 1 && qCount <= 15 && (q - 1) < qYs15.length) {
        final qy = qYs15[q - 1];
        coords = {for (int i = 0; i < 4; i++) opts[i]: math.Point(optXs15[i], qy)};
      } else {
        final colIdx = (q - 1) ~/ qPerCol;
        final inCol = (q - 1) % qPerCol;
        final blockIdx = inCol ~/ 5;
        final posInBlock = inCol % 5;

        final xLeft = regX[colIdx + 1];
        final xRight = regX[colIdx + 2];
        final rawColW = xRight - xLeft;
        final effColW = math.min(rawColW, (numMcqCols == 1 ? 320 : 340));
        final colCenterX = (xLeft + xRight) / 2.0;
        final effColLeft = (numMcqCols == 1) ? (colCenterX - effColW / 2.0) : xLeft.toDouble();

        final qy = (colStartY +
                (blockIdx * (5 * rowStepY + blockHeaderH + blockSpacerH)) +
                blockHeaderH +
                (posInBlock * rowStepY))
            .round();

        coords = {
          for (int i = 0; i < 4; i++)
            opts[i]: math.Point((effColLeft + effColW * optOffsets[i]).round(), qy),
        };
      }

      questionCoords[q] = coords;
      final res = _classify(gray, ii, coords, targetW, targetH);
      answers[q] = res;

      totalConfidence += res.confidence;
      if (res.state == QuestionState.uncertain) uncertainCount++;
      if (res.state == QuestionState.multiple) multipleCount++;
      if (res.state == QuestionState.empty) emptyCount++;

      // The best guess of an UNCERTAIN answer is graded too (it is flagged for review).
      if (answerKey != null && answerKey[q] != null) {
        final counted = res.state == QuestionState.selected || res.state == QuestionState.uncertain;
        if (counted && res.selected == answerKey[q]) correctCount++;
      }
    }

    final overallConf = (totalConfidence / qCount).clamp(0.0, 1.0);

    // Annotated overlay
    final annotated = rectified.clone();
    final green = img.ColorRgb8(16, 185, 129);

    if (modelDetected) {
      img.drawCircle(annotated, x: detectedModelX, y: detectedModelY, radius: 16, color: green);
    }
    for (final pt in detectedRollCoords) {
      img.drawCircle(annotated, x: pt.x, y: pt.y, radius: 14, color: green);
    }

    for (int q = 1; q <= qCount; q++) {
      final ans = answers[q]!;
      final coords = questionCoords[q];
      if (coords == null) continue;

      if ((ans.state == QuestionState.selected) && ans.selected != null) {
        final pt = ans.snappedCoords[ans.selected!] ?? coords[ans.selected!]!;
        img.drawCircle(annotated, x: pt.x, y: pt.y, radius: 14, color: green);
      } else if (ans.state == QuestionState.uncertain) {
        final a = coords['A']!, d = coords['D']!;
        img.drawRect(annotated,
            x1: a.x - 20, y1: a.y - 14, x2: d.x + 20, y2: d.y + 14,
            color: img.ColorRgb8(245, 158, 11));
      } else if (ans.state == QuestionState.multiple) {
        final a = coords['A']!, d = coords['D']!;
        img.drawRect(annotated,
            x1: a.x - 20, y1: a.y - 14, x2: d.x + 20, y2: d.y + 14,
            color: img.ColorRgb8(239, 68, 68));
      } else if (ans.state == QuestionState.empty) {
        final a = coords['A']!, d = coords['D']!;
        img.drawRect(annotated,
            x1: a.x - 20, y1: a.y - 14, x2: d.x + 20, y2: d.y + 14,
            color: img.ColorRgb8(148, 163, 184));
      }
    }

    return OMRScanResult(
      success: true,
      model: detectedModel,
      modelDetected: modelDetected,
      studentCode: detectedCode,
      answers: answers,
      mcqScore: correctCount,
      totalQuestions: qCount,
      correctCount: correctCount,
      uncertainCount: uncertainCount,
      multipleCount: multipleCount,
      emptyCount: emptyCount,
      overallConfidence: overallConf,
      rectifiedImage: rectified,
      annotatedImage: annotated,
    );
  }

  // ---------------------------------------------------------------------------
  // FIDUCIAL QUAD SELECTION
  // ---------------------------------------------------------------------------
  static List<math.Point<double>>? _findBestFiducialQuad(List<math.Point<double>> dots) {
    if (dots.length < 4) return null;

    double hypot(num dx, num dy) => math.sqrt(dx * dx + dy * dy);

    bool isValidQuad(math.Point<double> tl, math.Point<double> tr, math.Point<double> br,
        math.Point<double> bl) {
      // 1. Strict directional sanity
      if (tr.x <= tl.x + 40) return false;
      if (br.x <= bl.x + 40) return false;
      if (bl.y <= tl.y + 40) return false;
      if (br.y <= tr.y + 40) return false;

      // 2. Minimum side lengths
      final wTop = hypot(tr.x - tl.x, tr.y - tl.y);
      final wBot = hypot(br.x - bl.x, br.y - bl.y);
      final hLeft = hypot(bl.x - tl.x, bl.y - tl.y);
      final hRight = hypot(br.x - tr.x, br.y - tr.y);

      if (math.min(math.min(wTop, wBot), math.min(hLeft, hRight)) < 50) return false;
      if (math.min(wTop, wBot) / math.max(wTop, wBot) < 0.60) return false;
      if (math.min(hLeft, hRight) / math.max(hLeft, hRight) < 0.60) return false;

      // 3. Top and bottom edges are primarily horizontal; left and right vertical
      if ((tr.x - tl.x).abs() < (tr.y - tl.y).abs() * 1.3) return false;
      if ((br.x - bl.x).abs() < (br.y - bl.y).abs() * 1.3) return false;
      if ((bl.y - tl.y).abs() < (bl.x - tl.x).abs() * 1.3) return false;
      if ((br.y - tr.y).abs() < (br.x - tr.x).abs() * 1.3) return false;

      // 4. Horizontal and vertical parallelism (atan2(dy, dx))
      final angTop = math.atan2(tr.y - tl.y, tr.x - tl.x);
      final angBot = math.atan2(br.y - bl.y, br.x - bl.x);
      var diffH = (angTop - angBot).abs();
      if (diffH > math.pi) diffH = 2 * math.pi - diffH;
      if (diffH > 0.32) return false;

      final angLeft = math.atan2(bl.y - tl.y, bl.x - tl.x);
      final angRight = math.atan2(br.y - tr.y, br.x - tr.x);
      var diffV = (angLeft - angRight).abs();
      if (diffV > math.pi) diffV = 2 * math.pi - diffV;
      if (diffV > 0.32) return false;

      return true;
    }

    // Try 1: extreme points (picks the outer page corners when they are visible)
    math.Point<double> tl = dots[0], tr = dots[0], br = dots[0], bl = dots[0];
    double minSum = double.infinity, maxSum = -double.infinity;
    double minDiff = double.infinity, maxDiff = -double.infinity;

    for (final pt in dots) {
      final s = pt.x + pt.y;
      final d = pt.x - pt.y;
      if (s < minSum) { minSum = s; tl = pt; }
      if (s > maxSum) { maxSum = s; br = pt; }
      if (d > maxDiff) { maxDiff = d; tr = pt; }
      if (d < minDiff) { minDiff = d; bl = pt; }
    }

    if (isValidQuad(tl, tr, br, bl)) return [tl, tr, br, bl];

    // Try 2: consistent candidate subsets
    final sortedByY = List<math.Point<double>>.from(dots)..sort((a, b) => a.y.compareTo(b.y));
    final half = sortedByY.length ~/ 2;
    final topHalf = sortedByY.sublist(0, half)..sort((a, b) => a.x.compareTo(b.x));
    final botHalf = sortedByY.sublist(half)..sort((a, b) => a.x.compareTo(b.x));

    final topCandL = topHalf.take(math.min(5, topHalf.length)).toList();
    final topCandR = topHalf.reversed.take(math.min(5, topHalf.length)).toList();
    final botCandL = botHalf.take(math.min(5, botHalf.length)).toList();
    final botCandR = botHalf.reversed.take(math.min(5, botHalf.length)).toList();

    List<math.Point<double>>? bestQuad;
    double maxArea = 0;

    for (final cTl in topCandL) {
      for (final cTr in topCandR) {
        if (cTl == cTr) continue;
        for (final cBr in botCandR) {
          for (final cBl in botCandL) {
            if (cBr == cBl || cTl == cBl || cTr == cBr || cBl == cTr) continue;
            if (isValidQuad(cTl, cTr, cBr, cBl)) {
              final area = 0.5 *
                  ((cTl.x * cTr.y - cTl.y * cTr.x) +
                          (cTr.x * cBr.y - cTr.y * cBr.x) +
                          (cBr.x * cBl.y - cBr.y * cBl.x) +
                          (cBl.x * cTl.y - cBl.y * cTl.x))
                      .abs();
              if (area > maxArea) {
                maxArea = area;
                bestQuad = [cTl, cTr, cBr, cBl];
              }
            }
          }
        }
      }
    }

    return bestQuad;
  }
}
