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

/// Analysis metrics of a single bubble with local centroid snapping
class BubbleAnalysis {
  final double fillRatio;
  final double netContrast;
  final double variance;
  final double paperLevel;
  final int snappedX;
  final int snappedY;

  BubbleAnalysis({
    required this.fillRatio,
    required this.netContrast,
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

/// High-Precision Pure Dart OMR Computer Vision Engine
class OMREngine {
  static const int targetW = 1200;
  static const int targetH = 1697;

  /// Quality Gate: Checks for blur, darkness, low resolution, and camera distance
  static Map<String, dynamic> checkQuality(img.Image image) {
    final w = image.width;
    final h = image.height;

    if (w < 600 || h < 800) {
      return {
        'passed': false,
        'reason': 'LOW_RESOLUTION',
        'message': 'Resolution is too low (minimum 600x800). Hold camera closer.',
      };
    }

    // Downsample for fast (sub-5ms) metric calculation
    final sampleW = math.min(w, 400);
    final sampleH = math.min(h, 533);
    final sample = img.copyResize(image, width: sampleW, height: sampleH);

    double sumLum = 0;
    int pixelCount = sampleW * sampleH;
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

    // Fast Laplacian Variance for blur detection
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

    final lapMean = lapSum / edgeCount;
    final lapVar = (lapSqSum / edgeCount) - (lapMean * lapMean);

    if (lapVar < 28.0) {
      return {
        'passed': false,
        'reason': 'TOO_BLURRY',
        'message': 'Image is blurry. Hold camera steady and capture again.',
      };
    }

    // Sheet Distance / Framing Check
    int darkCount = 0;
    int minDarkX = sampleW, maxDarkX = 0, minDarkY = sampleH, maxDarkY = 0;
    final darkThresh = math.min(85, (meanLum * 0.55).toInt());

    for (int y = 10; y < sampleH - 10; y += 4) {
      final row = y * sampleW;
      for (int x = 10; x < sampleW - 10; x += 4) {
        if (gray[row + x] < darkThresh) {
          darkCount++;
          if (x < minDarkX) minDarkX = x;
          if (x > maxDarkX) maxDarkX = x;
          if (y < minDarkY) minDarkY = y;
          if (y > maxDarkY) maxDarkY = y;
        }
      }
    }

    final spanW = (maxDarkX > minDarkX) ? (maxDarkX - minDarkX) / sampleW : 0.0;
    final spanH = (maxDarkY > minDarkY) ? (maxDarkY - minDarkY) / sampleH : 0.0;

    if (darkCount > 15 && (spanW < 0.40 || spanH < 0.35)) {
      return {
        'passed': false,
        'reason': 'SHEET_TOO_FAR',
        'message': 'Move Closer (الورقة بعيدة جداً): Please hold your phone closer so the sheet fills the frame.',
      };
    }

    return {'passed': true};
  }

  /// Solves 3x3 Projective Homography Matrix using Gaussian Elimination
  static List<double>? getPerspectiveTransform(List<math.Point<double>> src, List<math.Point<double>> dst) {
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

    // Gaussian elimination
    const n = 8;
    for (int i = 0; i < n; i++) {
      int maxRow = i;
      for (int k = i + 1; k < n; k++) {
        if (a[k][i].abs() > a[maxRow][i].abs()) maxRow = k;
      }
      final tmpA = a[i]; a[i] = a[maxRow]; a[maxRow] = tmpA;
      final tmpB = b[i]; b[i] = b[maxRow]; b[maxRow] = tmpB;

      final pivot = a[i][i];
      if (pivot.abs() < 1e-10) continue;
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

  /// Rectifies any tilted/rotated photo onto standard 1200x1697 canvas
  static img.Image rectifySheet(img.Image source, int questionCount) {
    final srcW = source.width;
    final srcH = source.height;

    // Convert to grayscale array for fast candidate blob search
    final gray = Uint8List(srcW * srcH);
    double sumLum = 0;
    for (int y = 0; y < srcH; y++) {
      for (int x = 0; x < srcW; x++) {
        final p = source.getPixel(x, y);
        final lum = (p.r * 299 + p.g * 587 + p.b * 114) ~/ 1000;
        gray[y * srcW + x] = lum;
        sumLum += lum;
      }
    }
    final meanLum = sumLum / (srcW * srcH);

    final minBlob = math.max(6, (srcW * 0.006).round());
    final maxBlob = math.max(50, (srcW * 0.050).round());
    final visited = Uint8List(srcW * srcH);
    final candidateDots = <math.Point<double>>[];
    final step = math.max(3, minBlob ~/ 2);
    final darkThresh = math.min(95, math.max(65, (meanLum * 0.45).toInt()));

    for (int y = step; y < srcH - step; y += step) {
      for (int x = step; x < srcW - step; x += step) {
        final idx = y * srcW + x;
        if (visited[idx] == 1 || gray[idx] >= darkThresh) continue;

        int minX = x, maxX = x, minY = y, maxY = y;
        int blobPixels = 0;
        final queue = <int>[idx];
        visited[idx] = 1;

        while (queue.isNotEmpty && queue.length < 3500) {
          final curr = queue.removeLast();
          final cy = curr ~/ srcW;
          final cx = curr % srcW;
          blobPixels++;

          if (cx < minX) minX = cx;
          if (cx > maxX) maxX = cx;
          if (cy < minY) minY = cy;
          if (cy > maxY) maxY = cy;

          final neighbors = [curr - 1, curr + 1, curr - srcW, curr + srcW];
          for (final nIdx in neighbors) {
            if (nIdx >= 0 && nIdx < visited.length && visited[nIdx] == 0) {
              visited[nIdx] = 1;
              if (gray[nIdx] < darkThresh) {
                queue.add(nIdx);
              }
            }
          }
        }

        final bw = maxX - minX + 1;
        final bh = maxY - minY + 1;
        final aspect = bw / math.max(1, bh);
        final fillDensity = blobPixels / (bw * bh);

        if (bw >= minBlob &&
            bw <= maxBlob &&
            bh >= minBlob &&
            bh <= maxBlob &&
            aspect >= 0.70 &&
            aspect <= 1.40 &&
            fillDensity >= 0.80) {
          candidateDots.add(math.Point((minX + maxX) / 2.0, (minY + maxY) / 2.0));
        }
      }
    }

    // If at least 4 fiducials are found, warp with homography
    // Robust Quadrilateral Detection (EvalBee-Style) to prevent mixing outer & inner fiducials
    final bestQuad = _findBestFiducialQuad(candidateDots);
    if (bestQuad != null) {
      final tl = bestQuad[0];
      final tr = bestQuad[1];
      final br = bestQuad[2];
      final bl = bestQuad[3];

      double hypot(num dx, num dy) => math.sqrt(dx * dx + dy * dy);
      final boxW = math.max(
          hypot(tr.x - tl.x, tr.y - tl.y),
          hypot(br.x - bl.x, br.y - bl.y));
      final boxH = math.max(
          hypot(bl.x - tl.x, bl.y - tl.y),
          hypot(br.x - tr.x, br.y - tr.y));
      final aspect = boxW / math.max(1.0, boxH);

      final numMcqCols = questionCount <= 20 ? 1 : (questionCount <= 40 ? 2 : (questionCount <= 75 ? 3 : 4));
      late final List<int> regX;
      if (numMcqCols == 1) {
        regX = [100, 480, 1100];
      } else if (numMcqCols == 2) {
        regX = [100, 420, 800, 1100];
      } else if (numMcqCols == 3) {
        regX = [80, 340, 620, 900, 1120];
      } else {
        regX = [60, 290, 530, 770, 1010, 1140];
      }

      const gridTopY = 480.0;
      const gridBotY = 1550.0;
      final gridLeftX = regX.first.toDouble();
      final gridRightX = regX.last.toDouble();

      late final List<math.Point<double>> dstCorners;
      if (aspect >= 0.80) {
        // Grid Fiducials detected
        dstCorners = [
          math.Point(gridLeftX, gridTopY),
          math.Point(gridRightX, gridTopY),
          math.Point(gridRightX, gridBotY),
          math.Point(gridLeftX, gridBotY),
        ];
      } else {
        // Page Corner Markers detected
        dstCorners = [
          const math.Point(60.0, 60.0),
          math.Point(targetW - 60.0, 60.0),
          math.Point(targetW - 60.0, targetH - 60.0),
          const math.Point(60.0, targetH - 60.0),
        ];
      }

      final srcCorners = [tl, tr, br, bl];
      final hInv = getPerspectiveTransform(dstCorners, srcCorners);
      if (hInv != null) {
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

              final p00 = source.getPixel(px, py);
              final p10 = source.getPixel(px + 1, py);
              final p01 = source.getPixel(px, py + 1);
              final p11 = source.getPixel(px + 1, py + 1);

              final r = ((p00.r * (1 - fx) + p10.r * fx) * (1 - fy) +
                  (p01.r * (1 - fx) + p11.r * fx) * fy).round();
              final g = ((p00.g * (1 - fx) + p10.g * fx) * (1 - fy) +
                  (p01.g * (1 - fx) + p11.g * fx) * fy).round();
              final b = ((p00.b * (1 - fx) + p10.b * fx) * (1 - fy) +
                  (p01.b * (1 - fx) + p11.b * fx) * fy).round();

              outImg.setPixelRgb(dx, dy, r, g, b);
            } else {
              outImg.setPixelRgb(dx, dy, 250, 250, 250);
            }
          }
        }
        return outImg;
      }
    }

    // Fallback resize
    return img.copyResize(source, width: targetW, height: targetH);
  }

  /// Inner-Core Bubble Analysis with Local Centroid Snapping (EvalBee-Style)
  static BubbleAnalysis analyzeBubbleCoreWithSnapping(
      Uint8List gray, int cx, int cy, int w, int h,
      [int searchR = 6, int rInner = 6]) {
    if (cx < rInner + searchR || cx >= w - (rInner + searchR) ||
        cy < rInner + searchR || cy >= h - (rInner + searchR)) {
      return BubbleAnalysis(fillRatio: 0, netContrast: 0, variance: 0, paperLevel: 245, snappedX: cx, snappedY: cy);
    }

    // 1. Search local +/- searchR window for darkest core centroid
    int bestX = cx;
    int bestY = cy;
    double maxDarkness = -1.0;

    for (int dy = -searchR; dy <= searchR; dy += 2) {
      final py = cy + dy;
      for (int dx = -searchR; dx <= searchR; dx += 2) {
        final px = cx + dx;
        double patchSum = 0;
        int patchCount = 0;
        for (int cdy = -2; cdy <= 2; cdy++) {
          final crow = (py + cdy) * w;
          for (int cdx = -2; cdx <= 2; cdx++) {
            patchSum += gray[crow + px + cdx];
            patchCount++;
          }
        }
        final darkness = 255.0 - (patchSum / patchCount);
        if (darkness > maxDarkness) {
          maxDarkness = darkness;
          bestX = px;
          bestY = py;
        }
      }
    }

    // 2. Measure local paper background annulus at snapped center (radius 12 to 17)
    double paperSum = 0;
    int paperCount = 0;
    const rAnnulusInner2 = 12 * 12;
    const rAnnulusOuter2 = 17 * 17;

    for (int dy = -17; dy <= 17; dy += 2) {
      final py = bestY + dy;
      if (py < 0 || py >= h) continue;
      final row = py * w;
      for (int dx = -17; dx <= 17; dx += 2) {
        final d2 = dx * dx + dy * dy;
        if (d2 >= rAnnulusInner2 && d2 <= rAnnulusOuter2) {
          final px = bestX + dx;
          if (px >= 0 && px < w) {
            paperSum += gray[row + px];
            paperCount++;
          }
        }
      }
    }

    final paperLevel = paperCount > 0 ? paperSum / paperCount : 245.0;
    final fillThresh = paperLevel * 0.72;

    // 3. Measure core fill ratio & variance at snapped center
    double coreSum = 0;
    double coreSqSum = 0;
    int coreCount = 0;
    int filledCount = 0;
    final r2 = rInner * rInner;

    for (int dy = -rInner; dy <= rInner; dy++) {
      final py = bestY + dy;
      final row = py * w;
      for (int dx = -rInner; dx <= rInner; dx++) {
        if (dx * dx + dy * dy <= r2) {
          final px = bestX + dx;
          final lum = gray[row + px];
          coreSum += lum;
          coreSqSum += (lum * lum);
          coreCount++;
          if (lum < fillThresh) {
            filledCount++;
          }
        }
      }
    }

    final coreMean = coreCount > 0 ? coreSum / coreCount : 255.0;
    final coreMeanSq = coreCount > 0 ? coreSqSum / coreCount : 0.0;
    final variance = math.max(0.0, coreMeanSq - (coreMean * coreMean));
    final fillRatio = coreCount > 0 ? filledCount / coreCount : 0.0;
    final meanDarkness = 255.0 - coreMean;
    final paperDarkness = 255.0 - paperLevel;
    final netContrast = math.max(0.0, meanDarkness - paperDarkness);

    return BubbleAnalysis(
      fillRatio: fillRatio,
      netContrast: netContrast,
      variance: variance,
      paperLevel: paperLevel,
      snappedX: bestX,
      snappedY: bestY,
    );
  }

  /// 4-State Question Classification with Snapping
  static QuestionResult classifyQuestion(
      Uint8List gray, Map<String, math.Point<int>> coords, int w, int h) {
    final opts = ['A', 'B', 'C', 'D'];
    final scores = <String, Map<String, double>>{};
    final snappedCoords = <String, math.Point<int>>{};

    for (final opt in opts) {
      final pt = coords[opt]!;
      final res = analyzeBubbleCoreWithSnapping(gray, pt.x, pt.y, w, h, 6, 6);
      final score = (res.fillRatio * 0.6) + (math.min(1.0, res.netContrast / 100.0) * 0.4);
      snappedCoords[opt] = math.Point(res.snappedX, res.snappedY);
      scores[opt] = {
        'score': score,
        'fill': res.fillRatio,
        'contrast': res.netContrast,
        'variance': res.variance,
      };
    }

    final sorted = opts.toList()..sort((a, b) => scores[b]!['score']!.compareTo(scores[a]!['score']!));
    final bestOpt = sorted[0];
    final secondOpt = sorted[1];
    final best = scores[bestOpt]!;
    final second = scores[secondOpt]!;

    final scoreMap = {for (final o in opts) o: scores[o]!['score']!};

    // 1. EMPTY: No shaded bubble
    if (best['score']! < 0.22 && best['fill']! < 0.25) {
      return QuestionResult(
        state: QuestionState.empty,
        selected: null,
        confidence: (1.0 - best['score']!).clamp(0.0, 1.0),
        scores: scoreMap,
        snappedCoords: snappedCoords,
      );
    }

    // 2. MULTIPLE: Two or more clearly marked answers
    if (best['score']! >= 0.38 && second['score']! >= 0.36 && (best['score']! - second['score']!) < 0.12) {
      return QuestionResult(
        state: QuestionState.multiple,
        selected: bestOpt,
        multipleSelected: [bestOpt, secondOpt],
        confidence: second['score']!,
        scores: scoreMap,
        snappedCoords: snappedCoords,
      );
    }

    // 3. UNCERTAIN: Erasure residue smudge (high variance), faint fill, or borderline margin
    if ((best['score']! >= 0.22 && best['score']! < 0.40) ||
        (best['variance']! > 700 && best['fill']! < 0.45) ||
        ((best['score']! - second['score']!) < 0.16 && best['score']! < 0.55)) {
      return QuestionResult(
        state: QuestionState.uncertain,
        selected: bestOpt,
        confidence: best['score']!,
        scores: scoreMap,
        snappedCoords: snappedCoords,
      );
    }

    // 4. SELECTED: One clearly marked answer
    final margin = best['score']! - second['score']!;
    final confidence = (0.70 + margin * 0.5).clamp(0.80, 0.99);
    return QuestionResult(
      state: QuestionState.selected,
      selected: bestOpt,
      confidence: confidence,
      scores: scoreMap,
      snappedCoords: snappedCoords,
    );
  }

  /// Master OMR Pipeline
  static OMRScanResult scanImage(img.Image rawImage, int questionCount, [Map<int, String>? answerKey]) {
    final quality = checkQuality(rawImage);
    if (quality['passed'] != true) {
      return OMRScanResult(
        success: false,
        error: quality['reason'],
        message: quality['message'],
      );
    }

    // Rectify to canonical 1200x1697
    final rectified = rectifySheet(rawImage, questionCount);
    final gray = Uint8List(targetW * targetH);
    for (int y = 0; y < targetH; y++) {
      for (int x = 0; x < targetW; x++) {
        final p = rectified.getPixel(x, y);
        // Enhanced ink darkness: heavily weights red and green so blue ink and pencil graphite both produce deep contrast
        final lum = (p.r * 500 + p.g * 400 + p.b * 100) ~/ 1000;
        gray[y * targetW + x] = lum;
      }
    }

    final qCount = questionCount.clamp(1, 100);
    final numMcqCols = qCount <= 20 ? 1 : (qCount <= 40 ? 2 : (qCount <= 75 ? 3 : 4));
    final qPerCol = (qCount / numMcqCols).ceil();

    // 1. Robust Model Detection (Band Search)
    String detectedModel = 'A';
    double bestModelMargin = -1.0;
    int detectedModelX = 360;
    int detectedModelY = 265;

    final candidateModelYs = [240, 255, 265, 280, 300, 320, 340, 360];
    final candidateXConfigs = [
      {'A': 360, 'B': 440, 'C': 520, 'D': 600}, // Wide table spacing
      {'A': 250, 'B': 290, 'C': 330, 'D': 370}, // Narrow table spacing
    ];

    for (final my in candidateModelYs) {
      for (final xs in candidateXConfigs) {
        final modelCoords = {
          'A': math.Point(xs['A']!, my),
          'B': math.Point(xs['B']!, my),
          'C': math.Point(xs['C']!, my),
          'D': math.Point(xs['D']!, my),
        };
        final res = classifyQuestion(gray, modelCoords, targetW, targetH);
        if (res.state == QuestionState.selected && res.selected != null) {
          final sortedScores = res.scores.values.toList()..sort((a, b) => b.compareTo(a));
          final margin = sortedScores.length >= 2 ? (sortedScores[0] - sortedScores[1]) : sortedScores[0];
          if (margin > bestModelMargin) {
            bestModelMargin = margin;
            detectedModel = res.selected!;
            final snapped = res.snappedCoords[res.selected!];
            detectedModelX = snapped != null ? snapped.x : xs[res.selected!]!;
            detectedModelY = snapped != null ? snapped.y : my;
          }
        }
      }
    }

    // 2. Read Student Roll No (5 Digits)
    final rollRowYs = [604, 657, 708, 763, 817, 872, 924, 974, 1028, 1080];
    final rollColXs = numMcqCols == 1
        ? [268, 326, 385, 443, 502]  // 15-question sheet
        : [196, 242, 289, 335, 382]; // 30+ question multi-column sheet
    final detectedRollCoords = <math.Point<int>>[];
    final idDigits = <String>[];

    for (int c = 0; c < rollColXs.length; c++) {
      final cx = rollColXs[c];
      final digitScores = <Map<String, dynamic>>[];
      for (int d = 0; d <= 9; d++) {
        final cy = rollRowYs[d];
        final res = analyzeBubbleCoreWithSnapping(gray, cx, cy, targetW, targetH, 6, 6);
        final score = (res.fillRatio * 0.6) + (math.min(1.0, res.netContrast / 100.0) * 0.4);
        digitScores.add({'digit': d, 'score': score, 'x': res.snappedX, 'y': res.snappedY});
      }
      digitScores.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
      final best = digitScores[0];
      final second = digitScores[1];
      if ((best['score'] as double) > 0.25 &&
          ((best['score'] as double) - (second['score'] as double)) > 0.08) {
        idDigits.add(best['digit'].toString());
        detectedRollCoords.add(math.Point(best['x'] as int, best['y'] as int));
      } else {
        idDigits.add('?');
      }
    }
    final detectedCode = idDigits.join();

    // 3. Read MCQ Questions using Calibrated Layout
    final answers = <int, QuestionResult>{};
    const optOffsets = [0.32, 0.49, 0.66, 0.83];

    // Calibrated coordinates for 15-question single-column exams
    final qYs15 = [
      656, 708, 764, 817, 869,     // Block 1: Q1..5
      978, 1030, 1082, 1139, 1191, // Block 2: Q6..10
      1300, 1352, 1404, 1456, 1509 // Block 3: Q11..15
    ];
    final optXs15 = {'A': 796, 'B': 852, 'C': 910, 'D': 971};

    late final List<int> regX;
    if (numMcqCols == 1) {
      regX = [100, 480, 1100];
    } else if (numMcqCols == 2) {
      regX = [100, 420, 800, 1100];
    } else if (numMcqCols == 3) {
      regX = [80, 340, 620, 900, 1120];
    } else {
      regX = [60, 290, 530, 770, 1010, 1140];
    }

    const gridTopY = 480;
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
      late final Map<String, math.Point<int>> coords;
      if (numMcqCols == 1 && qCount <= 15 && (q - 1) < qYs15.length) {
        // Direct calibrated lookup for 15-question sheet
        final qy = qYs15[q - 1];
        coords = {
          'A': math.Point(optXs15['A']!, qy),
          'B': math.Point(optXs15['B']!, qy),
          'C': math.Point(optXs15['C']!, qy),
          'D': math.Point(optXs15['D']!, qy),
        };
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
          'A': math.Point((effColLeft + effColW * optOffsets[0]).round(), qy),
          'B': math.Point((effColLeft + effColW * optOffsets[1]).round(), qy),
          'C': math.Point((effColLeft + effColW * optOffsets[2]).round(), qy),
          'D': math.Point((effColLeft + effColW * optOffsets[3]).round(), qy),
        };
      }

      questionCoords[q] = coords;
      final res = classifyQuestion(gray, coords, targetW, targetH);
      answers[q] = res;

      totalConfidence += res.confidence;
      if (res.state == QuestionState.uncertain) uncertainCount++;
      if (res.state == QuestionState.multiple) multipleCount++;
      if (res.state == QuestionState.empty) emptyCount++;

      if (answerKey != null && answerKey[q] != null) {
        if (res.state == QuestionState.selected && res.selected == answerKey[q]) {
          correctCount++;
        }
      }
    }

    final overallConf = (totalConfidence / qCount).clamp(0.0, 1.0);

    // Create Annotated Overlay Image
    final annotated = rectified.clone();

    // 1. Draw green circle on detected Model bubble
    img.drawCircle(annotated, x: detectedModelX, y: detectedModelY, radius: 16, color: img.ColorRgb8(16, 185, 129));

    // 2. Draw green circle on detected Roll No bubbles
    for (final pt in detectedRollCoords) {
      img.drawCircle(annotated, x: pt.x, y: pt.y, radius: 14, color: img.ColorRgb8(16, 185, 129));
    }

    // 3. Draw highlighted circles/boxes on MCQ questions
    for (int q = 1; q <= qCount; q++) {
      final ans = answers[q]!;
      final coords = questionCoords[q];
      if (coords == null) continue;

      if (ans.state == QuestionState.selected && ans.selected != null && coords.containsKey(ans.selected!)) {
        final pt = coords[ans.selected!]!;
        img.drawCircle(annotated, x: pt.x, y: pt.y, radius: 14, color: img.ColorRgb8(16, 185, 129));
      } else if (ans.state == QuestionState.uncertain) {
        final ptA = coords['A']!;
        final ptD = coords['D']!;
        img.drawRect(annotated,
            x1: ptA.x - 20,
            y1: ptA.y - 14,
            x2: ptD.x + 20,
            y2: ptD.y + 14,
            color: img.ColorRgb8(245, 158, 11));
      } else if (ans.state == QuestionState.multiple) {
        final ptA = coords['A']!;
        final ptD = coords['D']!;
        img.drawRect(annotated,
            x1: ptA.x - 20,
            y1: ptA.y - 14,
            x2: ptD.x + 20,
            y2: ptD.y + 14,
            color: img.ColorRgb8(239, 68, 68));
      }
    }

    return OMRScanResult(
      success: true,
      model: detectedModel,
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

  /// EvalBee-Style Geometric Quadrilateral Validator:
  /// Prevents mixing outer corner dots with inner grid dots
  static List<math.Point<double>>? _findBestFiducialQuad(List<math.Point<double>> dots) {
    if (dots.length < 4) return null;

    double hypot(num dx, num dy) => math.sqrt(dx * dx + dy * dy);

    bool isValidQuad(
      math.Point<double> tl,
      math.Point<double> tr,
      math.Point<double> br,
      math.Point<double> bl,
    ) {
      final wTop = hypot(tr.x - tl.x, tr.y - tl.y);
      final wBot = hypot(br.x - bl.x, br.y - bl.y);
      final hLeft = hypot(bl.x - tl.x, bl.y - tl.y);
      final hRight = hypot(br.x - tr.x, br.y - tr.y);

      if (math.min(math.min(wTop, wBot), math.min(hLeft, hRight)) < 40) {
        return false;
      }
      if (math.min(wTop, wBot) / math.max(wTop, wBot) < 0.65) return false;
      if (math.min(hLeft, hRight) / math.max(hLeft, hRight) < 0.65) return false;

      final angTop = math.atan2(tr.y - tl.y, tr.x - tl.x);
      final angBot = math.atan2(br.y - bl.y, br.x - bl.x);
      var diffH = (angTop - angBot).abs();
      if (diffH > math.pi) diffH = 2 * math.pi - diffH;
      if (diffH > 0.28) return false; // ~16 degrees max divergence

      final angLeft = math.atan2(bl.x - tl.x, bl.y - tl.y);
      final angRight = math.atan2(br.x - tr.x, br.y - tr.y);
      var diffV = (angLeft - angRight).abs();
      if (diffV > math.pi) diffV = 2 * math.pi - diffV;
      if (diffV > 0.28) return false; // ~16 degrees max divergence

      return true;
    }

    // Try 1: Extreme bounding points
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

    if (isValidQuad(tl, tr, br, bl)) {
      return [tl, tr, br, bl];
    }

    // Try 2: Avoid mixing outer & inner markers by checking consistent candidate subsets
    final sortedByY = List<math.Point<double>>.from(dots)..sort((a, b) => a.y.compareTo(b.y));
    final half = sortedByY.length ~/ 2;
    final topHalf = sortedByY.sublist(0, half)..sort((a, b) => a.x.compareTo(b.x));
    final botHalf = sortedByY.sublist(half)..sort((a, b) => a.x.compareTo(b.x));

    final topCandL = topHalf.take(math.min(3, topHalf.length)).toList();
    final topCandR = topHalf.reversed.take(math.min(3, topHalf.length)).toList();
    final botCandL = botHalf.take(math.min(3, botHalf.length)).toList();
    final botCandR = botHalf.reversed.take(math.min(3, botHalf.length)).toList();

    List<math.Point<double>>? bestQuad;
    double maxArea = 0;

    for (final cTl in topCandL) {
      for (final cTr in topCandR) {
        if (cTl == cTr) continue;
        for (final cBr in botCandR) {
          for (final cBl in botCandL) {
            if (cBr == cBl || cTl == cBl || cTr == cBr) continue;
            if (isValidQuad(cTl, cTr, cBr, cBl)) {
              final area = 0.5 * ((cTl.x * cTr.y - cTl.y * cTr.x) +
                                  (cTr.x * cBr.y - cTr.y * cBr.x) +
                                  (cBr.x * cBl.y - cBr.y * cBl.x) +
                                  (cBl.x * cTl.y - cBl.y * cTl.x)).abs();
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
