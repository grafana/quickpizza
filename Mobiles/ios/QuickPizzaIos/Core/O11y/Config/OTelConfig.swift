import Foundation
import SwiftiePod

let otelConfigProvider = Provider { pod in
    OTelConfig(
        configService: pod.resolve(configServiceProvider),
        runtimeConfig: pod.resolve(runtimeConfigHolderProvider).current
    )
}

/// Configuration values for OpenTelemetry instrumentation.
///
/// URL/credential fields are sourced from `RuntimeConfig` (the per-session
/// snapshot, which respects user overrides from Debug → Config). Resource
/// attributes (service name, version, environment) come from `ConfigService`.
struct OTelConfig {
    let endpointUrl: String?
    let authHeader: String?
    let serviceName: String
    let deploymentEnvironment: String
    let appVersion: String

    static let defaultScopeName = "quickpizza-ios"
    static let defaultScopeVersion = "1.0.0"

    let instrumentationScopeName = OTelConfig.defaultScopeName
    let instrumentationScopeVersion = OTelConfig.defaultScopeVersion

    init(configService: ConfigService, runtimeConfig: RuntimeConfig) {
        self.endpointUrl = runtimeConfig.isOtlpEnabled ? runtimeConfig.otlpEndpoint : nil
        self.authHeader = runtimeConfig.otlpAuthHeader
        self.serviceName = configService.serviceName
        self.deploymentEnvironment = configService.deploymentEnvironment
        self.appVersion = configService.appVersion
    }

    /// Whether OTLP export is enabled (endpoint is configured).
    var isOtlpEnabled: Bool {
        endpointUrl != nil
    }
}
