/**
 * OMR Engine (Optical Mark Recognition) & Bubble Sheet Generator
 * Developed for Centers Record & Examination System
 */

(function(global) {
    'use strict';

    // Standard Normalized Canvas Coordinate Space
    const SHEET_WIDTH = 1000;
    const SHEET_HEIGHT = 1414; // A4 aspect ratio 1 : 1.4142

    const OMR = {
        WIDTH: SHEET_WIDTH,
        HEIGHT: SHEET_HEIGHT,

        /**
         * Calculates coordinates layout for a given question count
         */
        getLayout(questionCount = 30) {
            const qCount = Math.max(10, Math.min(60, questionCount));
            const cols = qCount > 25 ? 2 : 1;
            const qPerCol = Math.ceil(qCount / cols);

            return {
                width: SHEET_WIDTH,
                height: SHEET_HEIGHT,
                cornerSize: 40,
                cornerMargin: 30,
                // Model selection
                modelBox: {
                    x: 620,
                    y: 190,
                    options: ['A', 'B', 'C', 'D'],
                    spacingX: 60
                },
                // Student Code (4 Digits)
                studentCode: {
                    x: 120,
                    y: 190,
                    digits: 4,
                    spacingX: 45,
                    spacingY: 28,
                    bubbleRadius: 10
                },
                // MCQ Questions
                mcq: {
                    cols: cols,
                    qPerCol: qPerCol,
                    colX: cols === 1 ? [320] : [110, 560],
                    startY: 550,
                    rowHeight: qCount > 40 ? 27 : 33,
                    optSpacingX: 48,
                    bubbleRadius: 10
                },
                // Written Score Box
                writtenBox: {
                    x: 600,
                    y: 360,
                    w: 280,
                    h: 110
                }
            };
        },

        /**
         * Generates high-resolution printable HTML/SVG Bubble Sheet
         */
        generatePrintableSheetHtml(exam) {
            const title = exam.title || 'Examination Sheet';
            const subject = exam.subject || 'Chemistry';
            const center = exam.center || 'All Centers';
            const date = exam.date || new Date().toISOString().split('T')[0];
            const qCount = exam.question_count || 30;
            const writtenMax = exam.written_max_score || 20;
            const mcqPerQ = exam.mcq_score_per_q || 1;
            const totalScore = (qCount * mcqPerQ) + parseFloat(writtenMax);

            const layout = this.getLayout(qCount);

            let qRowsHtml = '';
            const opts = ['A', 'B', 'C', 'D'];

            if (layout.mcq.cols === 1) {
                for (let i = 1; i <= qCount; i++) {
                    qRowsHtml += `
                        <div class="omr-q-row" style="display:flex; align-items:center; justify-content:space-between; margin-bottom: 6px; font-size:12px;">
                            <span style="font-weight:700; width:30px; text-align:right;">${i}.</span>
                            <div style="display:flex; gap:16px;">
                                ${opts.map(o => `<div class="omr-bubble" data-q="${i}" data-opt="${o}">${o}</div>`).join('')}
                            </div>
                        </div>
                    `;
                }
            } else {
                let leftColHtml = '';
                let rightColHtml = '';
                for (let i = 1; i <= layout.mcq.qPerCol; i++) {
                    leftColHtml += `
                        <div class="omr-q-row" style="display:flex; align-items:center; justify-content:space-between; margin-bottom: ${qCount > 40 ? '4px' : '7px'}; font-size:12px;">
                            <span style="font-weight:700; width:28px; text-align:right;">${i}.</span>
                            <div style="display:flex; gap:14px;">
                                ${opts.map(o => `<div class="omr-bubble" data-q="${i}" data-opt="${o}">${o}</div>`).join('')}
                            </div>
                        </div>
                    `;
                }
                for (let i = layout.mcq.qPerCol + 1; i <= qCount; i++) {
                    rightColHtml += `
                        <div class="omr-q-row" style="display:flex; align-items:center; justify-content:space-between; margin-bottom: ${qCount > 40 ? '4px' : '7px'}; font-size:12px;">
                            <span style="font-weight:700; width:28px; text-align:right;">${i}.</span>
                            <div style="display:flex; gap:14px;">
                                ${opts.map(o => `<div class="omr-bubble" data-q="${i}" data-opt="${o}">${o}</div>`).join('')}
                            </div>
                        </div>
                    `;
                }
                qRowsHtml = `
                    <div style="display:flex; gap:36px; width:100%;">
                        <div style="flex:1;">${leftColHtml}</div>
                        <div style="width:1px; background:#cbd5e1;"></div>
                        <div style="flex:1;">${rightColHtml}</div>
                    </div>
                `;
            }

            return `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8"/>
    <title>Bubble Sheet - ${title}</title>
    <style>
        @page {
            size: A4 portrait;
            margin: 0;
        }
        * { box-sizing: border-box; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
        body {
            margin: 0;
            padding: 0;
            background: #fff;
            color: #0f172a;
            font-family: 'Inter', system-ui, -apple-system, sans-serif;
        }
        .page-container {
            width: 210mm;
            height: 297mm;
            position: relative;
            padding: 16mm 14mm;
            margin: 0 auto;
            background: #ffffff;
            display: flex;
            flex-col;
            justify-content: space-between;
        }
        /* Corner Fiducials (Black Squares for Auto-Alignment) */
        .fiducial {
            position: absolute;
            width: 14mm;
            height: 14mm;
            background: #000000;
        }
        .fid-tl { top: 7mm; left: 7mm; }
        .fid-tr { top: 7mm; right: 7mm; }
        .fid-bl { bottom: 7mm; left: 7mm; }
        .fid-br { bottom: 7mm; right: 7mm; }

        .sheet-header {
            border-bottom: 2px solid #0f172a;
            padding-bottom: 8px;
            margin-bottom: 12px;
            display: flex;
            justify-content: space-between;
            align-items: flex-end;
        }
        .sheet-title {
            font-size: 20px;
            font-weight: 800;
            margin: 0;
            text-transform: uppercase;
            letter-spacing: -0.01em;
        }
        .sheet-sub {
            font-size: 11px;
            color: #475569;
            margin-top: 3px;
        }
        .meta-box {
            display: flex;
            gap: 16px;
            font-size: 11px;
            font-weight: 600;
        }
        .meta-item {
            border: 1px solid #94a3b8;
            padding: 4px 8px;
            border-radius: 4px;
        }

        .student-info-grid {
            display: grid;
            grid-template-columns: 1.2fr 1fr;
            gap: 16px;
            margin-bottom: 14px;
            padding: 10px;
            border: 1.5px solid #0f172a;
            border-radius: 6px;
            background: #f8fafc;
        }

        .input-line {
            display: flex;
            align-items: center;
            margin-bottom: 8px;
            font-size: 12px;
            font-weight: 700;
        }
        .input-line .line {
            flex: 1;
            border-bottom: 1px dashed #64748b;
            margin-left: 8px;
            height: 18px;
        }

        /* Bubble styles */
        .omr-bubble {
            width: 22px;
            height: 22px;
            border: 1.8px solid #0f172a;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 10px;
            font-weight: 700;
            color: #0f172a;
            user-select: none;
        }

        .code-grid {
            display: flex;
            gap: 10px;
        }
        .code-col {
            display: flex;
            flex-direction: column;
            align-items: center;
            gap: 2px;
        }
        .code-col-header {
            width: 20px;
            height: 20px;
            border-bottom: 1.5px solid #0f172a;
            margin-bottom: 3px;
        }

        .instruction-box {
            font-size: 10px;
            line-height: 1.35;
            color: #334155;
            border: 1px dashed #94a3b8;
            padding: 6px 10px;
            border-radius: 4px;
            margin-bottom: 12px;
        }

        .written-score-box {
            border: 2px solid #0f172a;
            border-radius: 6px;
            padding: 8px;
            text-align: center;
            background: #fff;
        }
        .written-score-box .score-fill {
            font-size: 26px;
            font-weight: 900;
            color: #0f172a;
            height: 40px;
            border-bottom: 2px solid #000;
            margin: 6px 20px;
        }

        @media print {
            .no-print { display: none !important; }
            body { padding: 0; }
        }
    </style>
</head>
<body>
    <div class="no-print" style="background:#0f172a; color:#fff; padding:12px 20px; display:flex; justify-content:space-between; align-items:center;">
        <div><strong>Print Preview:</strong> ${title} (${qCount} Questions)</div>
        <button onclick="window.print()" style="background:#10b981; color:#fff; font-weight:700; border:none; padding:8px 18px; border-radius:6px; cursor:pointer;">
            🖨️ Print Now (Ctrl + P)
        </button>
    </div>

    <div class="page-container">
        <!-- 4 Black Square Corner Alignment Markers -->
        <div class="fiducial fid-tl"></div>
        <div class="fiducial fid-tr"></div>
        <div class="fiducial fid-bl"></div>
        <div class="fiducial fid-br"></div>

        <div>
            <!-- Header -->
            <div class="sheet-header">
                <div>
                    <h1 class="sheet-title">${title}</h1>
                    <div class="sheet-sub">MR. KELANY ACADEMY • ${subject.toUpperCase()}</div>
                </div>
                <div class="meta-box">
                    <div class="meta-item">Date: ${date}</div>
                    <div class="meta-item">Center: ${center}</div>
                    <div class="meta-item">Total: ${totalScore} Marks</div>
                </div>
            </div>

            <!-- Student Info & Code Block -->
            <div class="student-info-grid">
                <div>
                    <div class="input-line">
                        <span>Student Name:</span>
                        <div class="line"></div>
                    </div>
                    <div class="input-line">
                        <span>Center:</span>
                        <div class="line"></div>
                    </div>

                    <!-- Exam Model Selection -->
                    <div style="margin-top:12px; display:flex; align-items:center; gap:12px;">
                        <span style="font-size:11px; font-weight:800;">EXAM FORM / النموذج:</span>
                        <div style="display:flex; gap:10px;">
                            <div style="display:flex; align-items:center; gap:4px;">
                                <div class="omr-bubble" style="width:20px; height:20px;">A</div>
                            </div>
                            <div style="display:flex; align-items:center; gap:4px;">
                                <div class="omr-bubble" style="width:20px; height:20px;">B</div>
                            </div>
                            <div style="display:flex; align-items:center; gap:4px;">
                                <div class="omr-bubble" style="width:20px; height:20px;">C</div>
                            </div>
                            <div style="display:flex; align-items:center; gap:4px;">
                                <div class="omr-bubble" style="width:20px; height:20px;">D</div>
                            </div>
                        </div>
                    </div>

                    <div class="instruction-box" style="margin-top:10px;">
                        • Fill bubbles completely using a dark pen or pencil: <strong>●</strong> (Not <strong>✓</strong> or <strong>✗</strong>)<br/>
                        • Do not fold, crease, or write in the margins or over the corner black squares.
                    </div>
                </div>

                <!-- Right Side: Student Code Grid & Teacher Score Box -->
                <div style="display:flex; gap:14px; justify-content:flex-end;">
                    <!-- Student Code 4-Digits -->
                    <div>
                        <div style="font-size:10px; font-weight:800; text-align:center; margin-bottom:2px;">STUDENT ID (الكود)</div>
                        <div class="code-grid">
                            ${[0, 1, 2, 3].map(col => `
                                <div class="code-col">
                                    <div class="code-col-header"></div>
                                    ${[0, 1, 2, 3, 4, 5, 6, 7, 8, 9].map(num => `
                                        <div class="omr-bubble" style="width:16px; height:16px; font-size:8px;">${num}</div>
                                    `).join('')}
                                </div>
                            `).join('')}
                        </div>
                    </div>

                    <!-- Written Grade / Essay Box -->
                    <div class="written-score-box" style="width:130px; display:flex; flex-direction:column; justify-content:space-between;">
                        <div>
                            <div style="font-size:11px; font-weight:800; color:#ba1a1a;">خاص بالمصحح</div>
                            <div style="font-size:9px; font-weight:700; color:#475569;">درجة السؤال المقالي</div>
                        </div>
                        <div class="score-fill"></div>
                        <div style="font-size:10px; font-weight:800; border-top:1px solid #cbd5e1; padding-top:4px;">
                            من ${writtenMax} درجات
                        </div>
                    </div>
                </div>
            </div>

            <!-- MCQ Questions Grid -->
            <div style="border: 1.5px solid #0f172a; border-radius:6px; padding: 12px 16px;">
                <div style="font-size:11px; font-weight:800; margin-bottom:8px; border-bottom:1px solid #e2e8f0; padding-bottom:4px; display:flex; justify-content:space-between;">
                    <span>MULTIPLE CHOICE QUESTIONS (اختر الإجابة الصحيحة)</span>
                    <span style="color:#64748b;">(${qCount} Questions • ${qCount * mcqPerQ} Marks)</span>
                </div>
                ${qRowsHtml}
            </div>
        </div>

        <!-- Footer -->
        <div style="font-size:9px; color:#64748b; display:flex; justify-content:space-between; align-items:center; border-top:1px solid #e2e8f0; padding-top:6px; margin-top:8px;">
            <span>OMR Barcode / Serial ID: ${exam.id ? exam.id.substring(0, 13) : 'TEST-SHEET'}</span>
            <span>Do not mark the 4 black square alignment markers at sheet corners.</span>
            <span>Page 1 of 1</span>
        </div>
    </div>
</body>
</html>
            `;
        },

        /**
         * Client-Side Image Processing & OMR Detection
         * Input: HTMLCanvasElement or HTMLImageElement
         * Output: { success, model, studentCode, answers: { 1: 'A', 2: 'B', ... }, confidence }
         */
        scanImage(canvas, questionCount = 30) {
            const ctx = canvas.getContext('2d');
            const w = canvas.width;
            const h = canvas.height;

            const imgData = ctx.getImageData(0, 0, w, h);
            const data = imgData.data;

            // 1. Grayscale & Luminance Map
            const gray = new Uint8Array(w * h);
            let sumLum = 0;
            for (let i = 0, j = 0; i < data.length; i += 4, j++) {
                // ITU-R BT.601 standard luminance
                const lum = (data[i] * 299 + data[i + 1] * 587 + data[i + 2] * 114) / 1000;
                gray[j] = lum;
                sumLum += lum;
            }
            const avgLum = sumLum / (w * h);
            const darkThreshold = avgLum * 0.72; // pixels significantly darker than paper

            /**
             * Samples a circular bubble at normalized ratios (rx, ry)
             * Returns darkness fill ratio [0.0 - 1.0]
             */
            function sampleBubbleDarkness(normX, normY, radiusPx = 10) {
                const cx = Math.round(normX * w);
                const cy = Math.round(normY * h);
                let darkCount = 0;
                let totalCount = 0;

                for (let dy = -radiusPx; dy <= radiusPx; dy++) {
                    for (let dx = -radiusPx; dx <= radiusPx; dx++) {
                        if (dx * dx + dy * dy <= radiusPx * radiusPx) {
                            const px = cx + dx;
                            const py = cy + dy;
                            if (px >= 0 && px < w && py >= 0 && py < h) {
                                totalCount++;
                                if (gray[py * w + px] < darkThreshold) {
                                    darkCount++;
                                }
                            }
                        }
                    }
                }
                return totalCount > 0 ? (darkCount / totalCount) : 0;
            }

            // Estimate sheet bounds / offsets (or fallback to standard normalized layout)
            const layout = this.getLayout(questionCount);

            // 2. Read Exam Model (A, B, C, D)
            // Model row is in the upper right header area
            const modelOpts = ['A', 'B', 'C', 'D'];
            const modelDarkness = [];
            // Approximate normalized position for Model bubbles
            const modelBaseY = 0.175;
            const modelBaseX = 0.35;
            const modelSpacingX = 0.055;

            for (let i = 0; i < 4; i++) {
                const dark = sampleBubbleDarkness(modelBaseX + (i * modelSpacingX), modelBaseY, Math.round(w * 0.012));
                modelDarkness.push({ opt: modelOpts[i], dark });
            }
            modelDarkness.sort((a, b) => b.dark - a.dark);
            const detectedModel = (modelDarkness[0].dark > 0.35) ? modelDarkness[0].opt : 'A';

            // 3. Read Student ID (4 Digits)
            const studentCodeDigits = [];
            const idBaseX = 0.73;
            const idStepX = 0.045;
            const idBaseY = 0.165;
            const idStepY = 0.021;

            for (let col = 0; col < 4; col++) {
                let colResults = [];
                for (let digit = 0; digit <= 9; digit++) {
                    const dark = sampleBubbleDarkness(idBaseX + (col * idStepX), idBaseY + (digit * idStepY), Math.round(w * 0.010));
                    colResults.push({ digit, dark });
                }
                colResults.sort((a, b) => b.dark - a.dark);
                if (colResults[0].dark > 0.32) {
                    studentCodeDigits.push(colResults[0].digit);
                } else {
                    studentCodeDigits.push('?');
                }
            }
            const detectedStudentCode = studentCodeDigits.join('');

            // 4. Read MCQ Questions
            const detectedAnswers = {};
            const qCount = Math.max(10, Math.min(60, questionCount));
            const cols = qCount > 25 ? 2 : 1;
            const qPerCol = Math.ceil(qCount / cols);

            const mcqBaseY = 0.44;
            const mcqRowH = (0.92 - mcqBaseY) / qPerCol;

            // Options A, B, C, D
            const col1X = cols === 1 ? 0.38 : 0.15;
            const col2X = 0.62;
            const optStepX = 0.055;

            for (let q = 1; q <= qCount; q++) {
                const isCol2 = q > qPerCol;
                const rowIdx = isCol2 ? (q - qPerCol - 1) : (q - 1);
                const baseX = isCol2 ? col2X : col1X;
                const cy = mcqBaseY + (rowIdx * mcqRowH);

                const optScores = [];
                for (let optIdx = 0; optIdx < 4; optIdx++) {
                    const cx = baseX + (optIdx * optStepX);
                    const dark = sampleBubbleDarkness(cx, cy, Math.round(w * 0.011));
                    optScores.push({ opt: modelOpts[optIdx], dark });
                }

                // Sort by darkness
                optScores.sort((a, b) => b.dark - a.dark);

                // Verification logic:
                // Marked bubble should have fill > 0.35 AND be significantly darker than 2nd place
                const best = optScores[0];
                const runnerUp = optScores[1];

                if (best.dark > 0.35) {
                    if (runnerUp.dark > 0.35 && (best.dark - runnerUp.dark) < 0.15) {
                        // Double marked!
                        detectedAnswers[q] = { selected: best.opt, ambiguous: true, second: runnerUp.opt };
                    } else {
                        detectedAnswers[q] = { selected: best.opt, ambiguous: false };
                    }
                } else {
                    // Blank / Unanswered
                    detectedAnswers[q] = { selected: null, ambiguous: false };
                }
            }

            return {
                success: true,
                model: detectedModel,
                studentCode: detectedStudentCode,
                answers: detectedAnswers,
                scannedAt: new Date().toISOString()
            };
        }
    };

    global.OMREngine = OMR;

})(typeof window !== 'undefined' ? window : this);
