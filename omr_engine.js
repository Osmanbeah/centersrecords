/**

 * OMR Engine (Optical Mark Recognition) & Bubble Sheet Generator

 * Developed for Centers Record & Examination System

 */



(function(global) {

    'use strict';



    // Standard Normalized Canvas Coordinate Space

    const SHEET_WIDTH = 1000;

    const SHEET_HEIGHT = 1414; // A4 aspect ratio 1 : 1.4142



    function escapeHtml(str) {

        if (!str) return '';

        return String(str).replace(/[&<>"']/g, function(m) {

            return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[m];

        });

    }



    const OMR = {

        WIDTH: SHEET_WIDTH,

        HEIGHT: SHEET_HEIGHT,



        /**

         * Calculates coordinates layout for a given question count

         */

        getLayout(questionCount = 30) {

            const qCount = Math.max(1, Math.min(100, parseInt(questionCount, 10) || 30));

            const cols = qCount <= 20 ? 1 : (qCount <= 40 ? 2 : (qCount <= 75 ? 3 : 4));

            const qPerCol = Math.ceil(qCount / cols);

            const isSpacious = qPerCol <= 16;

            const isMedium = qPerCol > 16 && qPerCol <= 24;



            return {

                width: SHEET_WIDTH,

                height: SHEET_HEIGHT,

                cols: cols,

                qPerCol: qPerCol,

                qCount: qCount,

                model: {

                    baseY: isSpacious ? 0.22 : (isMedium ? 0.21 : 0.20),

                    baseX: 0.26,

                    stepX: isSpacious ? 0.075 : (isMedium ? 0.068 : 0.065)

                },

                studentCode: {

                    digits: 5,

                    baseX: isSpacious ? 0.135 : 0.145,

                    stepX: isSpacious ? 0.028 : 0.026,

                    baseY: isSpacious ? 0.34 : (isMedium ? 0.38 : 0.42),

                    stepY: isSpacious ? 0.046 : (isMedium ? 0.040 : 0.038)

                },

                mcq: {

                    cols: cols,

                    qPerCol: qPerCol,

                    colBaseX: cols === 1 ? [0.55] : (cols === 2 ? [0.44, 0.73] : [0.38, 0.59, 0.80]),

                    optStepX: cols === 1 ? (isSpacious ? 0.060 : 0.055) : (cols === 2 ? 0.048 : 0.040),

                    baseY: isSpacious ? 0.33 : (isMedium ? 0.37 : 0.41),

                    totalHeight: isSpacious ? 0.58 : (isMedium ? 0.54 : 0.50)

                }

            };

        },



        /**

         * Generates high-resolution printable HTML/SVG Bubble Sheet

         */

        /**

         * Generates high-resolution printable HTML/SVG Bubble Sheet

         * Formatted for standard A4 paper with proportional vertical distribution:

         * - Dynamically scales font sizes, row heights, and bubble dimensions to eliminate blank voids

         * - Generous handwritten student info table rows

         * - Prominent teacher written score widget

         * - Calibrated Roll No digit boxes & vertical 0-9 bubble columns

         * - 5-question grouped MCQ bubble sections with column headers A B C D

         * - Black square registration anchor dots (fiducials) framing every column

         * - Full-height A4 print styling (with dual-sheet A5 option) with zero page overflow

         */

        generatePrintableSheetHtml(exam = {}) {

            const title = exam.title || 'Comprehensive Examination';

            const subject = exam.subject || 'Chemistry';

            const center = exam.center || 'All Centers';

            const date = exam.exam_date || exam.date || new Date().toISOString().split('T')[0];

            const qCount = Math.max(1, Math.min(100, parseInt(exam.question_count, 10) || 30));

            const mcqPerQ = exam.mcq_score_per_q || 1;

            const writtenMax = exam.written_max_score != null ? exam.written_max_score : 20;

            const totalScore = exam.total_score || ((qCount * mcqPerQ) + parseFloat(writtenMax));



            // Customizable Sheet & Info Table Configuration

            const cfg = exam.sheet_config || {};

            const academyName = cfg.academy_name || 'MR. KELANY ACADEMY';

            const nameLabel = cfg.name_label || 'Full NAME :';

            const phoneLabel = cfg.phone_label || 'Phone Number :';

            const parentPhoneLabel = cfg.parent_phone_label || 'Parent Number :';

            const idLabel = cfg.id_label || 'ID :';

            const modelLabel = cfg.model_label || 'Model :';

            const attendLabel = cfg.attend_center_label || 'بتحضر فين :';

            const examCenterLabel = cfg.exam_center_label || 'بتمتحن فين :';

            const showParentPhone = cfg.show_parent_phone !== false;

            const showCenterQuestions = cfg.show_center_questions === true;

            const showWrittenBox = cfg.show_written_box !== false;

            const writtenBoxTitle = cfg.written_box_title || 'خاص بالمصحح';

            const writtenBoxSub = cfg.written_box_sub || 'درجة السؤال المقالي';

            const idDigits = Math.max(3, Math.min(8, cfg.id_digits || 5));

            const rollTitle = cfg.roll_title || 'Roll No (كود الطالب)';

            const footerNote = cfg.footer_note || 'تعليمات التظليل: ● تظليل كامل (صحيح) | ✕ ✗ غير صحيح - لا تطوِ الورقة أو تكتب في الهوامش';



            // Determine MCQ columns dynamically based on question count

            const numCols = qCount <= 20 ? 1 : (qCount <= 40 ? 2 : (qCount <= 75 ? 3 : 4));

            const qPerCol = Math.ceil(qCount / numCols);



            // Sizing tier based on questions per column

            const isSpacious = qPerCol <= 16;

            const isMedium = qPerCol > 16 && qPerCol <= 24;

            const isCompact = qPerCol > 24;



            // Dimensions and typography tailored for standard A4 paper

            const dyn = {

                // Page & Layout

                pageMinH: '277mm',

                pagePad: isSpacious ? '8mm 12mm' : (isMedium ? '7mm 10mm' : '6mm 8mm'),

                

                // Header

                headerTitleFont: isSpacious ? '26px' : (isMedium ? '22px' : '19px'),

                headerSubFont: isSpacious ? '13.5px' : (isMedium ? '12px' : '11px'),

                metaBadgeFont: isSpacious ? '14.5px' : (isMedium ? '12px' : '10.5px'),

                metaBadgePad: isSpacious ? '6px 14px' : (isMedium ? '4px 10px' : '3px 7px'),

                headerPadB: isSpacious ? '12px' : (isMedium ? '8px' : '6px'),

                headerMarB: isSpacious ? '16px' : (isMedium ? '10px' : '8px'),



                // Student Table

                tableRowH: isSpacious ? '42px' : (isMedium ? '33px' : '26px'),

                tableFont: isSpacious ? '14.5px' : (isMedium ? '13px' : '11.5px'),

                labelWidth: isSpacious ? '150px' : (isMedium ? '130px' : '115px'),

                tablePad: isSpacious ? '7px 12px' : (isMedium ? '5px 10px' : '4px 8px'),

                modelBubbleSize: isSpacious ? '22px' : (isMedium ? '19px' : '17px'),

                modelBubbleGap: isSpacious ? '24px' : (isMedium ? '16px' : '12px'),

                modelLabelFont: isSpacious ? '13.5px' : (isMedium ? '11.5px' : '10px'),



                // Teacher Written Score Box

                writtenBoxW: isSpacious ? '160px' : (isMedium ? '140px' : '125px'),

                writtenBoxTitleFont: isSpacious ? '16px' : (isMedium ? '13px' : '11px'),

                writtenBoxSubFont: isSpacious ? '12px' : (isMedium ? '10px' : '9px'),

                writtenScoreAreaH: isSpacious ? '65px' : (isMedium ? '44px' : '34px'),

                writtenMaxFont: isSpacious ? '13.5px' : (isMedium ? '11px' : '10px'),



                // Spacing between Top Info Section and OMR Grid

                topInfoMargin: isSpacious ? '24px' : (isMedium ? '15px' : '10px'),



                // Roll No Matrix

                rollTitleFont: isSpacious ? '14.5px' : (isMedium ? '12.5px' : '11px'),

                rollBoxW: isSpacious ? '28px' : (isMedium ? '24px' : '20px'),

                rollBoxH: isSpacious ? '32px' : (isMedium ? '26px' : '20px'),

                rollBoxesGap: isSpacious ? '6px' : (isMedium ? '5px' : '4px'),

                rollBoxesMarB: isSpacious ? '12px' : (isMedium ? '8px' : '6px'),

                rollRowGap: isSpacious ? '7px' : (isMedium ? '4.5px' : '3.5px'),

                rollDigitFont: isSpacious ? '13.5px' : (isMedium ? '11.5px' : '10px'),

                rollBubbleSize: isSpacious ? '22px' : (isMedium ? '19px' : '17px'),

                rollBubblesGap: isSpacious ? '6px' : (isMedium ? '5px' : '4px'),



                // MCQ Questions & Bubbles

                bubbleSize: isSpacious ? '22px' : (isMedium ? '19px' : '17px'),

                bubbleBorder: isSpacious ? '1.8px' : '1.5px',

                qRowMargin: isSpacious ? '9px' : (isMedium ? '5px' : '3.5px'),

                qBlockSpacer: isSpacious ? '18px' : (isMedium ? '11px' : '7px'),

                qNumFont: isSpacious ? '14.5px' : (isMedium ? '12.5px' : '11px'),

                qNumWidth: isSpacious ? '32px' : '26px',

                optHeaderFont: isSpacious ? '14px' : (isMedium ? '12px' : '10.5px'),

                colTitleFont: isSpacious ? '14.5px' : (isMedium ? '12.5px' : '11px'),

                colMaxWidth: isSpacious ? '210px' : (isMedium ? '180px' : '155px'),

                optBubblePad: isSpacious ? '0 8px' : '0 4px',



                // Registration Dots (Fiducials)

                regDotSize: isSpacious ? '14px' : (isMedium ? '13px' : '11px'),

                regDotColW: isSpacious ? '16px' : (isMedium ? '15px' : '13px'),



                // Footer

                footerFont: isSpacious ? '11.5px' : (isMedium ? '10px' : '9px'),

                footerPadT: isSpacious ? '12px' : (isMedium ? '8px' : '5px'),

                footerMarT: isSpacious ? '18px' : (isMedium ? '12px' : '6px')

            };



            // Calculate exact number of registration dots needed based on question blocks

            const numDots = Math.max(3, Math.min(6, Math.ceil(qPerCol / 5) + 1));



            function buildRegDotsColHtml() {

                let dots = '';

                for (let d = 0; d < numDots; d++) {

                    dots += '<div class="reg-dot"></div>';

                }

                return `

                    <div class="reg-dot-col">

                        ${dots}

                    </div>

                `;

            }



            function buildMcqCol(colIdx) {

                const startQ = (colIdx * qPerCol) + 1;

                const endQ = Math.min(qCount, (colIdx + 1) * qPerCol);

                if (startQ > qCount) return '';



                let html = '';

                const blockSize = 5;



                for (let q = startQ; q <= endQ; q++) {

                    const posInBlock = (q - startQ) % blockSize;



                    // Repeat header A B C D at the start of each 5-question block

                    if (posInBlock === 0) {

                        html += `

                            <div class="omr-q-header-row">

                                <span class="q-num-spacer"></span>

                                <div class="opt-labels">

                                    <span>A</span>

                                    <span>B</span>

                                    <span>C</span>

                                    <span>D</span>

                                </div>

                            </div>

                        `;

                    }



                    html += `

                        <div class="omr-q-row">

                            <span class="q-num">${q}</span>

                            <div class="opt-bubbles">

                                <span class="bubble" data-q="${q}" data-opt="A"></span>

                                <span class="bubble" data-q="${q}" data-opt="B"></span>

                                <span class="bubble" data-q="${q}" data-opt="C"></span>

                                <span class="bubble" data-q="${q}" data-opt="D"></span>

                            </div>

                        </div>

                    `;



                    // Add spacer after each 5th question (except the last question in the column)

                    if (posInBlock === blockSize - 1 && q !== endQ) {

                        html += `<div class="q-block-spacer"></div>`;

                    }

                }



                return `

                    <div class="mcq-column">

                        <div class="mcq-col-title">${escapeHtml(subject)} (${startQ} - ${endQ})</div>

                        <div class="mcq-col-body">${html}</div>

                    </div>

                `;

            }



            let mcqColumnsHtml = '';

            for (let c = 0; c < numCols; c++) {

                mcqColumnsHtml += buildMcqCol(c);

                // Middle registration dots column between MCQ columns

                if (c < numCols - 1) {

                    mcqColumnsHtml += `

                        ${buildRegDotsColHtml()}

                    `;

                }

            }



            return `<!DOCTYPE html>

<html lang="ar" dir="ltr">

<head>

    <meta charset="utf-8"/>

    <title>Bubble Sheet - ${escapeHtml(title)}</title>

    <link rel="preconnect" href="https://fonts.googleapis.com"/>

    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin/>

    <link href="https://fonts.googleapis.com/css2?family=Cairo:wght@600;700;800;900&family=Inter:wght@500;600;700;800;900&display=swap" rel="stylesheet"/>

    <style>

        @page {

            size: A4 portrait;

            margin: 8mm 10mm;

        }

        * {

            box-sizing: border-box;

            -webkit-print-color-adjust: exact;

            print-color-adjust: exact;

        }

        body {

            margin: 0;

            padding: 0;

            background: #e2e8f0;

            color: #0f172a;

            font-family: 'Inter', 'Cairo', system-ui, -apple-system, sans-serif;

            -webkit-font-smoothing: antialiased;

        }



        /* Top Bar (Excluded from Print) */

        .preview-toolbar {

            background: #0f172a;

            color: #ffffff;

            padding: 12px 24px;

            display: flex;

            align-items: center;

            justify-content: space-between;

            gap: 12px;

            font-size: 13px;

            position: sticky;

            top: 0;

            z-index: 100;

            box-shadow: 0 2px 10px rgba(0,0,0,0.25);

        }

        .btn-print {

            background: #10b981;

            color: #ffffff;

            font-weight: 800;

            font-size: 13.5px;

            border: none;

            padding: 9px 22px;

            border-radius: 8px;

            cursor: pointer;

            display: inline-flex;

            align-items: center;

            gap: 6px;

            transition: all 0.15s ease;

            box-shadow: 0 2px 6px rgba(16, 185, 129, 0.4);

        }

        .btn-print:hover { background: #059669; transform: translateY(-1px); }

        .mode-toggle-btn {

            background: #334155;

            color: #f8fafc;

            border: 1px solid #475569;

            padding: 7px 16px;

            border-radius: 6px;

            font-size: 12px;

            font-weight: 700;

            cursor: pointer;

        }

        .mode-toggle-btn.active {

            background: #2563eb;

            border-color: #3b82f6;

        }



                /* 4-Corner Fiducial Markers for Perspective Homography */

        .corner-marker {

            position: absolute;

            width: 18px;

            height: 18px;

            background: #000000;

            border-radius: 1px;

            z-index: 10;

        }

        .corner-marker-tl { top: 4mm; left: 5mm; }

        .corner-marker-tr { top: 4mm; right: 5mm; }

        .corner-marker-bl { bottom: 4mm; left: 5mm; }

        .corner-marker-br { bottom: 4mm; right: 5mm; }



        /* Sheet Page Container - Full A4 Proportions */

        .sheet-wrapper {

            padding: 20px;

            display: flex;

            justify-content: center;

        }

        .bubble-sheet-page {

            width: 200mm;

            max-width: 100%;

            min-height: ${dyn.pageMinH};

            background: #ffffff;

            padding: ${dyn.pagePad};

            box-shadow: 0 4px 20px rgba(0, 0, 0, 0.15);

            display: flex;

            flex-direction: column;

            justify-content: space-between;

            position: relative;

            margin-bottom: 20px;

            box-sizing: border-box;

        }



        /* Two-Up A5 Mode */

        body.mode-dual .bubble-sheet-page {

            width: 194mm;

            height: auto;

            min-height: 135mm;

            max-height: 138mm;

            padding: 3mm 5mm;

            page-break-inside: avoid;

            margin-bottom: 4mm;

            border-bottom: 1px dashed #94a3b8;

        }

        body.mode-dual .sheet-header h1 { font-size: 15px !important; }

        body.mode-dual .student-table td { height: 22px !important; font-size: 10px !important; padding: 2px 4px !important; }

        body.mode-dual .student-table .td-label { width: 95px !important; }

        body.mode-dual .teacher-written-box { width: 110px !important; }

        body.mode-dual .twb-score-area { height: 26px !important; }

        body.mode-dual .top-info-section { margin-bottom: 6px !important; }

        body.mode-dual .bubble { width: 15px !important; height: 15px !important; }

        body.mode-dual .omr-q-row { margin-bottom: 2px !important; }

        body.mode-dual .q-block-spacer { height: 5px !important; }

        body.mode-dual .roll-box { width: 16px !important; height: 16px !important; }

        body.mode-dual .roll-matrix { gap: 2px !important; }

        body.mode-dual .roll-digit-label { font-size: 8.5px !important; }

        body.mode-dual .sheet-footer { font-size: 8px !important; padding-top: 3px !important; margin-top: 4px !important; }



        /* Top Header */

        .sheet-header {

            display: flex;

            justify-content: space-between;

            align-items: flex-start;

            padding-bottom: ${dyn.headerPadB};

            border-bottom: 2.5px solid #000000;

            margin-bottom: ${dyn.headerMarB};

        }

        .exam-title-group h1 {

            margin: 0;

            font-size: ${dyn.headerTitleFont};

            font-weight: 900;

            color: #000000;

            letter-spacing: -0.02em;

            line-height: 1.2;

        }

        .exam-subtitle {

            font-size: ${dyn.headerSubFont};

            font-weight: 800;

            color: #334155;

            margin-top: 3px;

            letter-spacing: 0.04em;

        }

        .sheet-meta-badges {

            display: flex;

            align-items: center;

            gap: 8px;

        }

        .meta-badge {

            border: 1.6px solid #000000;

            padding: ${dyn.metaBadgePad};

            border-radius: 6px;

            background: #f8fafc;

            font-size: ${dyn.metaBadgeFont};

            font-weight: 800;

        }



        /* Student Info Table & Written Score Row */

        .top-info-section {

            display: flex;

            gap: 12px;

            margin-bottom: ${dyn.topInfoMargin};

            align-items: stretch;

        }



        /* Student Info Table (Boxed Widget matching user request) */

        .student-table {

            flex: 1;

            border: 1.8px solid #000000;

            border-collapse: collapse;

            font-size: ${dyn.tableFont};

            font-weight: 700;

            width: 100%;

        }

        .student-table td {

            border: 1.4px solid #000000;

            padding: ${dyn.tablePad};

            height: ${dyn.tableRowH};

            vertical-align: middle;

        }

        .student-table .td-label {

            width: ${dyn.labelWidth};

            background: #ffffff;

            font-weight: 900;

            white-space: nowrap;

            letter-spacing: 0.01em;

        }

        .student-table .td-fill {

            background: #ffffff;

        }

        .model-bubbles-row {

            display: flex;

            align-items: center;

            gap: ${dyn.modelBubbleGap};

        }

        .model-bubble-item {

            display: inline-flex;

            align-items: center;

            gap: 6px;

            font-size: ${dyn.modelLabelFont};

            font-weight: 900;

        }

        .model-bubble-item .bubble {

            width: ${dyn.modelBubbleSize};

            height: ${dyn.modelBubbleSize};

            border: 1.8px solid #000000;

            border-radius: 50%;

            display: inline-flex;

            align-items: center;

            justify-content: center;

        }



        /* Teacher's Written Score Box */

        .teacher-written-box {

            width: ${dyn.writtenBoxW};

            border: 1.8px solid #000000;

            border-radius: 4px;

            background: #ffffff;

            padding: 8px;

            display: flex;

            flex-direction: column;

            justify-content: space-between;

            text-align: center;

        }

        .twb-header {

            font-size: ${dyn.writtenBoxTitleFont};

            font-weight: 900;

            color: #b91c1c;

            line-height: 1.2;

        }

        .twb-sub {

            font-size: ${dyn.writtenBoxSubFont};

            font-weight: 800;

            color: #475569;

            margin-top: 2px;

        }

        .twb-score-area {

            height: ${dyn.writtenScoreAreaH};

            border-bottom: 2.5px solid #000000;

            margin: 6px 10px;

        }

        .twb-max {

            font-size: ${dyn.writtenMaxFont};

            font-weight: 900;

            color: #0f172a;

            border-top: 1px solid #cbd5e1;

            padding-top: 4px;

        }



        /* Registration Dots & OMR Grid Layout */

        .omr-main-grid {

            display: flex;

            align-items: stretch;

            justify-content: space-between;

            gap: 12px;

            padding: 4px 0;

            flex: 1;

        }



        /* Solid Black Square Registration Dots */

        .reg-dot-col {

            display: flex;

            flex-direction: column;

            justify-content: space-between;

            align-items: center;

            width: ${dyn.regDotColW};

            padding: 2px 0;

        }

        .reg-dot {

            width: ${dyn.regDotSize};

            height: ${dyn.regDotSize};

            background: #000000;

            border-radius: 1px;

            margin: 2px 0;

        }



        /* Roll No Section (Student Code Matrix) */

        .roll-section {

            width: ${isSpacious ? '170px' : (isMedium ? '150px' : '140px')};

            display: flex;

            flex-direction: column;

            align-items: center;

        }

        .roll-title {

            font-size: ${dyn.rollTitleFont};

            font-weight: 900;

            text-align: center;

            margin-bottom: ${dyn.rollBoxesMarB};

            letter-spacing: -0.01em;

        }

        .roll-boxes-row {

            display: flex;

            gap: ${dyn.rollBoxesGap};

            margin-bottom: ${dyn.rollBoxesMarB};

        }

        .roll-box {

            width: ${dyn.rollBoxW};

            height: ${dyn.rollBoxH};

            border: 1.8px solid #000000;

            background: #ffffff;

            border-radius: 2px;

        }

        .roll-matrix {

            display: flex;

            flex-direction: column;

            gap: ${dyn.rollRowGap};

        }

        .roll-row {

            display: flex;

            align-items: center;

            gap: 8px;

        }

        .roll-digit-label {

            width: 14px;

            text-align: right;

            font-size: ${dyn.rollDigitFont};

            font-weight: 800;

            color: #334155;

        }

        .roll-bubbles {

            display: flex;

            gap: ${dyn.rollBubblesGap};

        }



        /* MCQ Columns */

        .mcq-column {

            flex: 1;

            display: flex;

            flex-direction: column;

            align-items: center;

        }

        .mcq-col-title {

            font-size: ${dyn.colTitleFont};

            font-weight: 900;

            text-align: center;

            margin-bottom: 8px;

            letter-spacing: -0.01em;

            text-transform: uppercase;

        }

        .mcq-col-body {

            width: 100%;

            display: flex;

            flex-direction: column;

            align-items: center;

        }



        /* 5-Question Block Header (A B C D) */

        .omr-q-header-row {

            display: flex;

            align-items: center;

            width: 100%;

            max-width: ${dyn.colMaxWidth};

            margin-bottom: 3px;

        }

        .q-num-spacer {

            width: ${dyn.qNumWidth};

            display: inline-block;

        }

        .opt-labels {

            display: flex;

            justify-content: space-between;

            flex: 1;

            padding: ${dyn.optBubblePad};

        }

        .opt-labels span {

            width: ${dyn.bubbleSize};

            text-align: center;

            font-size: ${dyn.optHeaderFont};

            font-weight: 900;

            color: #1e293b;

        }



        /* Question Row */

        .omr-q-row {

            display: flex;

            align-items: center;

            width: 100%;

            max-width: ${dyn.colMaxWidth};

            margin-bottom: ${dyn.qRowMargin};

        }

        .q-num {

            width: ${dyn.qNumWidth};

            font-size: ${dyn.qNumFont};

            font-weight: 900;

            color: #0f172a;

            text-align: right;

            padding-right: 8px;

        }

        .opt-bubbles {

            display: flex;

            justify-content: space-between;

            flex: 1;

            padding: ${dyn.optBubblePad};

        }



        /* Hollow Circular Bubbles */

        .bubble {

            width: ${dyn.bubbleSize};

            height: ${dyn.bubbleSize};

            border: ${dyn.bubbleBorder} solid #000000;

            border-radius: 50%;

            display: inline-block;

            background: #ffffff;

            cursor: pointer;

        }



        /* Gap between 5-question groups */

        .q-block-spacer {

            height: ${dyn.qBlockSpacer};

            width: 100%;

        }



        /* Footer Instructions */

        .sheet-footer {

            border-top: 2px solid #000000;

            padding-top: ${dyn.footerPadT};

            margin-top: ${dyn.footerMarT};

            display: flex;

            justify-content: space-between;

            align-items: center;

            font-size: ${dyn.footerFont};

            font-weight: 700;

            color: #334155;

        }

        .inst-icons {

            display: flex;

            align-items: center;

            gap: 8px;

            font-weight: 800;

        }

        .inst-icons span {

            display: inline-flex;

            align-items: center;

            gap: 2px;

        }



        @media print {

            .preview-toolbar { display: none !important; }

            body { background: #ffffff !important; padding: 0 !important; }

            .sheet-wrapper { padding: 0 !important; margin: 0 !important; }

            .bubble-sheet-page {

                box-shadow: none !important;

                width: 100% !important;

                min-height: 279mm !important;

                height: 279mm !important;

                max-height: 279mm !important;

                padding: 4mm 6mm !important;

                margin: 0 !important;

                display: flex !important;

                flex-direction: column !important;

                justify-content: space-between !important;

                page-break-inside: avoid !important;

                page-break-after: avoid !important;

            }

            body.mode-dual .bubble-sheet-page {

                height: 138mm !important;

                min-height: 135mm !important;

                max-height: 138mm !important;

            }

        }

    </style>

</head>

<body>

    <!-- Top Preview Toolbar (Hidden in Print) -->

    <div class="preview-toolbar">

        <div style="display:flex; align-items:center; gap:12px;">

            <strong style="font-size:14px;">🖨️ Bubble Sheet Preview: ${escapeHtml(title)}</strong>

            <span style="color:#94a3b8; font-size:12px;">(${qCount} Questions &bull; Total: ${totalScore} Marks)</span>

        </div>

        <div style="display:flex; align-items:center; gap:10px;">

            <button class="mode-toggle-btn active" id="btn_mode_a4" onclick="setSheetMode('a4')">A4 Single Page</button>

            <button class="mode-toggle-btn" id="btn_mode_dual" onclick="setSheetMode('dual')">A5 Dual-Sheet (2 per A4)</button>

            <button class="btn-print" onclick="window.print()">

                <span>Print Bubble Sheet (Ctrl+P)</span>

            </button>

        </div>

    </div>



    <!-- Sheet Container -->

    <div class="sheet-wrapper" id="sheet_container">

        <div class="bubble-sheet-page" id="sheet_page_1">

            <!-- 4-Corner Homography Perspective Registration Anchors -->

            <div class="corner-marker corner-marker-tl"></div>

            <div class="corner-marker corner-marker-tr"></div>

            <div class="corner-marker corner-marker-bl"></div>

            <div class="corner-marker corner-marker-br"></div>

            <!-- 1. Header Row -->

            <div class="sheet-header">

                <div class="exam-title-group">

                    <h1>${escapeHtml(title)}</h1>

                    <div class="exam-subtitle">${escapeHtml(academyName)} &bull; ${escapeHtml(subject).toUpperCase()}</div>

                </div>

                <div class="sheet-meta-badges">

                    <span class="meta-badge">Total: <strong>${totalScore} Marks</strong></span>

                </div>

            </div>



            <!-- 2. Student Info Table & Written Score Box -->

            <div class="top-info-section">

                <table class="student-table">

                    <tr>

                        <td class="td-label">${escapeHtml(nameLabel)}</td>

                        <td class="td-fill"></td>

                    </tr>

                    <tr>

                        <td class="td-label">${escapeHtml(phoneLabel)}</td>

                        <td class="td-fill"></td>

                    </tr>

                    ${showParentPhone ? `

                    <tr>

                        <td class="td-label">${escapeHtml(parentPhoneLabel)}</td>

                        <td class="td-fill"></td>

                    </tr>

                    ` : ''}

                    <tr>

                        <td class="td-label">${escapeHtml(idLabel)}</td>

                        <td class="td-fill"></td>

                    </tr>

                    <tr>

                        <td class="td-label">${escapeHtml(modelLabel)}</td>

                        <td class="td-fill">

                            <div class="model-bubbles-row">

                                <span class="model-bubble-item"><span class="bubble"></span> A</span>

                                <span class="model-bubble-item"><span class="bubble"></span> B</span>

                                <span class="model-bubble-item"><span class="bubble"></span> C</span>

                                <span class="model-bubble-item"><span class="bubble"></span> D</span>

                            </div>

                        </td>

                    </tr>

                    ${showCenterQuestions ? `

                    <tr>

                        <td colspan="2" style="padding:0;">

                            <table style="width:100%; border-collapse:collapse; height:28px;">

                                <tr>

                                    <td style="width:50%; border-right:1.4px solid #000; direction:rtl; text-align:right; font-weight:800; padding:4px 10px; font-size:12px;">

                                        ${escapeHtml(attendLabel)}

                                    </td>

                                    <td style="width:50%; direction:rtl; text-align:right; font-weight:800; padding:4px 10px; font-size:12px;">

                                        ${escapeHtml(examCenterLabel)}

                                    </td>

                                </tr>

                            </table>

                        </td>

                    </tr>

                    ` : ''}

                </table>



                ${showWrittenBox ? `

                <!-- Teacher's Written Score Box -->

                <div class="teacher-written-box">

                    <div>

                        <div class="twb-header">${escapeHtml(writtenBoxTitle)}</div>

                        <div class="twb-sub">${escapeHtml(writtenBoxSub)}</div>

                    </div>

                    <div class="twb-score-area"></div>

                    <div class="twb-max">من <strong>${writtenMax}</strong> درجات</div>

                </div>

                ` : ''}

            </div>



            <!-- 3. OMR Grid: Framed with Black Registration Dots -->

            <div class="omr-main-grid">

                <!-- Left Registration Dots -->

                ${buildRegDotsColHtml()}



                <!-- Roll No Matrix -->

                <div class="roll-section">

                    <div class="roll-title">${escapeHtml(rollTitle)}</div>

                    <div class="roll-boxes-row">

                        ${Array.from({ length: idDigits }).map(() => '<span class="roll-box"></span>').join('')}

                    </div>

                    <div class="roll-matrix">

                        ${[0, 1, 2, 3, 4, 5, 6, 7, 8, 9].map(d => `

                            <div class="roll-row">

                                <span class="roll-digit-label">${d}</span>

                                <div class="roll-bubbles">

                                    ${Array.from({ length: idDigits }).map((_, col) => `

                                        <span class="bubble" data-col="${col}" data-val="${d}"></span>

                                    `).join('')}

                                </div>

                            </div>

                        `).join('')}

                    </div>

                </div>



                <!-- Middle Registration Dots -->

                ${buildRegDotsColHtml()}



                <!-- MCQ Columns -->

                ${mcqColumnsHtml}



                <!-- Right Registration Dots -->

                ${buildRegDotsColHtml()}

            </div>



            <!-- 4. Footer & Scanner Guide -->

            <div class="sheet-footer">

                <div class="inst-icons">

                    <span>تعليمات التظليل:</span>

                    <span>● تظليل كامل (صحيح)</span>

                    <span style="color:#ba1a1a;">✕ ✗ غير صحيح</span>

                </div>

                <div>OMR Serial: <strong>${exam.id ? exam.id.substring(0, 12).toUpperCase() : 'KELANY-OMR'}</strong></div>

                <div>${escapeHtml(footerNote)}</div>

            </div>

        </div>

    </div>



    <script>

        function setSheetMode(mode) {

            const body = document.body;

            const btnA4 = document.getElementById('btn_mode_a4');

            const btnDual = document.getElementById('btn_mode_dual');

            const container = document.getElementById('sheet_container');

            const page1 = document.getElementById('sheet_page_1');



            if (mode === 'dual') {

                body.classList.add('mode-dual');

                btnA4.classList.remove('active');

                btnDual.classList.add('active');



                // Duplicate the sheet for 2-up printing on single A4 sheet

                if (!document.getElementById('sheet_page_2')) {

                    const page2 = page1.cloneNode(true);

                    page2.id = 'sheet_page_2';

                    container.appendChild(page2);

                }

            } else {

                body.classList.remove('mode-dual');

                btnA4.classList.add('active');

                btnDual.classList.remove('active');



                const page2 = document.getElementById('sheet_page_2');

                if (page2) page2.remove();

            }

        }



        function escapeHtml(str) {

            return String(str).replace(/[&<>"']/g, function(m) {

                return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[m];

            });

        }

    </script>

</body>

</html>`;

        },



        /**

         * Client-Side Image Processing & OMR Detection

         * Input: HTMLCanvasElement or HTMLImageElement

         * Output: { success, model, studentCode, answers: { 1: 'A', 2: 'B', ... }, confidence }

         */

                        /**

         * Image Quality Assessment Gate

         * Rejects blurry, overly dark, or low-resolution images

         */

        checkQuality(canvas) {

            const w = canvas.width;

            const h = canvas.height;

            if (w < 600 || h < 800) {

                return {

                    passed: false,

                    reason: "LOW_RESOLUTION",

                    message: "Image resolution is too low for accurate OMR detection (minimum 600x800). Please capture a closer photo.",

                    details: { width: w, height: h }

                };

            }



            const ctx = canvas.getContext('2d');

            // Sample down to max 600x800 for instant quality calculation

            const sampleW = Math.min(w, 600);

            const sampleH = Math.min(h, 800);

            const offscreen = (typeof document !== 'undefined') ? document.createElement('canvas') : null;

            let sampleData;

            

            if (offscreen) {

                offscreen.width = sampleW;

                offscreen.height = sampleH;

                const octx = offscreen.getContext('2d');

                octx.drawImage(canvas, 0, 0, sampleW, sampleH);

                sampleData = octx.getImageData(0, 0, sampleW, sampleH).data;

            } else {

                sampleData = ctx.getImageData(0, 0, sampleW, sampleH).data;

            }



            // Convert sample to grayscale and calculate mean luminance

            const gray = new Uint8Array(sampleW * sampleH);

            let sumLum = 0;

            for (let i = 0, j = 0; i < sampleData.length; i += 4, j++) {

                const lum = Math.round((sampleData[i] * 299 + sampleData[i + 1] * 587 + sampleData[i + 2] * 114) / 1000);

                gray[j] = lum;

                sumLum += lum;

            }

            const meanLum = sumLum / gray.length;



            if (meanLum < 38) {

                return {

                    passed: false,

                    reason: "TOO_DARK",

                    message: "The captured image is too dark. Please scan under good lighting or turn on your device flash.",

                    details: { meanLum, width: w, height: h }

                };

            }

            if (meanLum > 250) {

                return {

                    passed: false,

                    reason: "OVEREXPOSED",

                    message: "The image is overexposed or blank white. Please adjust camera exposure and retake.",

                    details: { meanLum, width: w, height: h }

                };

            }



            // Laplacian Variance for Blur Detection

            // Fast 3x3 Laplacian kernel: [0, 1, 0, 1, -4, 1, 0, 1, 0]

            let lapSum = 0;

            let lapSqSum = 0;

            let edgePixels = 0;

            const stride = 2; // sample every 2nd pixel for maximum speed



            for (let y = 1; y < sampleH - 1; y += stride) {

                const row = y * sampleW;

                for (let x = 1; x < sampleW - 1; x += stride) {

                    const center = gray[row + x];

                    const lap = gray[row + x - 1] + gray[row + x + 1] + gray[row - sampleW + x] + gray[row + sampleW + x] - (center * 4);

                    lapSum += lap;

                    lapSqSum += (lap * lap);

                    edgePixels++;

                }

            }



            const lapMean = lapSum / edgePixels;

            const lapVariance = (lapSqSum / edgePixels) - (lapMean * lapMean);



            if (lapVariance < 28.0) {

                return {

                    passed: false,

                    reason: "TOO_BLURRY",

                    message: "The image is blurry or out of focus. Please hold your camera steady and retake.",

                    details: { blurVariance: Math.round(lapVariance), meanLum: Math.round(meanLum), width: w, height: h }

                };

            }



            // Sheet Distance / Framing Gate ("Move Closer" Detection)

            let minDarkX = sampleW, maxDarkX = 0, minDarkY = sampleH, maxDarkY = 0;

            let darkCount = 0;

            const darkThreshold = Math.min(85, meanLum * 0.55);



            for (let y = 10; y < sampleH - 10; y += 4) {

                const row = y * sampleW;

                for (let x = 10; x < sampleW - 10; x += 4) {

                    if (gray[row + x] < darkThreshold) {

                        darkCount++;

                        if (x < minDarkX) minDarkX = x;

                        if (x > maxDarkX) maxDarkX = x;

                        if (y < minDarkY) minDarkY = y;

                        if (y > maxDarkY) maxDarkY = y;

                    }

                }

            }



            const darkSpanW = (maxDarkX > minDarkX) ? (maxDarkX - minDarkX) / sampleW : 0;

            const darkSpanH = (maxDarkY > minDarkY) ? (maxDarkY - minDarkY) / sampleH : 0;



            if (darkCount > 15 && (darkSpanW < 0.40 || darkSpanH < 0.35)) {

                return {

                    passed: false,

                    reason: "SHEET_TOO_FAR",

                    message: "Move Closer to Paper (الورقة بعيدة جداً): The answer sheet is too far from the camera. Please bring your phone closer so the sheet fills the viewfinder box.",

                    details: {

                        coverageWidth: Math.round(darkSpanW * 100) + "%",

                        coverageHeight: Math.round(darkSpanH * 100) + "%",

                        tip: "Hold camera 20-30 cm directly above the paper"

                    }

                };

            }



            return {

                passed: true,

                details: { blurVariance: Math.round(lapVariance), meanLum: Math.round(meanLum), width: w, height: h }

            };

        },



        /**

         * Solves 3x3 Perspective Homography Matrix using Gaussian Elimination

         */

        getPerspectiveTransform(src, dst) {

            const A = [];

            const b = [];

            for (let i = 0; i < 4; i++) {

                const sx = src[i].x, sy = src[i].y;

                const dx = dst[i].x, dy = dst[i].y;

                A.push([sx, sy, 1, 0, 0, 0, -dx * sx, -dx * sy]);

                b.push(dx);

                A.push([0, 0, 0, sx, sy, 1, -dy * sx, -dy * sy]);

                b.push(dy);

            }

            

            const n = 8;

            for (let i = 0; i < n; i++) {

                let maxRow = i;

                for (let k = i + 1; k < n; k++) {

                    if (Math.abs(A[k][i]) > Math.abs(A[maxRow][i])) maxRow = k;

                }

                const tmpA = A[i]; A[i] = A[maxRow]; A[maxRow] = tmpA;

                const tmpB = b[i]; b[i] = b[maxRow]; b[maxRow] = tmpB;

                

                const pivot = A[i][i];

                if (Math.abs(pivot) < 1e-10) continue;

                for (let j = i; j < n; j++) A[i][j] /= pivot;

                b[i] /= pivot;

                

                for (let k = 0; k < n; k++) {

                    if (k === i) continue;

                    const factor = A[k][i];

                    for (let j = i; j < n; j++) A[k][j] -= factor * A[i][j];

                    b[k] -= factor * b[i];

                }

            }

            return [b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7], 1.0];

        },



        /**

         * Perspective Rectification: Warps skewed photos to standard 1200x1697 A4 canvas

         */

        rectifySheet(sourceCanvas, targetW = 1200, targetH = 1697, questionCount = 30) {

            const srcW = sourceCanvas.width;

            const srcH = sourceCanvas.height;

            const srcCtx = sourceCanvas.getContext('2d');

            const srcData = srcCtx.getImageData(0, 0, srcW, srcH).data;



            // Compute grayscale & mean luminance
            const gray = new Uint8Array(srcW * srcH);
            let sumLum = 0;
            for (let i = 0, j = 0; i < srcData.length; i += 4, j++) {
                const lum = Math.round((srcData[i] * 299 + srcData[i + 1] * 587 + srcData[i + 2] * 114) / 1000);
                gray[j] = lum;
                sumLum += lum;
            }
            const meanLum = sumLum / (srcW * srcH);

            // Find candidate black fiducial squares
            const minBlob = Math.max(6, Math.round(srcW * 0.006));
            const maxBlob = Math.max(50, Math.round(srcW * 0.050));
            const visited = new Uint8Array(srcW * srcH);
            const candidateDots = [];
            const step = Math.max(3, Math.floor(minBlob / 2));
            const darkThresh = Math.min(95, Math.max(65, Math.round(meanLum * 0.45)));



            for (let y = step; y < srcH - step; y += step) {

                for (let x = step; x < srcW - step; x += step) {

                    const idx = y * srcW + x;

                    if (visited[idx] || gray[idx] >= darkThresh) continue;



                    let minX = x, maxX = x, minY = y, maxY = y;

                    let blobPixels = 0;

                    const queue = [idx];

                    visited[idx] = 1;



                    while (queue.length > 0 && queue.length < 3500) {

                        const curr = queue.pop();

                        const cy = Math.floor(curr / srcW);

                        const cx = curr % srcW;

                        blobPixels++;



                        if (cx < minX) minX = cx;

                        if (cx > maxX) maxX = cx;

                        if (cy < minY) minY = cy;

                        if (cy > maxY) maxY = cy;



                        const neighbors = [curr - 1, curr + 1, curr - srcW, curr + srcW];

                        for (let k = 0; k < 4; k++) {

                            const nIdx = neighbors[k];

                            if (nIdx >= 0 && nIdx < visited.length && !visited[nIdx]) {

                                visited[nIdx] = 1;

                                if (gray[nIdx] < darkThresh) {

                                    queue.push(nIdx);

                                }

                            }

                        }

                    }



                    const bw = maxX - minX + 1;

                    const bh = maxY - minY + 1;

                    const aspect = bw / Math.max(1, bh);

                    const fillDensity = blobPixels / (bw * bh);



                    // High fill density (> 0.80) to select squares and exclude circular bubbles

                    if (bw >= minBlob && bw <= maxBlob &&

                        bh >= minBlob && bh <= maxBlob &&

                        aspect >= 0.70 && aspect <= 1.40 &&

                        fillDensity >= 0.80) {

                        candidateDots.push({

                            x: (minX + maxX) / 2,

                            y: (minY + maxY) / 2

                        });

                    }

                }

            }



            // Create target output canvas

            const outCanvas = (typeof document !== 'undefined') ? document.createElement('canvas') : {

                width: targetW,

                height: targetH,

                getContext: () => ({ getImageData: () => ({ data: new Uint8ClampedArray(targetW * targetH * 4) }) })

            };

            outCanvas.width = targetW;

            outCanvas.height = targetH;

            const outCtx = outCanvas.getContext('2d');



            // If we found at least 4 distinct corners, compute homography

            if (candidateDots.length >= 4) {

                // Find 4 extreme corners: TL, TR, BR, BL

                let tl = candidateDots[0], tr = candidateDots[0], br = candidateDots[0], bl = candidateDots[0];

                let minSum = Infinity, maxSum = -Infinity;

                let minDiff = Infinity, maxDiff = -Infinity;



                for (const pt of candidateDots) {

                    const s = pt.x + pt.y;

                    const d = pt.x - pt.y;

                    if (s < minSum) { minSum = s; tl = pt; }

                    if (s > maxSum) { maxSum = s; br = pt; }

                    if (d > maxDiff) { maxDiff = d; tr = pt; }

                    if (d < minDiff) { minDiff = d; bl = pt; }

                }



                // Geometric dimensions of detected corner quadrilateral

                const boxW = Math.max(Math.hypot(tr.x - tl.x, tr.y - tl.y), Math.hypot(br.x - bl.x, br.y - bl.y));

                const boxH = Math.max(Math.hypot(bl.x - tl.x, bl.y - tl.y), Math.hypot(br.x - tr.x, br.y - tr.y));

                const aspect = boxW / Math.max(1, boxH);



                // Derive column bounds based on question count

                const qCount = Math.max(1, Math.min(100, parseInt(questionCount, 10) || 30));

                const numMcqCols = qCount <= 20 ? 1 : (qCount <= 40 ? 2 : (qCount <= 75 ? 3 : 4));

                let regX;

                if (numMcqCols === 1) regX = [100, 480, 1100];

                else if (numMcqCols === 2) regX = [100, 420, 800, 1100];

                else if (numMcqCols === 3) regX = [80, 340, 620, 900, 1120];

                else regX = [60, 290, 530, 770, 1010, 1140];



                const gridTopY = 480;

                const gridBotY = 1550;

                const gridLeftX = regX[0];

                const gridRightX = regX[regX.length - 1];



                let dstCorners;

                // If aspect >= 0.80, candidate dots are the OMR Grid Fiducials!

                // If aspect < 0.80, candidate dots are the Full Page Perimeter Corner Markers (aspect ~0.68)

                if (aspect >= 0.80) {

                    dstCorners = [

                        { x: gridLeftX, y: gridTopY },

                        { x: gridRightX, y: gridTopY },

                        { x: gridRightX, y: gridBotY },

                        { x: gridLeftX, y: gridBotY }

                    ];

                } else {

                    dstCorners = [

                        { x: 60, y: 60 },

                        { x: targetW - 60, y: 60 },

                        { x: targetW - 60, y: targetH - 60 },

                        { x: 60, y: targetH - 60 }

                    ];

                }

                const srcCorners = [tl, tr, br, bl];



                // Inverse homography: maps each pixel in target (dx, dy) back to source (sx, sy)

                const H_inv = this.getPerspectiveTransform(dstCorners, srcCorners);

                const outImgData = outCtx.createImageData(targetW, targetH);

                const outData = outImgData.data;



                // Bilinear backward mapping

                for (let dy = 0; dy < targetH; dy++) {

                    const rowOffset = dy * targetW * 4;

                    for (let dx = 0; dx < targetW; dx++) {

                        const denom = H_inv[6] * dx + H_inv[7] * dy + H_inv[8];

                        const sx = (H_inv[0] * dx + H_inv[1] * dy + H_inv[2]) / denom;

                        const sy = (H_inv[3] * dx + H_inv[4] * dy + H_inv[5]) / denom;



                        const px = Math.floor(sx);

                        const py = Math.floor(sy);



                        const outIdx = rowOffset + dx * 4;



                        if (px >= 0 && px < srcW - 1 && py >= 0 && py < srcH - 1) {

                            const fx = sx - px;

                            const fy = sy - py;

                            const idx00 = (py * srcW + px) * 4;

                            const idx10 = idx00 + 4;

                            const idx01 = ((py + 1) * srcW + px) * 4;

                            const idx11 = idx01 + 4;



                            // Bilinear interpolation for R, G, B

                            for (let c = 0; c < 3; c++) {

                                const c0 = srcData[idx00 + c] * (1 - fx) + srcData[idx10 + c] * fx;

                                const c1 = srcData[idx01 + c] * (1 - fx) + srcData[idx11 + c] * fx;

                                outData[outIdx + c] = Math.round(c0 * (1 - fy) + c1 * fy);

                            }

                            outData[outIdx + 3] = 255;

                        } else {

                            outData[outIdx] = 250;

                            outData[outIdx + 1] = 250;

                            outData[outIdx + 2] = 250;

                            outData[outIdx + 3] = 255;

                        }

                    }

                }

                outCtx.putImageData(outImgData, 0, 0);

                return { rectifiedCanvas: outCanvas, wasRectified: true, corners: srcCorners };

            } else {

                // Fallback: draw directly centered with aspect fit

                outCtx.fillStyle = '#fafafa';

                outCtx.fillRect(0, 0, targetW, targetH);

                const scale = Math.min(targetW / srcW, targetH / srcH);

                const dw = srcW * scale;

                const dh = srcH * scale;

                const dx = (targetW - dw) / 2;

                const dy = (targetH - dh) / 2;

                outCtx.drawImage(sourceCanvas, dx, dy, dw, dh);

                return { rectifiedCanvas: outCanvas, wasRectified: false, corners: null };

            }

        },



        /**

         * Multi-Feature Bubble Core Extraction

         * Extracts inner core pixels, border-excluded fill ratio, variance and net contrast

         */

        analyzeBubbleCore(gray, cx, cy, w, h, rInner = 6) {

            if (cx < rInner || cx >= w - rInner || cy < rInner || cy >= h - rInner) {

                return { fillRatio: 0, netContrast: 0, variance: 0, paperLevel: 245 };

            }



            // 1. Inner core patch (strictly inside bubble circle)

            let coreSum = 0;

            let coreSqSum = 0;

            let coreCount = 0;

            const r2 = rInner * rInner;



            for (let dy = -rInner; dy <= rInner; dy++) {

                const py = cy + dy;

                const row = py * w;

                for (let dx = -rInner; dx <= rInner; dx++) {

                    if (dx * dx + dy * dy <= r2) {

                        const px = cx + dx;

                        const lum = gray[row + px];

                        coreSum += lum;

                        coreSqSum += (lum * lum);

                        coreCount++;

                    }

                }

            }

            const coreMeanLum = coreCount > 0 ? (coreSum / coreCount) : 255;

            const coreMeanSq = coreCount > 0 ? (coreSqSum / coreCount) : 0;

            const variance = Math.max(0, coreMeanSq - (coreMeanLum * coreMeanLum));



            // 2. Local paper background (annulus gap around bubble: radius 12 to 17)

            let paperSum = 0;

            let paperCount = 0;

            const rAnnulusInner2 = 12 * 12;

            const rAnnulusOuter2 = 17 * 17;



            for (let dy = -17; dy <= 17; dy += 2) {

                const py = cy + dy;

                if (py < 0 || py >= h) continue;

                const row = py * w;

                for (let dx = -17; dx <= 17; dx += 2) {

                    const dist2 = dx * dx + dy * dy;

                    if (dist2 >= rAnnulusInner2 && dist2 <= rAnnulusOuter2) {

                        const px = cx + dx;

                        if (px >= 0 && px < w) {

                            paperSum += gray[row + px];

                            paperCount++;

                        }

                    }

                }

            }

            const paperLevel = paperCount > 0 ? (paperSum / paperCount) : 245;



            // 3. Measure filled pixels inside core (pixels significantly darker than paper)

            const fillThresh = paperLevel * 0.72;

            let filledCount = 0;



            for (let dy = -rInner; dy <= rInner; dy++) {

                const py = cy + dy;

                const row = py * w;

                for (let dx = -rInner; dx <= rInner; dx++) {

                    if (dx * dx + dy * dy <= r2) {

                        const px = cx + dx;

                        if (gray[row + px] < fillThresh) {

                            filledCount++;

                        }

                    }

                }

            }

            const fillRatio = coreCount > 0 ? (filledCount / coreCount) : 0;



            const meanDarkness = 255.0 - coreMeanLum;

            const paperDarkness = 255.0 - paperLevel;

            const netContrast = Math.max(0, meanDarkness - paperDarkness);



            return { fillRatio, netContrast, variance, paperLevel };

        },



        /**

         * 4-State Question Answer Classification

         * Assigns states: SELECTED, EMPTY, MULTIPLE, UNCERTAIN

         */

        classifyQuestion(gray, optionCoords, w, h) {

            const opts = ['A', 'B', 'C', 'D'];

            const scores = [];



            for (const opt of opts) {

                const coord = optionCoords[opt];

                const res = this.analyzeBubbleCore(gray, Math.round(coord.x), Math.round(coord.y), w, h, 6);

                const score = (res.fillRatio * 0.6) + (Math.min(1.0, res.netContrast / 100.0) * 0.4);

                scores.push({

                    opt: opt,

                    fill: res.fillRatio,

                    contrast: res.netContrast,

                    variance: res.variance,

                    score: score

                });

            }



            scores.sort((a, b) => b.score - a.score);

            const best = scores[0];

            const second = scores[1];



            // 1. EMPTY: No shaded bubble

            if (best.score < 0.22 && best.fill < 0.25) {

                return {

                    state: 'EMPTY',

                    selected: null,

                    confidence: Math.round((1.0 - best.score) * 100) / 100,

                    scores: scores

                };

            }



            // 2. MULTIPLE: Two or more clearly marked answers

            if (best.score >= 0.38 && second.score >= 0.36 && (best.score - second.score) < 0.12) {

                return {

                    state: 'MULTIPLE',

                    selected: [best.opt, second.opt],

                    confidence: Math.round(second.score * 100) / 100,

                    scores: scores

                };

            }



            // 3. UNCERTAIN: Erasure residue smudge (high variance), faint fill, or narrow margin

            if ((best.score >= 0.22 && best.score < 0.40) ||

                (best.variance > 700 && best.fill < 0.45) ||

                ((best.score - second.score) < 0.16 && best.score < 0.55)) {

                return {

                    state: 'UNCERTAIN',

                    selected: best.opt,

                    confidence: Math.round(best.score * 100) / 100,

                    scores: scores

                };

            }



            // 4. SELECTED: One clearly marked answer

            const margin = best.score - second.score;

            const confidence = Math.min(0.99, Math.max(0.80, 0.70 + margin * 0.5));

            return {

                state: 'SELECTED',

                selected: best.opt,

                confidence: Math.round(confidence * 100) / 100,

                scores: scores

            };

        },



        /**

         * Production OMR Engine Master Scan Pipeline

         * Input: HTMLCanvasElement or Image

         * Output: Complete scan report with quality, rectified canvas, confidence, and 4-state classifications

         */

        scanImage(canvas, questionCount = 30) {

            // Step 1: Quality Gate

            const quality = this.checkQuality(canvas);

            if (!quality.passed) {

                return {

                    success: false,

                    error: quality.reason,

                    message: quality.message,

                    details: quality.details

                };

            }



            // Step 2: Perspective Rectification

            const TARGET_W = 1200;

            const TARGET_H = 1697;

            const { rectifiedCanvas, wasRectified } = this.rectifySheet(canvas, TARGET_W, TARGET_H, questionCount);



            const rCtx = rectifiedCanvas.getContext('2d');
            const rData = rCtx.getImageData(0, 0, TARGET_W, TARGET_H).data;
            const gray = new Uint8Array(TARGET_W * TARGET_H);
            for (let i = 0, j = 0; i < rData.length; i += 4, j++) {
                // Enhanced ink darkness: heavily weights red and green so blue ballpoint ink and pencil graphite both produce deep contrast
                gray[j] = Math.round((rData[i] * 500 + rData[i + 1] * 400 + rData[i + 2] * 100) / 1000);
            }

            // Step 3: Compute Calibrated Coordinates on Rectified Canvas
            const qCount = Math.max(1, Math.min(100, parseInt(questionCount, 10) || 30));
            const numMcqCols = qCount <= 20 ? 1 : (qCount <= 40 ? 2 : (qCount <= 75 ? 3 : 4));
            const qPerCol = Math.ceil(qCount / numMcqCols);

            const gridTopY = 480;
            const gridBotY = 1550;

            // Step 4: Read Model (A, B, C, D)
            // Supports standard table Model row (y=265), tall table (y=340), wide & narrow layouts
            let detectedModel = 'A';
            let bestModelScore = -1.0;
            let detectedModelCoord = null;

            const candidateModelConfigs = [
                { y: 265, xs: { 'A': 360, 'B': 440, 'C': 520, 'D': 600 } },
                { y: 340, xs: { 'A': 360, 'B': 440, 'C': 520, 'D': 600 } },
                { y: 265, xs: { 'A': 250, 'B': 290, 'C': 330, 'D': 370 } },
                { y: 340, xs: { 'A': 250, 'B': 290, 'C': 330, 'D': 370 } }
            ];

            for (const cfg of candidateModelConfigs) {
                const my = cfg.y;
                const xs = cfg.xs;
                const modelCoords = {
                    'A': { x: xs['A'], y: my },
                    'B': { x: xs['B'], y: my },
                    'C': { x: xs['C'], y: my },
                    'D': { x: xs['D'], y: my }
                };
                const res = this.classifyQuestion(gray, modelCoords, TARGET_W, TARGET_H);
                if (res.state === 'SELECTED' && res.selected && res.confidence > bestModelScore) {
                    bestModelScore = res.confidence;
                    detectedModel = res.selected;
                    detectedModelCoord = { x: xs[res.selected], y: my };
                }
            }

            // Step 5: Read Student Roll No (5 Digits)
            // Calibrated against printable template layout (10 rows: 0 to 9)
            const rollRowYs = [604, 657, 708, 763, 817, 872, 924, 974, 1028, 1080];
            const rollColXs = [268, 326, 385, 443, 502]; // 5 digits
            const detectedRollCoords = [];

            const idDigits = [];
            for (let c = 0; c < rollColXs.length; c++) {
                const cx = rollColXs[c];
                const digitScores = [];
                for (let d = 0; d <= 9; d++) {
                    const cy = rollRowYs[d];
                    const res = this.analyzeBubbleCore(gray, cx, cy, TARGET_W, TARGET_H, 6);
                    const s = (res.fillRatio * 0.6) + (Math.min(1.0, res.netContrast / 100.0) * 0.4);
                    digitScores.push({ digit: d, score: s, x: cx, y: cy });
                }
                digitScores.sort((a, b) => b.score - a.score);
                const best = digitScores[0];
                const second = digitScores[1];
                if (best.score > 0.25 && (best.score - second.score) > 0.08) {
                    idDigits.push(best.digit);
                    detectedRollCoords.push({ x: best.x, y: best.y, digit: best.digit });
                } else {
                    idDigits.push('?');
                }
            }
            const detectedStudentCode = idDigits.join('');

            // Step 6: Read MCQ Questions with Calibrated Coordinates & 4-State Classifier
            const detectedAnswers = {};
            const optOffsets = [0.32, 0.49, 0.66, 0.83];

            // Calibrated coordinates for 15-question single-column exams
            const qYs15 = [
                656, 708, 764, 817, 869,     // Block 1: Q1..5
                978, 1030, 1082, 1139, 1191, // Block 2: Q6..10
                1300, 1352, 1404, 1456, 1509 // Block 3: Q11..15
            ];
            const optXs15 = { 'A': 796, 'B': 852, 'C': 910, 'D': 971 };

            // Calibrated column X boundaries for 1, 2, 3, or 4 columns
            let regX;
            if (numMcqCols === 1) regX = [100, 480, 1100];
            else if (numMcqCols === 2) regX = [100, 420, 800, 1100];
            else if (numMcqCols === 3) regX = [80, 340, 620, 900, 1120];
            else regX = [60, 290, 530, 770, 1010, 1140];

            // Calibrated vertical dimensions matching template CSS
            const isSpacious = qPerCol <= 16;
            const isMedium = qPerCol > 16 && qPerCol <= 24;
            const rowStepY = isSpacious ? 48.0 : (isMedium ? 42.0 : 36.0);
            const blockHeaderH = isSpacious ? 42.0 : (isMedium ? 36.0 : 30.0);
            const blockSpacerH = isSpacious ? 38.0 : (isMedium ? 28.0 : 20.0);
            const colStartY = gridTopY + (isSpacious ? 25.0 : 18.0);

            let uncertainCount = 0;
            let multipleCount = 0;
            let emptyCount = 0;
            let totalConfidence = 0;

            for (let q = 1; q <= qCount; q++) {
                let qCoords;
                let qy;
                let effColLeft, effColW;

                if (numMcqCols === 1 && qCount <= 15 && (q - 1) < qYs15.length) {
                    qy = qYs15[q - 1];
                    effColLeft = 750;
                    effColW = 260;
                    qCoords = {
                        'A': { x: optXs15['A'], y: qy },
                        'B': { x: optXs15['B'], y: qy },
                        'C': { x: optXs15['C'], y: qy },
                        'D': { x: optXs15['D'], y: qy }
                    };
                } else {
                    const colIdx = Math.floor((q - 1) / qPerCol);
                    const inCol = (q - 1) % qPerCol;
                    const blockIdx = Math.floor(inCol / 5);
                    const posInBlock = inCol % 5;

                    const xLeft = regX[colIdx + 1] || regX[1];
                    const xRight = regX[colIdx + 2] || (xLeft + 300);
                    const rawColW = xRight - xLeft;
                    effColW = Math.min(rawColW, (numMcqCols === 1 ? 320 : 340));
                    const colCenterX = (xLeft + xRight) / 2;
                    effColLeft = (numMcqCols === 1) ? (colCenterX - effColW / 2) : xLeft;

                    qy = Math.round(colStartY + (blockIdx * (5 * rowStepY + blockHeaderH + blockSpacerH)) + blockHeaderH + (posInBlock * rowStepY));
                    qCoords = {
                        'A': { x: Math.round(effColLeft + effColW * optOffsets[0]), y: qy },
                        'B': { x: Math.round(effColLeft + effColW * optOffsets[1]), y: qy },
                        'C': { x: Math.round(effColLeft + effColW * optOffsets[2]), y: qy },
                        'D': { x: Math.round(effColLeft + effColW * optOffsets[3]), y: qy }
                    };
                }

                const classRes = this.classifyQuestion(gray, qCoords, TARGET_W, TARGET_H);
                classRes.coords = qCoords;
                classRes.effColLeft = effColLeft;
                classRes.effColW = effColW;
                classRes.qy = qy;
                detectedAnswers[q] = classRes;

                totalConfidence += classRes.confidence;
                if (classRes.state === 'UNCERTAIN') uncertainCount++;
                else if (classRes.state === 'MULTIPLE') multipleCount++;
                else if (classRes.state === 'EMPTY') emptyCount++;
            }

            const overallConfidence = Math.round((totalConfidence / qCount) * 100);

            // Step 7: Create Annotated Human Review Overlay Canvas
            const overlayCanvas = (typeof document !== 'undefined') ? document.createElement('canvas') : null;
            if (overlayCanvas) {
                overlayCanvas.width = TARGET_W;
                overlayCanvas.height = TARGET_H;
                const octx = overlayCanvas.getContext('2d');
                octx.drawImage(rectifiedCanvas, 0, 0);

                // 1. Draw green circle on detected Model bubble
                if (detectedModelCoord) {
                    octx.strokeStyle = '#10b981';
                    octx.lineWidth = 4;
                    octx.beginPath();
                    octx.arc(detectedModelCoord.x, detectedModelCoord.y, 16, 0, 2 * Math.PI);
                    octx.stroke();
                }

                // 2. Draw green circles on detected Roll No bubbles
                for (const rc of detectedRollCoords) {
                    octx.strokeStyle = '#10b981';
                    octx.lineWidth = 3;
                    octx.beginPath();
                    octx.arc(rc.x, rc.y, 14, 0, 2 * Math.PI);
                    octx.stroke();
                }

                // 3. Draw highlighted circles/boxes on MCQ questions
                for (let q = 1; q <= qCount; q++) {
                    const ans = detectedAnswers[q];
                    const qy = ans.qy;
                    const effColLeft = ans.effColLeft;
                    const effColW = ans.effColW;

                    if (ans.state === 'SELECTED' && ans.selected && ans.coords && ans.coords[ans.selected]) {
                        const bx = ans.coords[ans.selected].x;
                        const by = ans.coords[ans.selected].y;
                        octx.strokeStyle = '#10b981';
                        octx.lineWidth = 3.5;
                        octx.beginPath();
                        octx.arc(bx, by, 14, 0, 2 * Math.PI);
                        octx.stroke();
                    } else if (ans.state === 'UNCERTAIN') {
                        octx.strokeStyle = '#f59e0b';
                        octx.lineWidth = 2.5;
                        octx.setLineDash([4, 4]);
                        octx.strokeRect(effColLeft - 10, qy - 12, effColW + 20, 24);
                        octx.setLineDash([]);
                    } else if (ans.state === 'MULTIPLE') {
                        octx.strokeStyle = '#ef4444';
                        octx.lineWidth = 2.5;
                        octx.strokeRect(effColLeft - 10, qy - 12, effColW + 20, 24);
                    }
                }
            }

            return {

                success: true,

                model: detectedModel,

                studentCode: detectedStudentCode,

                answers: detectedAnswers,

                quality: quality.details,

                overallConfidence: overallConfidence,

                uncertainCount: uncertainCount,

                multipleCount: multipleCount,

                emptyCount: emptyCount,

                wasRectified: wasRectified,

                rectifiedCanvas: rectifiedCanvas,

                annotatedCanvas: overlayCanvas,

                scannedAt: new Date().toISOString()

            };

        }

    };



    global.OMREngine = OMR;

    if (typeof module !== 'undefined' && module.exports) {

        module.exports = OMR;

    }



})(typeof window !== 'undefined' ? window : this);

