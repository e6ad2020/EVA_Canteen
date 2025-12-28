from playwright.sync_api import sync_playwright
import time

def verify_analytics_page():
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()

        # Navigate to the app
        page.goto("http://localhost:8080")

        # Wait for the app to load
        page.wait_for_selector("#screen-1.active")
        print("Loaded login screen")

        # Go to Admin Login
        page.click("#goto-admin-login-button")
        page.wait_for_selector("#screen-6.active")
        print("Loaded admin login screen")

        # Login as Admin
        page.fill("#admin-email", "admin@canteen.app")
        page.fill("#admin-password", "admin123")
        page.click("#admin-login-submit")

        # Wait for Order Management Screen (Screen 5)
        page.wait_for_selector("#screen-5.active")
        print("Loaded order management screen")

        # Click on Analytics Button
        page.click("#goto-analytics-button")

        # Wait for Analytics Screen (Screen 11)
        page.wait_for_selector("#screen-11.active")
        print("Loaded analytics screen")

        # Wait for data to populate (simple wait as we don't have a specific loading indicator for data)
        time.sleep(2)

        # Take a screenshot
        screenshot_path = "verification/analytics_page.png"
        page.screenshot(path=screenshot_path)
        print(f"Screenshot saved to {screenshot_path}")

        browser.close()

if __name__ == "__main__":
    verify_analytics_page()
