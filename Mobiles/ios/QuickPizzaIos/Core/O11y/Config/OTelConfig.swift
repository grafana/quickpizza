import Foundation
import SwiftiePod

let otelConfigProvider = Provider { pod in
    OTelConfig(configService: pod.resolve(configServiceProvider))
}

/// Configuration values for OpenTelemetry instrumentation.
struct OTelConfig {
    let endpointUrl: String?
    let authHeader: String?
    let serviceName: String
    let deploymentEnvironment: String
    let appVersion: String

    let instrumentationScopeName = "quickpizza-ios"
    let instrumentationScopeVersion = "1.0.0"

    init(configService: ConfigService) {
        self.endpointUrl = configService.otlpEndpoint
        self.authHeader = configService.otlpAuthHeader
        self.serviceName = configService.serviceName
        self.deploymentEnvironment = configService.deploymentEnvironment
        self.appVersion = configService.appVersion
    }

    /// Whether OTLP export is enabled (endpoint is configured).
    var isOtlpEnabled: Bool {
        endpointUrl != nil
    }
}
