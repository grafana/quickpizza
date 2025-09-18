export class LoginPage {
  constructor(page) {
    this.page = page
    this.submitButton = page.getByRole('button', { name: "Sign in" });
    this.logoutButton = page.getByRole('button', { name: "Logout" });
  }

  async goto(baseURL) {
    await this.page.goto(`${baseURL}/admin`, { waitUntil: "networkidle" });
  }

  async login() {
    await this.submitButton.click();
  }

  getLogoutButtonText() {
    return this.logoutButton.textContent();
  }
}