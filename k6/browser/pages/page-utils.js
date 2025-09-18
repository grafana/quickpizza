export class PageUtils {
  constructor(page) {
    this.page = page;
  }

  async addPerformanceMark(markName) {
    await this.page.evaluate(function (markName) {
      window.performance.mark(markName)
    }, markName);
  }

  async measurePerformance(performanceName, markName1, markName2) {
    await this.page.evaluate(function (performanceName, markName1, markName2) {
      window.performance.measure(performanceName, markName1, markName2)
    }, performanceName, markName1, markName2)
  }

  async getPerformanceDuration(performanceName) {
    return await this.page.evaluate(function (performanceName) {
      return JSON.parse(JSON.stringify(window.performance.getEntriesByName(performanceName)))[0].duration
    }, performanceName);
  }
}