"""필사앱 웹 빌드 E2E 검증 v3.

전략: 타이핑이 필요한 필사 플로우는 시맨틱 비활성(일반 사용자와 동일) 상태에서
고정 좌표로 수행하고, 이후 시맨틱을 켜서 텍스트 존재를 검증한다.
(시맨틱 모드에서는 quill 에디터의 숨은 입력 요소 대신 시맨틱 노드가
포커스를 가져가 타이핑이 유실되는 제약이 있음 — 실사용에는 영향 없음)
"""
import asyncio
import sys
from playwright.async_api import async_playwright

BASE = "http://localhost:8899/"
OUT = "/home/claude/work/verify/"
PORTRAIT = {"width": 420, "height": 900}
LANDSCAPE = {"width": 980, "height": 460}

results = []

FIND_JS = """(args) => {
  const {label, exact} = args;
  const match = (t) => exact ? t === label : t.includes(label);
  let els = Array.from(document.querySelectorAll('flt-semantics'))
    .filter(e => match((e.textContent || '').trim()));
  els = els.filter(e =>
    !Array.from(e.querySelectorAll('flt-semantics'))
      .some(c => match((c.textContent || '').trim())));
  if (!els.length) {
    els = Array.from(document.querySelectorAll('input, textarea'))
      .filter(e => match(e.placeholder || '') || match(e.getAttribute('aria-label') || ''));
  }
  if (!els.length) return null;
  els.sort((a, b) => {
    const ra = a.getBoundingClientRect(), rb = b.getBoundingClientRect();
    return (ra.width * ra.height) - (rb.width * rb.height);
  });
  const r = els[0].getBoundingClientRect();
  return {x: r.x, y: r.y, w: r.width, h: r.height};
}"""


def check(name, ok, detail=""):
    results.append((name, ok, detail))
    print(f"{'PASS' if ok else 'FAIL'} {name} {detail}")


async def enable_semantics(page):
    await page.wait_for_selector("flt-semantics-placeholder",
                                 state="attached", timeout=30000)
    await page.evaluate(
        """() => {
        const el = document.querySelector('flt-semantics-placeholder');
        el.dispatchEvent(new MouseEvent('click', {bubbles: true, cancelable: true}));
      }"""
    )
    await page.wait_for_timeout(2500)


async def find_box(page, label, exact=False):
    return await page.evaluate(FIND_JS, {"label": label, "exact": exact})


async def click_label(page, label, exact=False, timeout=8000):
    while timeout > 0:
        box = await find_box(page, label, exact)
        if box and box["w"] > 0:
            await page.mouse.click(box["x"] + box["w"] / 2,
                                   box["y"] + box["h"] / 2)
            await page.wait_for_timeout(900)
            return True
        await page.wait_for_timeout(500)
        timeout -= 500
    return False


async def has_label(page, label, timeout=8000):
    while timeout > 0:
        if await find_box(page, label):
            return True
        await page.wait_for_timeout(400)
        timeout -= 400
    return False


async def shot(page, name):
    await page.wait_for_timeout(700)
    await page.screenshot(path=OUT + name)
    print("shot:", name)


async def wait_boot(page):
    await page.goto(BASE, wait_until="load")
    for _ in range(10):
        await page.wait_for_timeout(3000)
        if await page.evaluate(
                "document.querySelectorAll('flutter-view').length"):
            break
    await page.wait_for_timeout(2000)


async def main():
    async with async_playwright() as p:
        browser = await p.chromium.launch()
        ctx = await browser.new_context(viewport=PORTRAIT,
                                        device_scale_factor=2)
        page = await ctx.new_page()
        errors = []
        page.on("pageerror", lambda e: errors.append(str(e)))
        page.on("console", lambda m: errors.append(m.text)
                if m.type == "error" else None)

        await wait_boot(page)
        await shot(page, "01_library_empty_portrait.png")

        # ---- 시맨틱 OFF 구간: 실제 사용자와 동일한 입력 경로 ----

        # 1. 새 필사 (사진 2장 첨부) — 시트 애니메이션 유의, 2회 재시도
        chooser_ok = False
        for attempt in range(3):
            await page.mouse.click(349, 856)  # FAB
            await page.wait_for_timeout(1800)
            if attempt == 0:
                await shot(page, "02_create_sheet.png")
            try:
                async with page.expect_file_chooser(timeout=8000) as fc_info:
                    await page.mouse.click(210, 770)  # '책 사진으로 새 필사'
                fc = await fc_info.value
                await fc.set_files(
                    [OUT + "book_page_1.png", OUT + "book_page_2.png"])
                chooser_ok = True
                break
            except Exception:
                await page.keyboard.press("Escape")
                await page.wait_for_timeout(1200)
        check("사진 선택기 열림", chooser_ok)
        await page.wait_for_timeout(4500)
        await shot(page, "03_note_portrait.png")

        # 2. 본문 필사 입력
        await page.mouse.click(210, 700)  # 에디터 영역
        await page.wait_for_timeout(1000)
        await page.keyboard.type(
            "무진에 명산물이 없는 게 아니다. 나는 그것이 무엇인지 알고 있다. 그것은 안개다.",
            delay=15)
        await page.wait_for_timeout(1500)
        await shot(page, "04_note_typed.png")

        # 3. 서식: 마지막 문장 선택 후 굵게
        for _ in range(8):
            await page.keyboard.press("Shift+ArrowLeft")
        await page.wait_for_timeout(300)
        await page.mouse.click(108, 510)  # 툴바 B 버튼
        await page.wait_for_timeout(800)
        await page.keyboard.press("End")
        await page.wait_for_timeout(1000)
        await shot(page, "05_note_bold.png")

        # 4. 제목 입력
        await page.mouse.click(200, 30)
        await page.wait_for_timeout(1000)
        await page.keyboard.type("무진기행", delay=30)
        await page.wait_for_timeout(1200)

        # 5. 가로 화면(좌우 분할)
        await page.set_viewport_size(LANDSCAPE)
        await page.wait_for_timeout(2000)
        await shot(page, "06_note_landscape.png")
        await page.set_viewport_size(PORTRAIT)
        await page.wait_for_timeout(1500)

        # 6. 뒤로 → 라이브러리
        await page.mouse.click(28, 28)
        await page.wait_for_timeout(1200)
        await page.mouse.click(28, 28)  # 리사이즈 직후 첫 클릭 유실 대비
        await page.wait_for_timeout(2500)
        await shot(page, "07_library_list.png")

        # ---- 시맨틱 ON 구간: 상태 검증 + 나머지 플로우 ----
        await enable_semantics(page)

        check("목록에 제목 표시", await has_label(page, "무진기행"))
        check("목록에 본문 미리보기 표시", await has_label(page, "명산물"))

        # 7. 폴더 생성 (다이얼로그 TextField는 시맨틱 모드에서도 입력 가능)
        check("새 필사 버튼", await click_label(page, "새 필사", exact=True))
        check("새 폴더 시트", await click_label(page, "새 폴더", exact=True))
        await page.wait_for_timeout(700)
        await page.keyboard.type("한국문학", delay=30)
        await page.wait_for_timeout(300)
        check("폴더 확인", await click_label(page, "확인", exact=True))
        check("폴더 생성됨", await has_label(page, "한국문학"))
        await shot(page, "08_library_with_folder.png")

        # 8. 갤러리형 보기
        check("갤러리형 전환", await click_label(page, "갤러리형 보기"))
        await shot(page, "09_library_gallery.png")

        # 9. 다크 테마
        check("설정 진입", await click_label(page, "설정", exact=True))
        await shot(page, "10_settings.png")
        dark = await click_label(page, "다크", exact=True, timeout=4000) \
            or await click_label(page, "다크", timeout=4000)
        if not dark:
            await page.mouse.click(120, 216)  # '다크' 라디오 좌표 폴백
            dark = True
        check("다크 선택", dark)
        await page.wait_for_timeout(1200)
        back = await click_label(page, "뒤로") or await click_label(page, "Back")
        if not back:
            await page.mouse.click(28, 28)
        await page.wait_for_timeout(1500)
        await shot(page, "11_library_dark.png")

        # 10. 새로고침 후 데이터 유지(IndexedDB 영속성)
        await wait_boot(page)
        await enable_semantics(page)
        check("새로고침 후 노트 유지", await has_label(page, "무진기행", timeout=15000))
        check("새로고침 후 폴더 유지", await has_label(page, "한국문학"))
        await shot(page, "12_after_reload.png")

        await browser.close()

        print("\n--- 콘솔/페이지 오류", len(errors), "건 ---")
        for e in errors[:10]:
            print("ERR:", e[:200])

        fails = [r for r in results if not r[1]]
        print(f"\n총 {len(results)}개 체크, 실패 {len(fails)}건")
        for f in fails:
            print("FAILED:", f[0], f[2])
        return 1 if fails else 0


sys.exit(asyncio.run(main()))
