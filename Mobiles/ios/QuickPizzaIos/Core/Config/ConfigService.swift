import Foundation
import SwiftiePod

let configServiceProvider = Provider { _ in
    ConfigService()
}

let appVersionProvider = Provider<String> { pod in
    pod.resolve(configServiceProvider).appVersion
}

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

    /// OTLP authorization header (e.g. "Basic <base64>").
    /// Required when using Grafana Cloud OTLP gateway.
    /// Set `OTLP_AUTH_HEADER` in Config.xcconfig (auto-generated into BuildConfig at build time).
    var otlpAuthHeader: String? {
        guard let header = BuildConfig.otlpAuthHeader, !header.isEmpty else {
            return nil
        }
        return header
    }

    /// Service name for OTel resource attributes.
    let serviceName = "quickpizza-ios"

    /// Deployment environment for OTel resource attributes.
    let deploymentEnvironment = "production"

    /// App version, read from the bundle.
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
}
