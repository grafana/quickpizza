import Foundation
import SwiftUI
import SwiftiePod

let debugViewModelProvider = Provider(scope: AlwaysCreateNewScope()) { pod in
    DebugViewModel(logger: pod.resolve(loggerProvider))
}

@Observable
class DebugViewModel {
    private let logger: Logging

    var lastActionMessage: String?

    init(logger: Logging) {
        self.logger = logger
    }

    func sendExceptionEvent() {
        let error = DebugTestError.simulatedException
        logger.exception(
            "Debug tab sent custom logger.exception event",
            error: error,
            attributes: [
                "debug.action": "logger.exception",
                "debug.source": "debug_tab",
            ]
        )
        lastActionMessage = "Sent custom exception log"
    }

    func triggerCrash() -> Never {
        logger.error(
            "Debug tab is about to trigger a fatalError crash",
            error: nil,
            attributes: [
                "debug.action": "crash",
                "debug.source": "debug_tab",
            ]
        )
        fatalError("Debug crash triggered from Debug tab")
    }
}

enum DebugTestError: LocalizedError {
    case simulatedException

    var errorDescription: String? {
        "Simulated exception from Debug tab"
    }
}
