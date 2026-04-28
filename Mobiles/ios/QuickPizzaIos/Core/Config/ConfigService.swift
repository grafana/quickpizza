import Foundation
import SwiftiePod

let configServiceProvider = Provider { _ in
    ConfigService()
}

let appVersionProvider = Provider<String> { pod in
    pod.resolve(configServiceProvider).appVersion
}

/// Bootstrap configuration loaded from `Config.xcconfig` (via `BuildConfig.generated.swift`).
///
/// Holds the build-time defaults only — runtime overrides (set by the user
/// through Debug → Config) are applied on top by `RuntimeConfigHolder`.
struct ConfigService {
    /// Base URL for the QuickPizza API.
    /// Set `BASE_URL` in Config.xcconfig (auto-generated into BuildConfig at build time).
    /// Defaults to localhost:3333 if not configured.
    var baseURL: String {
        BuildConfig.baseURL ?? "http://localhost:\(port)"
    }

    /// Port for the QuickPizza API. Defaults to 3333.
    /// Set `PORT` in Config.xcconfig (auto-generated into BuildConfig at build time).
    var port: String {
        BuildConfig.port ?? "3333"
    }

    /// OTLP endpoint URL for OpenTelemetry traces and logs.
    /// When empty, telemetry goes to stdout only.
    /// Set `OTLP_ENDPOINT` in Config.xcconfig (auto-generated into BuildConfig at build time).
    var otlpEndpoint: String? {
        guard let endpoint = BuildConfig.otlpEndpoint, !endpoint.isEmpty else {
            return nil
        }
        return endpoint
    }

    /// Numeric OTLP instance ID from your Grafana Cloud OTLP Gateway integration.
    /// Combined with `otlpApiKey` at runtime to build the Authorization header.
    /// Set `OTLP_INSTANCE_ID` in Config.xcconfig.
    var otlpInstanceId: String {
        BuildConfig.otlpInstanceId ?? ""
    }

    /// OTLP API key (Grafana Cloud access policy token, typically `glc_...`).
    /// Combined with `otlpInstanceId` at runtime to build the Authorization header.
    /// Set `OTLP_API_KEY` in Config.xcconfig.
    var otlpApiKey: String {
        BuildConfig.otlpApiKey ?? ""
    }

    /// Service name for OTel resource attributes.
    let serviceName = "quickpizza-ios"

    /// Deployment environment for OTel resource attributes.
    let deploymentEnvironment = "production"

    /// OTLP Authorization header derived from the build-time instance ID and API key.
    /// `nil` when either credential is missing.
    var otlpAuthHeader: String? {
        Self.buildAuthHeader(instanceId: otlpInstanceId, apiKey: otlpApiKey)
    }

    /// App version, read from the bundle.
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    /// Builds `Basic base64("<instanceId>:<apiKey>")`. Returns `nil` when
    /// either credential is missing.
    static func buildAuthHeader(instanceId: String, apiKey: String) -> String? {
        let trimmedId = instanceId.trimmingCharacters(in: .whitespaces)
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespaces)
        guard !trimmedId.isEmpty, !trimmedKey.isEmpty else { return nil }
        let token = Data("\(trimmedId):\(trimmedKey)".utf8).base64EncodedString()
        return "Basic \(token)"
    }
}
