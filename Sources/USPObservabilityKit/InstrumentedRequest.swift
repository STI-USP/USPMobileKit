import Foundation

/// Resultado da instrumentação, incluindo o contexto disponível para correlação.
public struct InstrumentedRequest: Sendable {
    public let request: URLRequest
    public let traceContext: TraceContext?

    public init(request: URLRequest, traceContext: TraceContext?) {
        self.request = request
        self.traceContext = traceContext
    }
}
