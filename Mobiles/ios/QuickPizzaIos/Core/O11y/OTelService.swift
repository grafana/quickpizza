import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk
import StdoutExporter
import OpenTelemetryProtocolExporterHttp
import URLSessionInstrumentation
import ResourceExtension
import SwiftiePod

let otelServiceProvider = Provider { pod in
    let config = pod.resolve(otelConfigProvider)
    OTelService.instance.initialize(config: config)
    return OTelService.instance
}

/// Initializes and manages OpenTelemetry traces, logs, and URLSession instrumentation.
/// When no OTLP endpoint is configured, telemetry goes to stdout only.
/// Provide the endpoint later via environment variable and telemetry will flow automatically.
final class OTelService {
    fileprivate static let instance = OTelService()

    private var isInitialized = false
    private var otelConfig: OTelConfig?

    private init() {}

    func initialize(config: OTelConfig) {
        guard !isInitialized else { return }
        isInitialized = true
        self.otelConfig = config

        setupTraces(config: config)
        setupLogs(config: config)
        setupURLSessionInstrumentation(config: config)
    }

    // MARK: - Traces

    private func setupTraces(config: OTelConfig) {
        var spanProcessors: [SpanProcessor] = []

        if let endpointUrl = config.endpointUrl {
            // Set auth header as environment variable for OTLP exporter
            var envVarHeaders: [(String, String)]? = nil
            if let authHeader = config.authHeader {
                envVarHeaders = [("Authorization", authHeader)]
            }
            
            // OTLP HTTP exporter for traces
            let otlpTraceExporter = OtlpHttpTraceExporter(
                endpoint: URL(string: "\(endpointUrl)/v1/traces")!,
                envVarHeaders: envVarHeaders
            )
            spanProcessors.append(BatchSpanProcessor(spanExporter: otlpTraceExporter))
        }

        // Always add stdout for development visibility
        #if DEBUG
        spanProcessors.append(SimpleSpanProcessor(spanExporter: StdoutSpanExporter()))
        #endif

        let tracerProviderBuilder = TracerProviderBuilder()
            .with(resource: buildResource(config: config))
        for processor in spanProcessors {
            _ = tracerProviderBuilder.add(spanProcessor: processor)
        }
        let tracerProvider = tracerProviderBuilder.build()
        OpenTelemetry.registerTracerProvider(tracerProvider: tracerProvider)
    }

    // MARK: - Logs

    private func setupLogs(config: OTelConfig) {
        var logProcessors: [LogRecordProcessor] = []

        if let endpointUrl = config.endpointUrl {
            // Set auth header as environment variable for OTLP exporter
            var envVarHeaders: [(String, String)]? = nil
            if let authHeader = config.authHeader {
                envVarHeaders = [("Authorization", authHeader)]
            }
            
            // OTLP HTTP exporter for logs
            let otlpLogExporter = OtlpHttpLogExporter(
                endpoint: URL(string: "\(endpointUrl)/v1/logs")!,
                envVarHeaders: envVarHeaders
            )
            logProcessors.append(BatchLogRecordProcessor(logRecordExporter: otlpLogExporter))
        }

        let loggerProvider = LoggerProviderBuilder()
            .with(processors: logProcessors)
            .with(resource: buildResource(config: config))
            .build()
        OpenTelemetry.registerLoggerProvider(loggerProvider: loggerProvider)
    }

    // MARK: - URLSession Instrumentation

    private func setupURLSessionInstrumentation(config: OTelConfig) {
        let excludedHosts: Set<String> = {
            var hosts = Set<String>()
            if let endpointUrl = config.endpointUrl,
               let host = URL(string: endpointUrl)?.host {
                hosts.insert(host)
            }
            return hosts
        }()

        _ = URLSessionInstrumentation(
            configuration: URLSessionInstrumentationConfiguration(
                shouldInstrument: { request in
                    guard let host = request.url?.host else { return true }
                    return !excludedHosts.contains(host)
                },
                spanCustomization: { _, spanBuilder in
                    spanBuilder.setSpanKind(spanKind: .client)
                }
            )
        )
    }

    // MARK: - Resource

    private func buildResource(config: OTelConfig) -> Resource {
        let defaultResources = DefaultResources().get()
        let customResource = Resource(
            attributes: [
                "service.name": .string(config.serviceName),
                "deployment.environment": .string(config.deploymentEnvironment),
                "service.version": .string(config.appVersion),
                "telemetry.sdk.name": .string("opentelemetry-swift"),
                "telemetry.sdk.language": .string("swift"),
            ]
        )
        return defaultResources.merging(other: customResource)
    }

    // MARK: - Accessors

    func getTracer() -> Tracer {
        let config = otelConfig ?? OTelConfig(configService: ConfigService())
        return OpenTelemetry.instance.tracerProvider.get(
            instrumentationName: config.instrumentationScopeName,
            instrumentationVersion: config.instrumentationScopeVersion
        )
    }

    func getLogger() -> OpenTelemetryApi.Logger {
        let config = otelConfig ?? OTelConfig(configService: ConfigService())
        return OpenTelemetry.instance.loggerProvider.loggerBuilder(
            instrumentationScopeName: config.instrumentationScopeName
        ).build()
    }
}
