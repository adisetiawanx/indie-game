"""Asset generator untuk Slow Leaf.

Generate ilustrasi storybook via Cloudflare Workers AI (Flux schnell),
lalu post-process (resize, darken overlay agar teks UI tetap terbaca,
kompress WebP) menjadi aset final di assets/.
Usage: python scripts/gen_assets.py [nama-aset ...]  (tanpa argumen = semua)
"""
import base64
import json
import os
import sys

import urllib.request

from PIL import Image, ImageDraw, ImageEnhance

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "assets")
RAW = os.path.join(ROOT, "assets_raw")
os.makedirs(ASSETS, exist_ok=True)
os.makedirs(RAW, exist_ok=True)

ACCOUNT_ID = "5f06438a4bdf166d16aae0723049f461"
MODEL = "@cf/black-forest-labs/flux-1-schnell"
# Prompt style lock: semua aset wajib pakai sufix ini agar satu gaya visual.
STYLE = (
    "soft storybook illustration, children's book watercolor style, "
    "warm muted earthy palette, gentle cozy atmosphere, soft brush strokes, "
    "no text, no people"
)

ASSET_SPECS = {
    # background garden: kebun teh terasering, tanpa gedung dominan
    "bg_garden": (
        "terraced tea plantation on gentle hills behind a small countryside "
        "cottage, rows of low green tea bushes, morning mist, wooden fence, "
        "top-down wide view with clear empty lower area for game interface"
    ),
    # background shop: interior kedai teh hangat
    "bg_shop": (
        "interior of a small cozy tea house, wooden counter with teapots and "
        "cups, shelves with jars, warm lantern light through a round window, "
        "wide view with clear empty lower area for game interface"
    ),
    # background processing: ruang kerja pengolahan daun
    "bg_processing": (
        "rustic workshop for processing tea leaves, bamboo trays of withering "
        "leaves, a small brick drying stove, hanging herbs, warm daylight from "
        "a window, wide view with clear empty lower area for game interface"
    ),
    # header banner tipis untuk atas dashboard (alternatif bg full)
    "banner": (
        "panoramic view of a quiet tea valley at golden hour, tiny tea house "
        "with smoke from chimney among terraced fields, wide banner "
        "composition, sky in upper half"
    ),
}


def load_token() -> str:
    env_path = r"C:\Users\Adi\Desktop\ruvicode\.env"
    with open(env_path, "r", encoding="utf-8") as f:
        for line in f:
            if line.startswith("CF_API_TOKEN="):
                return line.split("=", 1)[1].strip().strip('"').strip()
    raise SystemExit("CF_API_TOKEN tidak ditemukan di ruvicode/.env")


def generate(prompt: str, token: str) -> bytes:
    url = (
        f"https://api.cloudflare.com/client/v4/accounts/{ACCOUNT_ID}"
        f"/ai/run/{MODEL}"
    )
    body = json.dumps({"prompt": prompt}).encode()
    req = urllib.request.Request(
        url, data=body, headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
    )
    with urllib.request.urlopen(req, timeout=120) as resp:
        data = json.loads(resp.read())
    if not data.get("success"):
        raise RuntimeError(json.dumps(data.get("errors", []))[:300])
    return base64.b64decode(data["result"]["image"])


def postprocess(png: bytes, name: str, darken: float, quality: int = 80) -> str:
    import io
    img = Image.open(io.BytesIO(png)).convert("RGB")
    img = img.resize((960, 600), Image.LANCZOS)
    # darken overlay supaya teks UI putih tetap terbaca di atasnya
    overlay = Image.new("RGB", img.size, (15, 15, 14))
    img = Image.blend(img, overlay, darken)
    img = ImageEnhance.Color(img).enhance(0.85)
    out = os.path.join(ASSETS, f"{name}.webp")
    img.save(out, "WEBP", quality=quality, method=4)
    return out


def main() -> None:
    token = load_token()
    wanted = sys.argv[1:] or list(ASSET_SPECS.keys())
    for name in wanted:
        if name not in ASSET_SPECS:
            print(f"SKIP {name}: tidak ada di spesifikasi")
            continue
        prompt = f"{ASSET_SPECS[name]}, {STYLE}"
        print(f"Generating {name} ...")
        png = generate(prompt, token)
        raw_path = os.path.join(RAW, f"{name}.png")
        with open(raw_path, "wb") as f:
            f.write(png)
        out = postprocess(png, name, darken=0.45)
        size_kb = os.path.getsize(out) // 1024
        print(f"  OK -> {out} ({size_kb} KB)")


if __name__ == "__main__":
    main()
