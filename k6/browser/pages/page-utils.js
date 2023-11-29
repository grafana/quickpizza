export class PageUtils {
  constructor(page) {
    this.page = page;
  }

  addPerformanceMark(markName) {
    this.page.evaluate(function (markName) {
      window.performance.mark(markName)
    }, markName);
  }

  measurePerformance(performanceName, markName1, markName2) {
    this.page.evaluate(function (performanceName, markName1, markName2) {
      window.performance.measure(performanceName, markName1, markName2)
    }, performanceName, markName1, markName2)
  }

  getPerformanceDuration(performanceName) {
    return this.page.evaluate(function (performanceName) {
      return JSON.parse(JSON.stringify(window.performance.getEntriesByName(performanceName)))[0].duration
    }, performanceName);
  }
}