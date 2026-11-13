import cv2
import numpy as np
import math

SHEET_W = 1200
SHEET_H = 1697

def create_ground_truth_sheet(q_count=30, roll_digits=5):
    img = np.ones((SHEET_H, SHEET_W), dtype=np.uint8) * 250
    marker_size = 24
    corner_pts = [
        (60, 60),
        (SHEET_W - 60, 60),
        (SHEET_W - 60, SHEET_H - 60),
        (60, SHEET_H - 60)
    ]
    for cx, cy in corner_pts:
        cv2.rectangle(img, (cx - marker_size//2, cy - marker_size//2),
                           (cx + marker_size//2, cy + marker_size//2), 0, -1)
    
    cv2.rectangle(img, (100, 100), (SHEET_W - 100, 380), 0, 2)
    model_y = 340
    model_x_start = 250
    model_step_x = 40
    for i, opt in enumerate(['A', 'B', 'C', 'D']):
        bx = model_x_start + i * model_step_x
        cv2.circle(img, (bx, model_y), 11, 0, 2)
    
    grid_top_y = 480
    grid_bot_y = 1550
    grid_h = grid_bot_y - grid_top_y
    
    reg_x = [100, 420, 800, 1100]
    for rx in reg_x:
        for r_idx in range(4):
            ry = int(grid_top_y + r_idx * (grid_h / 3.0))
            cv2.rectangle(img, (rx - 10, ry - 10), (rx + 10, ry + 10), 0, -1)
            
    roll_w = reg_x[1] - reg_x[0]
    roll_col_start = int(reg_x[0] + roll_w * 0.30)
    roll_col_step = int((roll_w * 0.58) / (roll_digits - 1))
    roll_row_start = int(grid_top_y + grid_h * 0.16)
    roll_row_step = int((grid_h * 0.76) / 9.0)
    
    roll_coords = {}
    for c in range(roll_digits):
        cx = roll_col_start + c * roll_col_step
        roll_coords[c] = {}
        for d in range(10):
            cy = roll_row_start + d * roll_row_step
            cv2.circle(img, (cx, cy), 10, 0, 2)
            roll_coords[c][d] = (cx, cy)
            
    q_per_col = 15
    num_blocks = 3
    block_h = grid_h / float(num_blocks)
    unit_h = block_h / 6.4
    opt_offsets = [0.32, 0.49, 0.66, 0.83]
    
    q_coords = {}
    for q in range(1, q_count + 1):
        col_idx = (q - 1) // q_per_col
        in_col = (q - 1) % q_per_col
        block_idx = in_col // 5
        pos_in_block = in_col % 5
        
        x_left = reg_x[col_idx + 1]
        x_right = reg_x[col_idx + 2]
        mcq_w = x_right - x_left
        
        qy = int(grid_top_y + (block_idx * block_h) + (0.9 * unit_h) + (pos_in_block * unit_h))
        q_coords[q] = {}
        for o_idx, o_name in enumerate(['A', 'B', 'C', 'D']):
            qx = int(x_left + mcq_w * opt_offsets[o_idx])
            cv2.circle(img, (qx, qy), 10, 0, 2)
            q_coords[q][o_name] = (qx, qy)
            
    return img, corner_pts, q_coords, roll_coords

def fill_bubble(img, cx, cy, fill_type='pen'):
    r = 7
    if fill_type == 'pen':
        cv2.circle(img, (cx, cy), r, 20, -1)
    elif fill_type == 'pencil_dark':
        cv2.circle(img, (cx, cy), r, 50, -1)
    elif fill_type == 'pencil_light':
        cv2.circle(img, (cx, cy), r, 120, -1)
    elif fill_type == 'erased':
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                if dx*dx + dy*dy <= r*r:
                    img[cy + dy, cx + dx] = np.random.randint(185, 220)
    elif fill_type == 'partial':
        for dy in range(-r, 0):
            for dx in range(-r, r + 1):
                if dx*dx + dy*dy <= r*r:
                    img[cy + dy, cx + dx] = 35

# Computer Vision Preprocessing & Classification Functions
def check_quality(gray):
    """Detects blur, darkness, low-res, and distance."""
    h, w = gray.shape
    if w < 600 or h < 800:
        return False, "LOW_RESOLUTION"
    mean_lum = float(np.mean(gray))
    if mean_lum < 38:
        return False, "TOO_DARK"
    laplacian_var = float(cv2.Laplacian(gray, cv2.CV_64F).var())
    if laplacian_var < 28.0:
        return False, "TOO_BLURRY"
        
    # Distance / Framing check
    dark_mask = gray < min(85, mean_lum * 0.55)
    ys, xs = np.where(dark_mask)
    if len(xs) > 15:
        span_w = (xs.max() - xs.min()) / float(w)
        span_h = (ys.max() - ys.min()) / float(h)
        if span_w < 0.40 or span_h < 0.35:
            return False, "SHEET_TOO_FAR"
            
    return True, "OK"

def rectify_sheet(gray, target_w=SHEET_W, target_h=SHEET_H):
    """Detects 4 corner registration markers and applies perspective homography warp."""
    # Binary inverse to find solid black corner fiducials
    _, thresh = cv2.threshold(gray, 60, 255, cv2.THRESH_BINARY_INV)
    num_labels, labels, stats, centroids = cv2.connectedComponentsWithStats(thresh)
    
    h, w = gray.shape
    corners = []
    for i in range(1, num_labels):
        cw = stats[i, cv2.CC_STAT_WIDTH]
        ch = stats[i, cv2.CC_STAT_HEIGHT]
        area = stats[i, cv2.CC_STAT_AREA]
        aspect = float(cw) / max(1, ch)
        extent = area / float(cw * ch)
        cx, cy = centroids[i]
        # Registration markers: 15-40px, aspect ~1.0, extent > 0.82
        if 0.75 <= aspect <= 1.30 and 14 <= cw <= 45 and 14 <= ch <= 45 and extent > 0.80:
            corners.append((cx, cy))
            
    if len(corners) < 4:
        # Fallback: find corners of largest external quadrilateral
        contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        largest_cnt = max(contours, key=cv2.contourArea) if contours else None
        if largest_cnt is not None and cv2.contourArea(largest_cnt) > (w * h * 0.3):
            peri = cv2.arcLength(largest_cnt, True)
            approx = cv2.approxPolyDP(largest_cnt, 0.02 * peri, True)
            if len(approx) == 4:
                corners = [p[0] for p in approx]
                
    if len(corners) < 4:
        # Return original if corners cannot be parsed
        return gray, False
        
    # Sort 4 corners: TL, TR, BR, BL
    corners = np.array(corners, dtype=np.float32)
    s = corners.sum(axis=1)
    tl = corners[np.argmin(s)]
    br = corners[np.argmax(s)]
    diff = np.diff(corners, axis=1)
    tr = corners[np.argmin(diff)]
    bl = corners[np.argmax(diff)]
    
    src_pts = np.array([tl, tr, br, bl], dtype=np.float32)
    box_w = max(np.hypot(tr[0] - tl[0], tr[1] - tl[1]), np.hypot(br[0] - bl[0], br[1] - bl[1]))
    box_h = max(np.hypot(bl[0] - tl[0], bl[1] - tl[1]), np.hypot(br[0] - tr[0], br[1] - tr[1]))
    aspect = box_w / max(1.0, box_h)
    
    if aspect >= 0.80:
        # OMR Grid Fiducials detected
        dst_pts = np.array([
            [100, 480],
            [1100, 480],
            [1100, 1550],
            [100, 1550]
        ], dtype=np.float32)
    else:
        # Full Page corners detected
        dst_pts = np.array([
            [60, 60],
            [target_w - 60, 60],
            [target_w - 60, target_h - 60],
            [60, target_h - 60]
        ], dtype=np.float32)
    
    M = cv2.getPerspectiveTransform(src_pts, dst_pts)
    warped = cv2.warpPerspective(gray, M, (target_w, target_h), flags=cv2.INTER_LINEAR, borderValue=250)
    return warped, True

def analyze_bubble(gray, cx, cy, r_inner=6):
    """Multi-feature bubble detection: inner core fill, border exclusion, variance, relative contrast."""
    h, w = gray.shape
    if cx < r_inner or cx >= w - r_inner or cy < r_inner or cy >= h - r_inner:
        return 0.0, 0.0, 0.0, 0.0
        
    # Inner core mask (strictly inside bubble, ignoring border)
    y_min, y_max = max(0, cy - r_inner), min(h, cy + r_inner + 1)
    x_min, x_max = max(0, cx - r_inner), min(w, cx + r_inner + 1)
    
    core_patch = gray[y_min:y_max, x_min:x_max]
    
    # Local paper background (annulus gap around bubble: radius 12 to 16)
    annulus_mask = np.zeros((35, 35), dtype=np.uint8)
    cv2.circle(annulus_mask, (17, 17), 16, 255, -1)
    cv2.circle(annulus_mask, (17, 17), 12, 0, -1)
    
    ay_min, ay_max = max(0, cy - 17), min(h, cy + 18)
    ax_min, ax_max = max(0, cx - 17), min(w, cx + 18)
    surround = gray[ay_min:ay_max, ax_min:ax_max]
    
    paper_level = float(np.median(surround)) if surround.size > 0 else 245.0
    
    # Darkness threshold for local pixel fill
    fill_thresh = paper_level * 0.70
    core_pixels = core_patch.flatten()
    filled_count = np.sum(core_pixels < fill_thresh)
    fill_ratio = float(filled_count) / float(len(core_pixels))
    
    mean_darkness = 255.0 - float(np.mean(core_pixels))
    paper_darkness = 255.0 - paper_level
    net_contrast = max(0.0, mean_darkness - paper_darkness)
    
    variance = float(np.var(core_pixels)) # Erased marks have high variance
    
    return fill_ratio, net_contrast, variance, paper_level

def classify_question(gray, option_coords):
    """Classifies a question into SELECTED, EMPTY, MULTIPLE, UNCERTAIN."""
    opts = ['A', 'B', 'C', 'D']
    scores = []
    
    for opt in opts:
        cx, cy = option_coords[opt]
        fill_ratio, net_contrast, variance, paper_level = analyze_bubble(gray, cx, cy)
        
        # Combined confidence metric
        score = (fill_ratio * 0.6) + (min(1.0, net_contrast / 100.0) * 0.4)
        scores.append({
            'opt': opt,
            'fill': fill_ratio,
            'contrast': net_contrast,
            'variance': variance,
            'score': score
        })
        
    scores.sort(key=lambda x: x['score'], reverse=True)
    best = scores[0]
    second = scores[1]
    
    # 1. EMPTY Question
    if best['score'] < 0.22 and best['fill'] < 0.25:
        return {'state': 'EMPTY', 'selected': None, 'confidence': 1.0 - best['score']}
        
    # 2. MULTIPLE answers
    if best['score'] >= 0.40 and second['score'] >= 0.38 and (best['score'] - second['score']) < 0.12:
        return {'state': 'MULTIPLE', 'selected': [best['opt'], second['opt']], 'confidence': second['score']}
        
    # 3. UNCERTAIN (Erasure residue, faint mark, or borderline contrast)
    if (best['score'] >= 0.22 and best['score'] < 0.42) or (best['variance'] > 750 and best['fill'] < 0.45) or ((best['score'] - second['score']) < 0.16 and best['score'] < 0.55):
        return {'state': 'UNCERTAIN', 'selected': best['opt'], 'confidence': best['score']}
        
    # 4. SELECTED (Clear single answer)
    margin = best['score'] - second['score']
    confidence = min(0.99, max(0.80, 0.70 + margin * 0.5))
    return {'state': 'SELECTED', 'selected': best['opt'], 'confidence': round(confidence, 2)}

print("Engine ready for benchmark execution")

def run_accuracy_benchmark():
    np.random.seed(42)
    print("=" * 70)
    print("OMR ACCURACY BENCHMARK & MULTI-CONDITION VERIFICATION SUITE")
    print("=" * 70)
    
    total_bubbles_tested = 0
    correct_bubble_detections = 0
    
    total_questions_tested = 0
    correct_question_classifications = 0
    
    false_positives = 0
    false_negatives = 0
    
    # Ground truth answer key for 30 questions
    answer_key = {
        1: 'A', 2: 'B', 3: 'C', 4: 'D', 5: 'A',
        6: 'B', 7: 'C', 8: 'D', 9: 'A', 10: 'B',
        11: 'C', 12: 'D', 13: 'A', 14: 'B', 15: 'C',
        16: 'D', 17: 'A', 18: 'B', 19: 'C', 20: 'D',
        21: 'A', 22: 'B', 23: 'C', 24: 'D', 25: 'A',
        26: 'B', 27: 'C', 28: 'D', 29: 'A', 30: 'B'
    }
    
    # Test Scenarios
    scenarios = [
        ("Scenario 1: Ideal Flat Scan (Standard Black Pen)", "pen", 0.0, False, False),
        ("Scenario 2: Mobile Phone Lighting Gradient & Shadow", "pen", 0.0, True, False),
        ("Scenario 3: Perspective Tilt (12° Camera Distortion)", "pen", 12.0, False, False),
        ("Scenario 4: Dark Pencil (2B Graphite)", "pencil_dark", 0.0, False, False),
        ("Scenario 5: Light Pencil (Faint Marks)", "pencil_light", 0.0, False, False),
        ("Scenario 6: Complex Mixed (Pen, Pencil, Erasures, Multi-Marks, Blanks)", "mixed", 8.0, True, False)
    ]
    
    scenario_results = []
    
    for sc_name, fill_mode, tilt_deg, add_shadow, add_blur in scenarios:
        img, corners, q_coords, roll_coords = create_ground_truth_sheet(30, 5)
        
        # Build student answers
        ground_truth = {}
        for q in range(1, 31):
            if fill_mode == "mixed":
                if q in [5, 15, 25]: # Blanks
                    ground_truth[q] = {'state': 'EMPTY', 'selected': None}
                elif q in [8, 18]: # Multiple marks
                    fill_bubble(img, q_coords[q]['A'][0], q_coords[q]['A'][1], 'pen')
                    fill_bubble(img, q_coords[q]['B'][0], q_coords[q]['B'][1], 'pen')
                    ground_truth[q] = {'state': 'MULTIPLE', 'selected': ['A', 'B']}
                elif q in [10, 20]: # Erased mark
                    fill_bubble(img, q_coords[q]['C'][0], q_coords[q]['C'][1], 'erased')
                    ground_truth[q] = {'state': 'UNCERTAIN', 'selected': 'C'}
                elif q % 2 == 0:
                    ans = answer_key[q]
                    fill_bubble(img, q_coords[q][ans][0], q_coords[q][ans][1], 'pencil_light')
                    ground_truth[q] = {'state': 'SELECTED', 'selected': ans}
                else:
                    ans = answer_key[q]
                    fill_bubble(img, q_coords[q][ans][0], q_coords[q][ans][1], 'pen')
                    ground_truth[q] = {'state': 'SELECTED', 'selected': ans}
            else:
                ans = answer_key[q]
                fill_bubble(img, q_coords[q][ans][0], q_coords[q][ans][1], fill_mode)
                ground_truth[q] = {'state': 'SELECTED', 'selected': ans}
                
        # Fill Roll No: 4 1 0 9 2
        roll_digits_gt = [4, 1, 0, 9, 2]
        for c, d in enumerate(roll_digits_gt):
            fill_bubble(img, roll_coords[c][d][0], roll_coords[c][d][1], 'pen')
            
        # Apply shadow / lighting gradient if requested
        test_img = img.copy()
        if add_shadow:
            gradient = np.linspace(1.15, 0.72, SHEET_H)[:, np.newaxis]
            test_img = np.clip(test_img * gradient, 0, 255).astype(np.uint8)
            
        # Apply perspective distortion if requested
        if tilt_deg > 0:
            rad = math.radians(tilt_deg)
            shift = int(SHEET_W * math.sin(rad) * 0.4)
            src = np.array([
                [0, 0],
                [SHEET_W, 0],
                [SHEET_W, SHEET_H],
                [0, SHEET_H]
            ], dtype=np.float32)
            dst = np.array([
                [shift, shift // 2],
                [SHEET_W - shift, shift // 2],
                [SHEET_W, SHEET_H],
                [0, SHEET_H]
            ], dtype=np.float32)
            M_skew = cv2.getPerspectiveTransform(src, dst)
            test_img = cv2.warpPerspective(test_img, M_skew, (SHEET_W, SHEET_H), borderValue=250)
            
        # Execute OMR Pipeline
        # 1. Quality Gate
        ok, reason = check_quality(test_img)
        assert ok, f"Quality check failed: {reason}"
        
        # 2. Rectification
        rectified, was_warped = rectify_sheet(test_img, SHEET_W, SHEET_H)
        
        # 3. Question Classification
        sc_q_correct = 0
        sc_bubbles_tested = 30 * 4
        sc_bubbles_correct = 0
        
        for q in range(1, 31):
            gt = ground_truth[q]
            pred = classify_question(rectified, q_coords[q])
            
            # Evaluate question classification
            matched = False
            if gt['state'] == pred['state']:
                if gt['state'] == 'SELECTED' and gt['selected'] == pred['selected']:
                    matched = True
                elif gt['state'] in ['EMPTY', 'UNCERTAIN', 'MULTIPLE']:
                    matched = True
                    
            if matched:
                sc_q_correct += 1
                correct_question_classifications += 1
            else:
                if gt['state'] == 'EMPTY' and pred['state'] == 'SELECTED':
                    false_positives += 1
                elif gt['state'] == 'SELECTED' and pred['state'] == 'EMPTY':
                    false_negatives += 1
                    
            total_questions_tested += 1
            
            # Evaluate individual bubble states (4 per question)
            for opt in ['A', 'B', 'C', 'D']:
                cx, cy = q_coords[q][opt]
                fill_r, net_c, _, _ = analyze_bubble(rectified, cx, cy)
                is_shaded_gt = (gt['state'] == 'SELECTED' and gt['selected'] == opt) or                                (gt['state'] == 'MULTIPLE' and opt in gt['selected'])
                is_shaded_pred = (fill_r >= 0.35 or net_c >= 25.0)
                
                if is_shaded_gt == is_shaded_pred:
                    sc_bubbles_correct += 1
                    correct_bubble_detections += 1
                total_bubbles_tested += 1
                
        # 4. Roll No extraction test
        detected_roll = []
        for c in range(5):
            digit_scores = []
            for d in range(10):
                cx, cy = roll_coords[c][d]
                fr, nc, _, _ = analyze_bubble(rectified, cx, cy)
                digit_scores.append((d, fr * 0.6 + min(1.0, nc / 100.0) * 0.4))
            digit_scores.sort(key=lambda x: x[1], reverse=True)
            if digit_scores[0][1] > 0.30:
                detected_roll.append(digit_scores[0][0])
            else:
                detected_roll.append(-1)
                
        roll_correct = (detected_roll == roll_digits_gt)
        
        q_acc = (sc_q_correct / 30.0) * 100.0
        b_acc = (sc_bubbles_correct / float(sc_bubbles_tested)) * 100.0
        
        scenario_results.append({
            'name': sc_name,
            'q_acc': q_acc,
            'b_acc': b_acc,
            'roll_match': roll_correct
        })
        print(f"{sc_name}:")
        print(f"   -> Question Classification Accuracy: {q_acc:.1f}% ({sc_q_correct}/30)")
        print(f"   -> Per-Bubble Detection Accuracy:     {b_acc:.1f}% ({sc_bubbles_correct}/120)")
        print(f"   -> Student ID (Roll No) Correct:       {roll_correct} ({detected_roll})")
        print()
        
    # Rejection Test: Blurry & Dark Images
    print("Executing Rejection Gates Test:")
    blurry_img = cv2.GaussianBlur(img, (45, 45), 0)
    b_ok, b_reason = check_quality(blurry_img)
    print(f"   -> Blurry Image Rejection: {'PASSED (Rejected: ' + b_reason + ')' if not b_ok else 'FAILED'}")
    
    dark_img = (img * 0.1).astype(np.uint8)
    d_ok, d_reason = check_quality(dark_img)
    print(f"   -> Dark Image Rejection:   {'PASSED (Rejected: ' + d_reason + ')' if not d_ok else 'FAILED'}")
    
    # Far sheet (sheet scaled to 30% centered in 1200x1697)
    far_img = np.ones((SHEET_H, SHEET_W), dtype=np.uint8) * 180
    small_sheet = cv2.resize(img, (int(SHEET_W * 0.35), int(SHEET_H * 0.30)))
    sy, sx = (SHEET_H - small_sheet.shape[0]) // 2, (SHEET_W - small_sheet.shape[1]) // 2
    far_img[sy:sy+small_sheet.shape[0], sx:sx+small_sheet.shape[1]] = small_sheet
    f_ok, f_reason = check_quality(far_img)
    print(f"   -> Too Far Rejection:      {'PASSED (Rejected: ' + f_reason + ')' if not f_ok else 'FAILED'}")
    print()
    
    # Overall summary metrics
    overall_q_acc = (correct_question_classifications / float(total_questions_tested)) * 100.0
    overall_b_acc = (correct_bubble_detections / float(total_bubbles_tested)) * 100.0
    fp_rate = (false_positives / float(total_questions_tested)) * 100.0
    fn_rate = (false_negatives / float(total_questions_tested)) * 100.0
    
    print("=" * 70)
    print("FINAL MEASURED BENCHMARK SUMMARY:")
    print(f"Total Questions Evaluated:          {total_questions_tested}")
    print(f"Total Individual Bubbles Evaluated: {total_bubbles_tested}")
    print(f"Overall Question Accuracy:          {overall_q_acc:.2f}%")
    print(f"Overall Per-Bubble Accuracy:        {overall_b_acc:.2f}%")
    print(f"False Positive Rate:                {fp_rate:.2f}%")
    print(f"False Negative Rate:                {fn_rate:.2f}%")
    print("=" * 70)

if __name__ == '__main__':
    run_accuracy_benchmark()
