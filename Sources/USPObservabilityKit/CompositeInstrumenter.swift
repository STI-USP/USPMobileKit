// CompositeInstrumenter.swift
// USPObservabilityKit
//
// Permite compor múltiplos HTTPRequestInstrumenting em cadeia, aplicando
// cada um em sequência. Nenhum instrumentador precisa conhecer os outros.
//
// Uso típico em um HTTPClient do app:
//
//   private let observability: any HTTPRequestInstrumenting =
//       CompositeInstrumenter([
//           USPContextInstrumenter(),   // USP-* headers
//           myTracingInstrumenter       // traceparent (Iteração 2)
//       ])

import Foundation

/// Aplica múltiplos `HTTPRequestInstrumenting` em sequência, passando a request
/// resultante de cada etapa como entrada para a próxima.
///
/// A ordem de inserção determina a ordem de execução. Todos os headers adicionados
/// por instrumentadores anteriores são preservados pelas etapas seguintes.
///
/// ```swift
/// let composite = CompositeInstrumenter([
///     USPContextInstrumenter(),
///     myTracingInstrumenter
/// ])
///
/// let instrumented = try composite.instrument(request)
/// ```
public struct CompositeInstrumenter: HTTPRequestInstrumenting {

    private let instrumenters: [any HTTPRequestInstrumenting]

    /// Cria um compostor com a lista de instrumentadores fornecida.
    ///
    /// - Parameter instrumenters: Lista de instrumentadores a aplicar em ordem.
    public init(_ instrumenters: [any HTTPRequestInstrumenting]) {
        self.instrumenters = instrumenters
    }

    public func instrument(_ request: URLRequest) throws -> URLRequest {
        try instrumenters.reduce(request) { accumulated, instrumenter in
            try instrumenter.instrument(accumulated)
        }
    }
}
