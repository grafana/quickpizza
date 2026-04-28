import Foundation
import SwiftiePod

let runtimeConfigHolderProvider = Provider<RuntimeConfigHolder> { pod in
    RuntimeConfigHolder(
        configService: pod.resolve(configServiceProvider),
        debugSettings: pod.resolve(debugSettingsRepositoryProvider)
    )
}

/// Immutable snapshot of the URLs and credentials the app was bootstrapped with.
///
/// This is intentionally *not* reactive: these are the values `OTelService`
/// initialized with and that `APIClient` is using. Changing a saved override in
/// `DebugSettings` will NOT change these values — the user must restart the app
/// for the override to take effect.
///
/// Why: keeping backend + collector + auth stable per session makes correlated
/// traces/logs/metrics much easier to reason about when demoing.
struct RuntimeConfig {
    let backendBaseUrl: String
    let otlpEndpoint: String
    let otlpInstanceId: String
    let otlpApiKey: String

    /// OTLP Authorization header derived from the resolved instance ID and API key.
    /// `nil` when either credential is missing.
    var otlpAuthHeader: String? {
        ConfigService.buildAuthHeader(instanceId: otlpInstanceId, apiKey: otlpApiKey)
    }

    /// Whether OTLP export is enabled (endpoint is configured).
    var isOtlpEnabled: Bool {
        !otlpEndpoint.isEmpty
    }
}

/// Resolves and holds the `RuntimeConfig` snapshot for the lifetime of the
/// process. Built lazily on first access (which happens during
/// `Bootstrap.initialize()`).
final class RuntimeConfigHolder {
    private let configService: ConfigService
    private let debugSettings: DebugSettingsRepository

    private(set) lazy var current: RuntimeConfig = resolve()

    init(configService: ConfigService, debugSettings: DebugSettingsRepository) {
        self.configService = configService
        self.debugSettings = debugSettings
    }

    private func resolve() -> RuntimeConfig {
        let saved = debugSettings.current
        let instanceId = saved.otlpInstanceIdOverride ?? configService.otlpInstanceId
        let apiKey = saved.otlpApiKeyOverride ?? configService.otlpApiKey
        return RuntimeConfig(
            backendBaseUrl: saved.backendUrlOverride ?? configService.baseURL,
            otlpEndpoint: saved.otlpEndpointOverride ?? (configService.otlpEndpoint ?? ""),
            otlpInstanceId: instanceId,
            otlpApiKey: apiKey
        )
    }
}
