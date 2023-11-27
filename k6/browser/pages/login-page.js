export class LoginPage {
  constructor(page) {
    this.page = page
    this.submitButton = page.locator('button[type="submit"]');
    this.logoutButton = page.locator('//*[text()="Logout"]');
  }

  async goto(baseURL) {
    await this.page.goto(`${baseURL}/admin`);
  }

  async login() {
    await this.submitButton.click();
  }

  getLogoutButtonText() {
    return this.logoutButton.textContent();
  }
}