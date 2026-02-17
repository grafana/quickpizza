import Foundation
import SwiftiePod

/// Global DI container — single instance for the entire app.
let pod = SwiftiePod()

/// Bootstraps the app: initializes OTel, logger, and other services.
/// Called once at app launch from `QuickPizzaIosApp.init()`.
enum Bootstrap {
    static func initialize() {
        // 1. OpenTelemetry
        let otelConfig = pod.resolve(otelConfigProvider)
        _ = pod.resolve(otelServiceProvider)

        // 2. Log startup
        let config = pod.resolve(configServiceProvider)
        let logger = pod.resolve(loggerProvider)
        if otelConfig.isOtlpEnabled {
            logger.info("OTel initialized with OTLP endpoint", attributes: [
                "endpoint": otelConfig.endpointUrl ?? "",
                "hasAuthHeader": otelConfig.authHeader != nil ? "yes" : "no",
            ])
        } else {
            logger.info("OTel initialized in stdout-only mode (no OTLP endpoint configured)")
        }
        logger.info("QuickPizza iOS app started", attributes: [
            "version": config.appVersion,
            "baseURL": config.baseURL,
        ])
    }
}
