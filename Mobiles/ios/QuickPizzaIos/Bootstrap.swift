import Foundation
import SwiftiePod

/// Global DI container — single instance for the entire app.
let pod = SwiftiePod()

/// Bootstraps the app: initializes OTel, logger, and other services.
/// Called once at app launch from `QuickPizzaIosApp.init()`.
enum Bootstrap {
    static func initialize() {
        // 1. Resolve the in-use URLs before anything else so OTelService and
        //    APIClient see the same snapshot for the rest of the session.
        let runtimeConfig = pod.resolve(runtimeConfigHolderProvider).current

        // 2. OpenTelemetry (reads runtimeConfig via otelConfigProvider)
        _ = pod.resolve(otelServiceProvider)

        // 3. Log startup
        let config = pod.resolve(configServiceProvider)
        let logger = pod.resolve(loggerProvider)
        if runtimeConfig.isOtlpEnabled {
            logger.info("OTel initialized with OTLP endpoint", attributes: [
                "endpoint": runtimeConfig.otlpEndpoint,
                "hasAuthHeader": runtimeConfig.otlpAuthHeader != nil ? "yes" : "no",
            ])
        } else {
            logger.info("OTel initialized in stdout-only mode (no OTLP endpoint configured)")
        }
        logger.info("QuickPizza iOS app started", attributes: [
            "version": config.appVersion,
            "baseURL": runtimeConfig.backendBaseUrl,
        ])
    }
}
