import Foundation
import OpenTelemetryApi
import OSLog
import SwiftiePod

let loggerProvider = Provider<Logging> { pod in
    let subsystem = Bundle.main.bundleIdentifier ?? "com.grafana.QuickPizzaIos"
    return CompositeLogger(loggers: [
        ConsoleLogger(subsystem: subsystem),
        OtelLogger(otelLogger: pod.resolve(otelServiceProvider).getLogger()),
    ])
}

// MARK: - Protocol

/// Capability protocol for structured logging.
protocol Logging {
    func debug(_ message: String, attributes: [String: String])
    func info(_ message: String, attributes: [String: String])
    func warning(_ message: String, attributes: [String: String])
    func error(_ message: String, error: Error?, attributes: [String: String])
}

extension Logging {
    func debug(_ message: String, attributes: [String: String] = [:]) {
        debug(message, attributes: attributes)
    }
    func info(_ message: String, attributes: [String: String] = [:]) {
        info(message, attributes: attributes)
    }
    func warning(_ message: String, attributes: [String: String] = [:]) {
        warning(message, attributes: attributes)
    }
    func error(_ message: String, error: Error? = nil, attributes: [String: String] = [:]) {
        self.error(message, error: error, attributes: attributes)
    }
}

// MARK: - CompositeLogger

/// Fans out log calls to a list of loggers.
final class CompositeLogger: Logging {
    private let loggers: [Logging]

    init(loggers: [Logging]) {
        self.loggers = loggers
    }

    func debug(_ message: String, attributes: [String: String]) {
        loggers.forEach { $0.debug(message, attributes: attributes) }
    }

    func info(_ message: String, attributes: [String: String]) {
        loggers.forEach { $0.info(message, attributes: attributes) }
    }

    func warning(_ message: String, attributes: [String: String]) {
        loggers.forEach { $0.warning(message, attributes: attributes) }
    }

    func error(_ message: String, error: Error?, attributes: [String: String]) {
        loggers.forEach { $0.error(message, error: error, attributes: attributes) }
    }
}

// MARK: - ConsoleLogger

/// Logs to the Xcode console via OSLog.
final class ConsoleLogger: Logging {
    private let osLogger: os.Logger

    init(subsystem: String, category: String = "app") {
        self.osLogger = os.Logger(subsystem: subsystem, category: category)
    }

    func debug(_ message: String, attributes: [String: String]) {
        osLogger.debug("\(message)")
    }

    func info(_ message: String, attributes: [String: String]) {
        osLogger.info("\(message)")
    }

    func warning(_ message: String, attributes: [String: String]) {
        osLogger.warning("\(message)")
    }

    func error(_ message: String, error: Error?, attributes: [String: String]) {
        let fullMessage = error != nil ? "\(message): \(error!.localizedDescription)" : message
        osLogger.error("\(fullMessage)")
    }
}

// MARK: - OtelLogger

/// Logs to OpenTelemetry with structured attributes.
final class OtelLogger: Logging {
    private let otelLogger: OpenTelemetryApi.Logger

    init(otelLogger: OpenTelemetryApi.Logger) {
        self.otelLogger = otelLogger
    }

    func debug(_ message: String, attributes: [String: String]) {
        emitLog(message, severity: .debug, attributes: attributes)
    }

    func info(_ message: String, attributes: [String: String]) {
        emitLog(message, severity: .info, attributes: attributes)
    }

    func warning(_ message: String, attributes: [String: String]) {
        emitLog(message, severity: .warn, attributes: attributes)
    }

    func error(_ message: String, error: Error?, attributes: [String: String]) {
        var attrs = attributes
        if let error {
            attrs["error.type"] = String(describing: type(of: error))
            attrs["error.message"] = error.localizedDescription
        }
        let fullMessage = error != nil ? "\(message): \(error!.localizedDescription)" : message
        emitLog(fullMessage, severity: .error, attributes: attrs)
    }

    private func emitLog(_ message: String, severity: Severity, attributes: [String: String]) {
        var otelAttributes = attributes.reduce(
            into: [String: OpenTelemetryApi.AttributeValue]()
        ) { result, pair in
            result[pair.key] = .string(pair.value)
        }
        otelAttributes["level"] = .string("\(severity)")

        otelLogger
            .logRecordBuilder()
            .setBody(.string(message))
            .setTimestamp(Date())
            .setAttributes(otelAttributes)
            .setSeverity(severity)
            .emit()
    }
}
