import Foundation

@objc(QuickPizzaCrash)
class QuickPizzaCrash: NSObject {
  @objc
  static func requiresMainQueueSetup() -> Bool {
    false
  }

  @objc(crash:)
  func crash(_ variant: NSString) {
    if variant == "nullPointer" {
      let value: String? = nil
      _ = value!
      return
    }

    fatalError("QuickPizza RN intentional native crash")
  }
}
