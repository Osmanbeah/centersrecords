import os
import sys
import json
import base64
import io
import subprocess
import urllib.request
from PIL import Image
import qrcode

# Paths
WORKSPACE = os.path.dirname(os.path.abspath(__file__))
OUTPUT_DIR = os.path.join(WORKSPACE, "employee_id_cards")
os.makedirs(OUTPUT_DIR, exist_ok=True)

# Find browser
CHROME_PATH = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
EDGE_PATH = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
BROWSER_PATH = CHROME_PATH if os.path.exists(CHROME_PATH) else EDGE_PATH

# Load teacher logo (fallback to online if local file missing)
LOGO_PATH = os.path.join(WORKSPACE, "kelany_logo.png")
if not os.path.exists(LOGO_PATH):
    fallback_url = "https://lh3.googleusercontent.com/aida-public/AB6AXuDkqxElV86sCe0LBid5gJE7sguNEq5TTOJLLuhoOI9BWFwYq2kF-C7JALor7FaSq2NR-SOZn8crmXxJE9weKmtmpTerHvRTG27S21bXaMI-hcoM0teU6i1CyrQUSzxRfCGa9gJoSvsKgepH5TAaIV2WRMZN7rkiRd3bOILQMDai2-PR85NjqEjmVL250XwIJPMPCYDcShr73-sexPFbgr50fIRikg1E0tJZUkqpFhXQfhj4V0QdyGTqkaujF4j3wIgLQg"
    try:
        urllib.request.urlretrieve(fallback_url, LOGO_PATH)
    except Exception as e:
        print(f"Warning: could not download logo: {e}")

LOGO_BASE64 = ""
if os.path.exists(LOGO_PATH):
    with open(LOGO_PATH, "rb") as f:
        LOGO_BASE64 = "data:image/png;base64," + base64.b64encode(f.read()).decode("utf-8")


def generate_qr_base64(name: str) -> str:
    """Generate high-contrast QR code for the assistant name."""
    qr = qrcode.QRCode(
        version=1,
        error_correction=qrcode.constants.ERROR_CORRECT_M,
        box_size=12,
        border=1,
    )
    qr.add_data(name)
    qr.make(fit=True)
    img = qr.make_image(fill_color="#0F1E36", back_color="white")
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode("utf-8")


def build_card_html(name: str, role: str = "Assistant", teacher: str = "MR. MOHAMED KELANY", subject: str = "mathematics") -> str:
    """Build standalone, self-contained HTML for a single vertical card."""
    qr_b64 = generate_qr_base64(name)
    
    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>ID Card - {name}</title>
  <script src="https://cdn.tailwindcss.com"></script>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=JetBrains+Mono:wght@500;700&display=swap" rel="stylesheet">
  <script>
    tailwind.config = {{
      theme: {{
        extend: {{
          fontFamily: {{
            sans: ['"Plus Jakarta Sans"', 'sans-serif'],
            mono: ['"JetBrains Mono"', 'monospace'],
          }},
          colors: {{
            brand: {{
              navy: '#0F1E36',
              deep: '#091322',
              teal: '#0D9488',
              tealLight: '#14B8A6',
              accent: '#06B6D4',
              surface: '#F8FAFC'
            }}
          }},
          boxShadow: {{
            'card-elevated': '0 20px 40px -15px rgba(15, 30, 54, 0.22), 0 8px 16px -6px rgba(15, 30, 54, 0.12), inset 0 1px 0 rgba(255, 255, 255, 0.9)',
            'slot': 'inset 0 2px 4px rgba(0,0,0,0.4), 0 1px 1px rgba(255,255,255,0.8)'
          }}
        }}
      }}
    }}
  </script>
  <style>
    * {{
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }}
    body {{
      background: #F1F5F9;
      font-family: 'Plus Jakarta Sans', sans-serif;
      display: flex;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      padding: 24px;
    }}
    .id-card {{
      width: 320px;
      height: 507px;
      position: relative;
    }}
  </style>
</head>
<body>
  <div id="badge-wrapper" class="p-3">
    <div class="id-card bg-white rounded-[24px] shadow-card-elevated border border-slate-200/80 overflow-hidden flex flex-col justify-between select-none">
      
      <!-- Top Lanyard Slot -->
      <div class="relative w-full pt-3.5 pb-1 flex justify-center bg-brand-navy">
        <div class="w-12 h-2.5 rounded-full bg-slate-900 border border-slate-700/80 shadow-slot relative flex items-center justify-center">
          <span class="w-8 h-[1px] bg-slate-800/80"></span>
        </div>
      </div>

      <!-- Header Section: Teacher & Subject -->
      <div class="bg-brand-navy px-5 pb-5 pt-1.5 text-center relative overflow-hidden flex flex-col items-center justify-center">
        <div class="absolute -right-6 -bottom-6 w-20 h-20 bg-teal-500/10 rounded-full blur-xl pointer-events-none"></div>
        <div class="w-16 h-16 rounded-2xl bg-gradient-to-tr from-brand-navy to-slate-900 border-2 border-teal-500/30 p-2 shadow-md flex items-center justify-center mb-2 overflow-hidden">
          <img src="{LOGO_BASE64}" alt="Logo" class="w-full h-full object-contain filter drop-shadow">
        </div>
        <span class="text-sm font-bold tracking-wider text-white uppercase font-sans">{teacher}</span>
        <p class="text-[10px] uppercase font-semibold tracking-widest text-teal-300/80 mt-0.5">{subject}</p>
      </div>

      <!-- Middle & Bottom Section: Assistant Name + Role + QR -->
      <div class="flex-1 flex flex-col items-center justify-around px-4 py-3 bg-gradient-to-b from-slate-50/60 to-white">
        <div class="text-center mt-1">
          <h2 class="text-xl font-extrabold text-brand-navy text-center tracking-tight leading-tight mb-1">{name}</h2>
          <div class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-teal-50 border border-teal-200/80 text-teal-700 shadow-sm">
            <span class="w-1.5 h-1.5 rounded-full bg-teal-500"></span>
            <span class="text-[10px] font-bold uppercase tracking-wider">{role}</span>
          </div>
        </div>

        <!-- Real QR Code -->
        <div class="flex flex-col items-center py-1">
          <div class="p-2.5 bg-white rounded-xl border border-slate-200 shadow-sm">
            <img src="{qr_b64}" class="w-32 h-32 object-contain" alt="QR Code for {name}">
          </div>
          <span class="text-[9px] font-semibold text-slate-400 uppercase tracking-widest mt-1.5">Scan to verify</span>
        </div>
      </div>

    </div>
  </div>
</body>
</html>
"""
    return html


def capture_card_photo(html_file: str, output_image: str) -> bool:
    """Use Chrome/Edge headless to capture high-res card photo and crop to the badge."""
    if not os.path.exists(BROWSER_PATH):
        print(f"Error: Browser not found at {BROWSER_PATH}")
        return False

    temp_raw = output_image.replace(".png", "_raw.png")
    abs_html = os.path.abspath(html_file).replace("\\", "/")
    file_url = f"file:///{abs_html}"

    cmd = [
        BROWSER_PATH,
        "--headless=new",
        "--disable-gpu",
        "--hide-scrollbars",
        "--force-device-scale-factor=2",
        "--window-size=500,750",
        f"--screenshot={temp_raw}",
        file_url
    ]

    try:
        subprocess.run(cmd, check=True, capture_output=True, timeout=15)
        if os.path.exists(temp_raw):
            # Crop to badge area cleanly
            im = Image.open(temp_raw)
            # Find bounding box or crop centered
            # Window size 500x750 at 2x scale = 1000x1500
            w, h = im.size
            # Card is ~344x531 px at 1x, at 2x it is ~688x1062
            # Center crop
            crop_w = int(380 * 2)
            crop_h = int(580 * 2)
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


def generate_for_assistants(assistants: list):
    """Generate HTML and photos for each assistant."""
    results = []
    print(f"Starting card generation for {len(assistants)} assistant(s)...")

    for i, item in enumerate(assistants, 1):
        if isinstance(item, str):
            name = item.strip()
            role = "Assistant"
        elif isinstance(item, dict):
            name = item.get("name", "").strip()
            role = item.get("role", "Assistant").strip()
        else:
            continue

        if not name:
            continue

        safe_name = "".join(c for c in name if c.isalnum() or c in (" ", "_", "-")).strip().replace(" ", "_")
        html_path = os.path.join(OUTPUT_DIR, f"{safe_name}_card.html")
        png_path = os.path.join(OUTPUT_DIR, f"{safe_name}_id_card.png")

        print(f"[{i}/{len(assistants)}] Generating card for '{name}' ({role})...")
        
        # 1. Write HTML
        card_html = build_card_html(name=name, role=role)
        with open(html_path, "w", encoding="utf-8") as f:
            f.write(card_html)

        # 2. Capture Photo
        success = capture_card_photo(html_path, png_path)
        if success:
            file_size_kb = os.path.getsize(png_path) / 1024
            print(f"    -> Saved photo: {png_path} ({file_size_kb:.1f} KB)")
            results.append({
                "name": name,
                "role": role,
                "photo": png_path,
                "html": html_path
            })
        else:
            print(f"    -> Failed to render photo for '{name}'")

    print("\nGeneration completed successfully!")
    print(f"All photos and HTML cards saved to: {OUTPUT_DIR}")
    return results


def fetch_supabase_assistants() -> list:
    """Fetch all unique assistant names from Supabase schedules."""
    url = "https://mwposurgahrcdexfvywa.supabase.co/rest/v1/schedule?select=assistants"
    headers = {
        "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im13cG9zdXJnYWhyY2RleGZ2eXdhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE2NDE2NDAsImV4cCI6MjEwNzIxNzY0MH0.fxr7qxygr5Fl8urhcFWC1oYYqAxtYiObf5kNGnInPfk",
        "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im13cG9zdXJnYWhyY2RleGZ2eXdhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE2NDE2NDAsImV4cCI6MjEwNzIxNzY0MH0.fxr7qxygr5Fl8urhcFWC1oYYqAxtYiObf5kNGnInPfk"
    }
    try:
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req) as response:
            schedules = json.loads(response.read().decode())
            names = set()
            for s in schedules:
                for a in s.get("assistants", []):
                    if isinstance(a, str) and a.strip():
                        names.add(a.strip())
                    elif isinstance(a, dict) and a.get("name"):
                        names.add(a["name"].strip())
            return sorted(list(names))
    except Exception as e:
        print(f"Error fetching from Supabase: {e}")
        return []


if __name__ == "__main__":
    names = []
    
    if len(sys.argv) > 1:
        if sys.argv[1] == "--supabase":
            print("Fetching assistants from Supabase...")
            names = fetch_supabase_assistants()
            if not names:
                print("No assistants found in Supabase schedules. Defaulting to 'Ahmed Osman'.")
                names = ["Ahmed Osman"]
        elif sys.argv[1] == "--file" and len(sys.argv) > 2:
            file_path = sys.argv[2]
            if os.path.exists(file_path):
                with open(file_path, "r", encoding="utf-8") as f:
                    names = [line.strip() for line in f if line.strip()]
            else:
                print(f"File not found: {file_path}")
                sys.exit(1)
        else:
            names = [arg for arg in sys.argv[1:] if not arg.startswith("--")]
    
    if not names:
        names = ["Ahmed Osman"]

    generate_for_assistants(names)

