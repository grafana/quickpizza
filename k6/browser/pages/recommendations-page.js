export class RecommendationsPage {
  constructor(page) {
    this.page = page
    this.headingTextContent = page.locator("h1");
    this.getPizzaRecommendationsButton = page.locator('//button[. = "Pizza, Please!"]');
    this.pizzaRecommendations = page.locator("div#recommendations");
  }

  async goto(baseURL) {
    await this.page.goto(baseURL);
  }

  async getPizzaRecommendation() {
    await this.getPizzaRecommendationsButton.click();
    this.page.waitForTimeout(500);
    this.page.screenshot({ path: "screenshot.png" });
  }

  getHeadingTextContent() {
    return this.headingTextContent.textContent();
  }

  getPizzaRecommendationsContent() {
    return this.pizzaRecommendations.textContent();
  }
}