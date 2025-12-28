
import asyncio
from playwright.async_api import async_playwright

async def debug_landing():
    async with async_playwright() as p:
        browser = await p.chromium.launch()
        page = await browser.new_page()
        try:
            await page.goto("http://localhost:8080")
            await page.screenshot(path="verification/debug_landing.png")
            print("Screenshot saved to verification/debug_landing.png")
            content = await page.content()
            print("Page content length:", len(content))
        except Exception as e:
            print(f"Error: {e}")
        await browser.close()

if __name__ == "__main__":
    asyncio.run(debug_landing())
