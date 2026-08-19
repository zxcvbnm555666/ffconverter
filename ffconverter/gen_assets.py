"""生成视频转换软件所需的水墨风格素材：背景图 + 图标。
输出到 assets/images/ 目录。
"""
import math
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "assets", "images")
os.makedirs(OUT, exist_ok=True)

W, H = 1600, 1000


def lerp_color(c1, c2, t):
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))


# ---------- 背景：宣纸米色渐变 ----------
paper_top = (240, 236, 228)
paper_bottom = (216, 211, 200)
img = Image.new("RGB", (W, H))
pix = img.load()
for y in range(H):
    t = y / (H - 1)
    col = lerp_color(paper_top, paper_bottom, t)
    for x in range(W):
        pix[x, y] = col

# 添加宣纸纹理（细微噪点）
rng = np.random.default_rng(42)
noise = rng.normal(0, 6, (H, W, 1)).astype(np.int16)
arr = np.array(img).astype(np.int16)
arr = np.clip(arr + noise, 0, 255).astype(np.uint8)
img = Image.fromarray(arr)
draw = ImageDraw.Draw(img, "RGBA")


# ---------- 远山（多层半透明） ----------
def draw_mountain(base_y, amp, color, alpha):
    pts = [(0, H)]
    n = 14
    for i in range(n + 1):
        x = int(i / n * W)
        # 用正弦叠加形成山形
        y = base_y + amp * math.sin(i * 0.9 + 0.3) + amp * 0.4 * math.sin(i * 2.3)
        pts.append((x, int(y)))
    pts.append((W, H))
    draw.polygon(pts, fill=color + (alpha,))


draw_mountain(560, 70, (154, 149, 138), 70)
draw_mountain(640, 60, (122, 117, 106), 90)
draw_mountain(740, 50, (90, 85, 74), 120)

# ---------- 云雾（柔和椭圆，模糊） ----------
cloud_layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
cd = ImageDraw.Draw(cloud_layer)
for (cx, cy, rx, ry, a) in [
    (300, 520, 260, 26, 90),
    (900, 500, 340, 22, 80),
    (1400, 540, 280, 28, 70),
    (600, 600, 220, 18, 60),
]:
    cd.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=(255, 255, 255, a))
cloud_layer = cloud_layer.filter(ImageFilter.GaussianBlur(18))
img = Image.alpha_composite(img.convert("RGBA"), cloud_layer)

# ---------- 墨点 / 飞白 ----------
draw = ImageDraw.Draw(img, "RGBA")
for (cx, cy, r, a) in [
    (200, 160, 4, 60), (1360, 150, 3, 60), (1200, 280, 4, 50),
    (380, 220, 2, 50), (1500, 360, 3, 45), (120, 700, 3, 40),
]:
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(58, 53, 42, a))

# 书法笔触（红色印章风格）
draw.rectangle([140, 140, 178, 184], fill=(217, 56, 50, 50))

img = img.filter(ImageFilter.GaussianBlur(0.4))
img.convert("RGB").save(os.path.join(OUT, "bg_ink.png"), "PNG")
print("saved bg_ink.png", img.size)

# ---------- 暗色磨砂玻璃卡片用的内嵌预览底（深灰） ----------
card = Image.new("RGB", (400, 240), (15, 15, 17))
cpix = card.load()
for y in range(240):
    for x in range(400):
        v = 15 + int(20 * math.exp(-((x - 200) ** 2 + (y - 120) ** 2) / (2 * 120 * 80)))
        cpix[x, y] = (v, v, int(v * 0.92))
card.save(os.path.join(OUT, "preview_bg.png"), "PNG")
print("saved preview_bg.png")

# ---------- 程序图标：红底白字卷轴/转换箭头 ----------
icon = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
idraw = ImageDraw.Draw(icon)
# 圆角红底
idraw.rounded_rectangle([8, 8, 248, 248], radius=48, fill=(217, 56, 50, 255))
# 白色转换双箭头（循环）
idraw.line([80, 128, 176, 128], fill=(255, 255, 255, 255), width=14)
idraw.polygon([(176, 128), (152, 112), (152, 144)], fill=(255, 255, 255, 255))
idraw.line([176, 160, 80, 160], fill=(255, 255, 255, 255), width=14)
idraw.polygon([(80, 160), (104, 144), (104, 176)], fill=(255, 255, 255, 255))
icon.save(os.path.join(OUT, "app_icon.png"), "PNG")
print("saved app_icon.png")
