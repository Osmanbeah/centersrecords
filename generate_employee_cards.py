import os
import sys
import json
import base64
import io
import zipfile
import subprocess
from PIL import Image
import qrcode

# Paths
WORKSPACE = os.path.dirname(os.path.abspath(__file__))
OUTPUT_DIR = os.path.join(WORKSPACE, "All_29_Employee_ID_Cards")
LEGACY_DIR = os.path.join(WORKSPACE, "employee_id_cards")
os.makedirs(OUTPUT_DIR, exist_ok=True)
os.makedirs(LEGACY_DIR, exist_ok=True)

# Find Browser
CHROME_PATH = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
EDGE_PATH = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
BROWSER_PATH = CHROME_PATH if os.path.exists(CHROME_PATH) else EDGE_PATH

# Load portrait logo base64
LOGO_PATH = os.path.join(WORKSPACE, "kelany_new_portrait.png")
if not os.path.exists(LOGO_PATH):
    LOGO_PATH = os.path.join(WORKSPACE, "kelany_logo.png")

with open(LOGO_PATH, "rb") as f:
    LOGO_BASE64 = "data:image/png;base64," + base64.b64encode(f.read()).decode("utf-8")


def generate_qr_base64(name: str) -> str:
    """Generate high-contrast QR code for the assistant name with high error correction."""
    qr = qrcode.QRCode(
        version=1,
        error_correction=qrcode.constants.ERROR_CORRECT_H,
        box_size=10,
        border=0,
    )
    qr.add_data(name)
    qr.make(fit=True)
    img = qr.make_image(fill_color="#08182b", back_color="white")
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode("utf-8")


def build_card_html(name: str, role: str = "ACADEMIC ASSISTANT", id_code: str = "AST-2026-001") -> str:
    """Build standalone, self-contained HTML for the new vertical employee ID card."""
    qr_b64 = generate_qr_base64(name)

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>{name} - Employee ID Badge</title>
  <script src="https://cdn.tailwindcss.com?plugins=forms,container-queries"></script>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@500;600;700;800&display=swap" rel="stylesheet">
  <script>
    tailwind.config = {{
      theme: {{
        extend: {{
          fontFamily: {{
            sans: ['"Plus Jakarta Sans"', 'sans-serif'],
          }},
          colors: {{
            navy: {{ 900: '#061325', 950: '#040d1a' }},
            badgeTeal: '#00ccb3',
          }},
          boxShadow: {{
            'card': '0 25px 50px -12px rgba(15, 23, 42, 0.18), 0 0 0 1px rgba(226, 232, 240, 0.8)',
          }}
        }}
      }}
    }}
  </script>
  <style>
    .id-card {{
      width: 320px;
      height: 480px;
      aspect-ratio: 2 / 3;
    }}
    .lanyard-slot {{
      width: 52px;
      height: 10px;
      border-radius: 9999px;
      background-color: #030811;
      border: 1.5px solid rgba(255, 255, 255, 0.12);
      box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.8), 0 1px 1px rgba(255, 255, 255, 0.08);
    }}
  </style>
</head>
<body class="bg-[#f0f4f8] min-h-screen flex items-center justify-center p-0 m-0 font-sans antialiased text-slate-800">
  <article class="id-card bg-white rounded-[32px] overflow-hidden shadow-card flex flex-col relative select-none border border-slate-200/80">
    <!-- Header (37% height) -->
    <header class="bg-gradient-to-b from-[#060e1d] via-[#09152b] to-[#0c1b35] h-[37%] pt-3 px-4 flex flex-col items-center justify-between pb-3.5 relative border-b border-[#0a182b] overflow-hidden">
      <!-- Coordinate Grid Overlay -->
      <div class="absolute inset-0 opacity-15 pointer-events-none">
        <svg class="w-full h-full" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <pattern height="20" id="math-grid-1" patternUnits="userSpaceOnUse" width="20">
              <path d="M 20 0 L 0 0 0 20" fill="none" stroke="#38bdf8" stroke-dasharray="2 2" stroke-width="0.6"></path>
              <circle cx="0" cy="0" fill="#38bdf8" r="0.8"></circle>
            </pattern>
          </defs>
          <rect fill="url(#math-grid-1)" height="100%" width="100%"></rect>
          <path d="M -10 60 Q 40 30, 90 60 T 190 60 T 290 60 T 360 60" fill="none" opacity="0.4" stroke="#38bdf8" stroke-width="0.8"></path>
          <path d="M -10 75 Q 50 100, 110 75 T 230 75 T 350 75" fill="none" opacity="0.3" stroke="#2dd4bf" stroke-width="0.7"></path>
        </svg>
      </div>
      <!-- Lanyard Punch Slot -->
      <div aria-hidden="true" class="lanyard-slot mt-0.5 relative z-10"></div>
      <!-- Instructor Emblem -->
      <div class="w-[96px] h-[96px] rounded-2xl bg-[#0a182b] border border-cyan-400/40 p-0.5 flex items-center justify-center relative z-10 shadow-sm overflow-hidden">
        <img alt="Portrait" class="w-full h-full object-contain" src="{LOGO_BASE64}">
      </div>
      <!-- Header Titles -->
      <div class="text-center relative z-10">
        <h1 class="text-white font-extrabold text-[14px] tracking-[0.15em] uppercase leading-tight font-sans drop-shadow-sm">MR. MOHAMED KELANY</h1>
      </div>
    </header>
    <!-- Body Info (63% height) -->
    <section class="h-[63%] bg-white px-5 pt-4 pb-4 flex flex-col items-center justify-between relative">
      <div class="flex flex-col items-center text-center w-full">
        <h2 class="text-slate-900 font-extrabold text-[21px] tracking-tight leading-tight mb-1.5 font-sans">{name}</h2>
        <div class="inline-flex items-center justify-center gap-1.5 px-3.5 py-1 rounded-full border border-teal-500/30 bg-teal-50 text-teal-700 shadow-xs leading-none">
          <span class="w-1.5 h-1.5 rounded-full bg-teal-500 shrink-0 shadow-[0_0_4px_#14b8a6]"></span>
          <span class="text-[9.5px] font-extrabold tracking-[0.12em] uppercase leading-none block">{role}</span>
        </div>
        <div class="flex items-center w-full max-w-[210px] mt-2 px-1 text-[8.5px] font-semibold text-slate-400 border-t border-b border-slate-100 py-0.5 tracking-wider uppercase justify-center">
          <span>ID: <strong class="text-slate-700 font-bold">{id_code}</strong></span>
        </div>
      </div>
      <div class="flex flex-col items-center w-full">
        <div class="relative w-[154px] h-[154px] rounded-2xl border border-slate-200/90 bg-slate-50/40 p-2.5 shadow-sm flex items-center justify-center">
          <span class="absolute top-1 left-1 w-2.5 h-2.5 border-t-2 border-l-2 border-cyan-500/80 rounded-tl-sm pointer-events-none"></span>
          <span class="absolute top-1 right-1 w-2.5 h-2.5 border-t-2 border-r-2 border-cyan-500/80 rounded-tr-sm pointer-events-none"></span>
          <span class="absolute bottom-1 left-1 w-2.5 h-2.5 border-b-2 border-l-2 border-cyan-500/80 rounded-bl-sm pointer-events-none"></span>
          <span class="absolute bottom-1 right-1 w-2.5 h-2.5 border-b-2 border-r-2 border-cyan-500/80 rounded-br-sm pointer-events-none"></span>
          <div class="w-full h-full bg-white rounded-xl p-2 border border-slate-100 flex items-center justify-center relative">
            <img src="{qr_b64}" class="w-full h-full object-contain" alt="QR Code">
            <div class="absolute w-5 h-5 rounded-full bg-white border border-slate-200 shadow-sm flex items-center justify-center p-0.5 pointer-events-none">
              <span class="w-2.5 h-2.5 rounded-full bg-[#0a182b] flex items-center justify-center text-[6px] text-cyan-300 font-bold">M</span>
            </div>
          </div>
        </div>
        <div class="flex items-center gap-1.5 mt-2 text-slate-400 font-extrabold text-[8.5px] tracking-[0.18em] uppercase">
          <svg class="w-3 h-3 text-cyan-600" fill="currentColor" viewBox="0 0 24 24">
            <path d="M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4zm-2 16l-4-4 1.41-1.41L10 14.17l6.59-6.59L18 9l-8 8z"></path>
          </svg>
          <span>SCAN TO VERIFY CREDENTIALS</span>
        </div>
      </div>
    </section>
  </article>
</body>
</html>
"""


def capture_card_photo(html_file: str, output_image: str) -> bool:
    """Capture high-res card photo with Chrome/Edge headless and crop to the badge cleanly."""
    if not os.path.exists(BROWSER_PATH):
        print(f"Error: Browser not found at {BROWSER_PATH}")
        return False

    temp_raw = output_image.replace(".png", "_raw.png")
    file_url = "file:///" + os.path.abspath(html_file).replace("\\", "/")

    cmd = [
        BROWSER_PATH,
        "--headless=new",
        "--disable-gpu",
        "--hide-scrollbars",
        "--force-device-scale-factor=2",
        "--window-size=440,620",
        f"--screenshot={temp_raw}",
        file_url
    ]

    try:
        subprocess.run(cmd, check=True, capture_output=True, timeout=20)
        if os.path.exists(temp_raw):
            im = Image.open(temp_raw)
            w, h = im.size
            crop_w = int(360 * 2)
            crop_h = int(520 * 2)
            left = max(0, (w - crop_w) // 2)
            top = max(0, (h - crop_h) // 2)
            right = min(w, left + crop_w)
            bottom = min(h, top + crop_h)

            cropped = im.crop((left, top, right, bottom))
            cropped.save(output_image, "PNG", optimize=True)
            try:
                os.remove(temp_raw)
            except:
                pass
            return True
    except Exception as e:
        print(f"Error capturing screenshot for {output_image}: {e}")
        return False
    return False


def main():
    assistants_file = os.path.join(WORKSPACE, "assistants_list.json")
    with open(assistants_file, "r", encoding="utf-8") as f:
        assistants = json.load(f)

    print(f"Loaded {len(assistants)} assistants from assistants_list.json.")
    print(f"Browser path: {BROWSER_PATH}")
    print(f"Output directory: {OUTPUT_DIR}")

    generated_photos = []

    for i, a in enumerate(assistants, 1):
        name = a["name"].strip()
        role = "SENIOR ASSISTANT" if name == "Ahmed Osman" else "ACADEMIC ASSISTANT"
        if name == "Ahmed Osman":
            id_code = "AST-2026-094"
        elif name == "Omar Gamal":
            id_code = "AST-2026-095"
        else:
            id_code = f"AST-2026-{str(i).zfill(3)}"

        safe_name = "".join(c for c in name if c.isalnum() or c in (" ", "_", "-")).strip().replace(" ", "_")
        html_file = os.path.join(OUTPUT_DIR, f"{safe_name}_card.html")
        png_file = os.path.join(OUTPUT_DIR, f"{safe_name}_id_card.png")

        print(f"[{i:2d}/{len(assistants)}] Generating: {name} ({role}) -> {id_code}...")

        card_html = build_card_html(name=name, role=role, id_code=id_code)
        with open(html_file, "w", encoding="utf-8") as f:
            f.write(card_html)

        success = capture_card_photo(html_file, png_file)
        if success:
            kb = os.path.getsize(png_file) / 1024
            print(f"       -> OK: {os.path.basename(png_file)} ({kb:.1f} KB)")
            generated_photos.append(png_file)
            # Also copy to legacy employee_id_cards if desired
            legacy_png = os.path.join(LEGACY_DIR, f"{safe_name}_id_card.png")
            try:
                with open(png_file, "rb") as rf, open(legacy_png, "wb") as wf:
                    wf.write(rf.read())
            except:
                pass
        else:
            print(f"       -> FAILED to capture photo for {name}")

    # Build ZIP archive of all 29 employee ID cards
    zip_path = os.path.join(WORKSPACE, "All_29_Employee_ID_Cards.zip")
    print(f"\nPackaging {len(generated_photos)} cards into {zip_path}...")
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
        for photo in generated_photos:
            arcname = os.path.basename(photo)
            zf.write(photo, arcname=arcname)
    print(f"Zip created successfully: {os.path.getsize(zip_path) / (1024*1024):.2f} MB")
    print("All 29 employee ID cards generated with the new design!")


if __name__ == "__main__":
    main()
