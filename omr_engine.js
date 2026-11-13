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
                const lum = (data[i] * 299 + data[i + 1] * 587 + data[i + 2] * 114) / 1000;
                gray[j] = lum;
                sumLum += lum;
            }
            const avgLum = sumLum / (w * h);
            const darkThreshold = avgLum * 0.70;

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

            const layout = this.getLayout(questionCount);
            const modelOpts = ['A', 'B', 'C', 'D'];

            // 2. Read Exam Model (A, B, C, D)
            const modelScores = [];
            for (let i = 0; i < 4; i++) {
                const x = layout.model.baseX + (i * layout.model.stepX);
                const dark = sampleBubbleDarkness(x, layout.model.baseY, Math.round(w * 0.012));
                modelScores.push({ opt: modelOpts[i], dark });
            }
            modelScores.sort((a, b) => b.dark - a.dark);
            const detectedModel = (modelScores[0].dark > 0.30) ? modelScores[0].opt : 'A';

            // 3. Read Student ID (5 Digits)
            const idDigits = [];
            for (let col = 0; col < layout.studentCode.digits; col++) {
                const colScores = [];
                for (let digit = 0; digit <= 9; digit++) {
                    const x = layout.studentCode.baseX + (col * layout.studentCode.stepX);
                    const y = layout.studentCode.baseY + (digit * layout.studentCode.stepY);
                    const dark = sampleBubbleDarkness(x, y, Math.round(w * 0.010));
                    colScores.push({ digit, dark });
                }
                colScores.sort((a, b) => b.dark - a.dark);
                if (colScores[0].dark > 0.28) {
                    idDigits.push(colScores[0].digit);
                } else {
                    idDigits.push('?');
                }
            }
            const detectedStudentCode = idDigits.join('');

            // 4. Read MCQ Questions
            const detectedAnswers = {};
            const qCount = layout.qCount;
            const cols = layout.cols;
            const qPerCol = layout.qPerCol;
            const rowH = layout.mcq.totalHeight / Math.max(15, qPerCol);

            for (let q = 1; q <= qCount; q++) {
                const colIdx = Math.floor((q - 1) / qPerCol);
                const inColIdx = (q - 1) % qPerCol;
                const baseX = layout.mcq.colBaseX[colIdx] || layout.mcq.colBaseX[0];
                const optStepX = layout.mcq.optStepX;

                // Account for 5-question block spacers
                const blockIdx = Math.floor(inColIdx / 5);
                const cy = layout.mcq.baseY + (inColIdx * rowH) + (blockIdx * 0.014);

                const optScores = [];
                for (let optIdx = 0; optIdx < 4; optIdx++) {
                    const cx = baseX + (optIdx * optStepX);
                    const dark = sampleBubbleDarkness(cx, cy, Math.round(w * 0.010));
                    optScores.push({ opt: modelOpts[optIdx], dark });
                }

                optScores.sort((a, b) => b.dark - a.dark);
                const best = optScores[0];
                const runnerUp = optScores[1];

                if (best.dark > 0.30) {
                    if (runnerUp.dark > 0.28 && (best.dark - runnerUp.dark) < 0.12) {
                        detectedAnswers[q] = { selected: best.opt, ambiguous: true, second: runnerUp.opt };
                    } else {
                        detectedAnswers[q] = { selected: best.opt, ambiguous: false };
                    }
                } else {
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
    if (typeof module !== 'undefined' && module.exports) {
        module.exports = OMR;
    }

})(typeof window !== 'undefined' ? window : this);
