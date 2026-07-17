"""테스트용 책 페이지 이미지 2장 생성."""
from PIL import Image, ImageDraw

TEXT1 = (
    "무진에 명산물이 없는 게 아니다. 나는 그것이\n"
    "무엇인지 알고 있다. 그것은 안개다. 아침에\n"
    "잠자리에서 일어나서 밖으로 나오면, 밤사이에\n"
    "진주해 온 적군들처럼 안개가 무진을 빙 둘러싸고\n"
    "있는 것이었다. 무진을 둘러싸고 있던 산들도\n"
    "안개에 의하여 보이지 않는 먼 곳으로 유배당해\n"
    "버리고 없었다."
)
TEXT2 = (
    "안개는 마치 이승에 한이 있어서 매일 밤\n"
    "찾아오는 여귀가 뿜어 내놓은 입김과 같았다.\n"
    "해가 떠오르고, 바람이 바다 쪽에서 방향을\n"
    "바꾸어 불어오기 전에는 사람들의 힘으로써는\n"
    "그것을 헤쳐 버릴 수가 없었다."
)

for i, text in enumerate([TEXT1, TEXT2], start=1):
    img = Image.new("RGB", (800, 1100), "#f5f0e6")
    d = ImageDraw.Draw(img)
    # 책 페이지 느낌: 여백 + 본문 + 페이지 번호
    d.rectangle([40, 40, 760, 1060], outline="#d8d0c0", width=2)
    try:
        from PIL import ImageFont
        font = ImageFont.truetype(
            "/usr/share/fonts/opentype/noto/NotoSerifCJK-Regular.ttc", 30)
    except Exception:
        font = None
    d.multiline_text((90, 140), text, fill="#3a352c", spacing=22, font=font)
    d.text((390, 1000), str(140 + i), fill="#8a8272", font=font)
    img.save(f"/home/claude/work/verify/book_page_{i}.png")
print("ok")
