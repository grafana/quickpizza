import Foundation
import OpenTelemetryApi
import SwiftiePod

let tracerProvider = Provider<Tracing> { pod in
    OtelTracer(otelService: pod.resolve(otelServiceProvider))
}

// MARK: - Protocol

/// Capability protocol for distributed tracing following OpenTelemetry semantics.
protocol Tracing {
    /// Starts a new span with the given name.
    /// - Parameters:
    ///   - name: The span name describing the operation.
    ///   - kind: The span kind (client, server, etc.). When `nil`, the SDK defaults to `.internal`.
    ///   - parent: An optional parent span for explicit parent-child linking.
    func startSpan(_ name: String, kind: SpanKind?, parent: Span?) -> Span

    /// Starts a new active span and executes the given operation within its context.
    ///
    /// The span becomes the **active span** for the duration of the closure, meaning any
    /// spans created inside (including auto-instrumented HTTP spans) will automatically
    /// become children. The span is ended and deactivated when the closure returns.
    ///
    /// - Parameters:
    ///   - name: The span name describing the operation.
    ///   - kind: The span kind (client, server, etc.). When `nil`, the SDK defaults to `.internal`.
    ///   - parent: An optional parent span for explicit parent-child linking.
    ///   - operation: The async work to perform while this span is active. Receives the span
    ///     so you can set attributes, add events, etc.
    /// - Returns: The value returned by the operation closure.
    func withActiveSpan<T>(_ name: String, kind: SpanKind?, parent: Span?, _ operation: (Span) async throws -> T) async throws -> T
}

extension Tracing {
    func startSpan(_ name: String, kind: SpanKind? = nil, parent: Span? = nil) -> Span {
        startSpan(name, kind: kind, parent: parent)
    }

    func withActiveSpan<T>(_ name: String, kind: SpanKind? = nil, parent: Span? = nil, _ operation: (Span) async throws -> T) async throws -> T {
        try await withActiveSpan(name, kind: kind, parent: parent, operation)
    }
}

/// Represents a span in a distributed trace.
protocol Span {
    /// The current status of the span.
    var status: SpanStatus { get }
    
    /// Sets a string attribute on the span.
    func setAttribute(key: String, value: String)
    
    /// Sets an integer attribute on the span.
    func setAttribute(key: String, value: Int)
    
    /// Sets a double attribute on the span.
    func setAttribute(key: String, value: Double)
    
    /// Sets a boolean attribute on the span.
    func setAttribute(key: String, value: Bool)
    
    /// Sets the span status to error with an optional description.
    func setError(_ description: String)
    
    /// Adds a timestamped event to the span.
    func addEvent(name: String, attributes: [String: SpanAttributeValue])
    
    /// Records an exception as a span event following OTel semantic conventions,
    /// and sets the span status to error.
    func recordException(_ error: Error)
    
    /// Ends the span, recording its duration.
    func end()
}

extension Span {
    func addEvent(name: String, attributes: [String: SpanAttributeValue] = [:]) {
        addEvent(name: name, attributes: attributes)
    }
}

/// Typed attribute value for span events, mirroring OpenTelemetry AttributeValue
/// without leaking SDK types.
enum SpanAttributeValue {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
}

/// Span status following OpenTelemetry semantics.
enum SpanStatus: Equatable {
    /// Default status — the span completed without any explicitly set status.
    case unset
    /// The span completed with an error.
    case error(String)
}

/// Span kind following OpenTelemetry semantics.
enum SpanKind {
    case client
    case server
    case producer
    case consumer
    case `internal`
}

// MARK: - OtelTracer

/// OpenTelemetry implementation of the Tracing protocol.
final class OtelTracer: Tracing {
    private let tracer: OpenTelemetryApi.Tracer
    
    init(otelService: OTelService) {
        self.tracer = otelService.getTracer()
    }
    
    func startSpan(_ name: String, kind: SpanKind?, parent: Span?) -> Span {
        let builder = tracer.spanBuilder(spanName: name)
        
        if let kind {
            builder.setSpanKind(spanKind: kind.toOtelSpanKind())
        }
        
        if let otelSpan = parent as? OtelSpan {
            builder.setParent(otelSpan.underlyingSpan)
        }
        
        return OtelSpan(span: builder.startSpan())
    }

    func withActiveSpan<T>(_ name: String, kind: SpanKind?, parent: Span?, _ operation: (Span) async throws -> T) async throws -> T {
        let builder = tracer.spanBuilder(spanName: name)
        
        if let kind {
            builder.setSpanKind(spanKind: kind.toOtelSpanKind())
        }
        
        if let otelSpan = parent as? OtelSpan {
            builder.setParent(otelSpan.underlyingSpan)
        }
        
        let underlyingSpan = builder.startSpan()
        let wrappedSpan = OtelSpan(span: underlyingSpan)
        defer { wrappedSpan.end() }
        
        return try await OpenTelemetry.instance.contextProvider.withActiveSpan(underlyingSpan) {
            do {
                return try await operation(wrappedSpan)
            } catch {
                wrappedSpan.recordException(error)
                throw error
            }
        }
    }
}

// MARK: - OtelSpan

/// OpenTelemetry implementation of the Span protocol.
final class OtelSpan: Span {
    fileprivate let underlyingSpan: OpenTelemetryApi.Span
    
    init(span: OpenTelemetryApi.Span) {
        self.underlyingSpan = span
    }
    
    var status: SpanStatus {
        switch underlyingSpan.status {
        case .error(let description):
            return .error(description)
        default:
            return .unset
        }
    }
    
    func setAttribute(key: String, value: String) {
        underlyingSpan.setAttribute(key: key, value: value)
    }
    
    func setAttribute(key: String, value: Int) {
        underlyingSpan.setAttribute(key: key, value: value)
    }
    
    func setAttribute(key: String, value: Double) {
        underlyingSpan.setAttribute(key: key, value: value)
    }
    
    func setAttribute(key: String, value: Bool) {
        underlyingSpan.setAttribute(key: key, value: value)
    }
    
    func setError(_ description: String) {
        underlyingSpan.status = .error(description: description)
    }
    
    func addEvent(name: String, attributes: [String: SpanAttributeValue]) {
        underlyingSpan.addEvent(name: name, attributes: attributes.toOtelAttributes())
    }
    
    func recordException(_ error: Error) {
        underlyingSpan.addEvent(name: SemanticConventions.Exception.exception.rawValue, attributes: [
            SemanticConventions.Exception.type.rawValue: .string(String(describing: type(of: error))),
            SemanticConventions.Exception.message.rawValue: .string(error.localizedDescription),
        ])
        underlyingSpan.status = .error(description: error.localizedDescription)
    }
    
    func end() {
        underlyingSpan.end()
    }
}

// MARK: - Conversions

extension SpanKind {
    func toOtelSpanKind() -> OpenTelemetryApi.SpanKind {
        switch self {
        case .client: return .client
        case .server: return .server
        case .producer: return .producer
        case .consumer: return .consumer
        case .internal: return .internal
        }
    }
}

extension SpanAttributeValue {
    func toOtelAttributeValue() -> OpenTelemetryApi.AttributeValue {
        switch self {
        case .string(let v): return .string(v)
        case .int(let v): return .int(v)
        case .double(let v): return .double(v)
        case .bool(let v): return .bool(v)
        }
    }
}

extension Dictionary where Key == String, Value == SpanAttributeValue {
    func toOtelAttributes() -> [String: OpenTelemetryApi.AttributeValue] {
        mapValues { $0.toOtelAttributeValue() }
    }
}
