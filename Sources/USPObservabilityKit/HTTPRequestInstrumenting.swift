// HTTPRequestInstrumenting.swift
// USPObservabilityKit
//
// Protocolo central do Mobile API Observability Contract.
//
// Cada implementador é responsável por uma única preocupação:
//   - USPContextInstrumenter  → adiciona headers USP-* e traceparent
//   - TracingInstrumenting    → identifica instrumentadores com W3C Trace Context
//   - CompositeInstrumenter   → compõe múltiplos instrumentadores em cadeia
//
// O HTTPClient do app não precisa conhecer nenhum detalhe de observabilidade:
//
//   let request = try observability.instrument(request)
//   return try await URLSession.shared.data(for: request)

import Foundation

/// Protocolo central de instrumentação de requests HTTP.
///
/// Um `HTTPRequestInstrumenting` recebe uma `URLRequest`, pode adicionar ou modificar
/// headers e retorna a request instrumentada. Headers existentes não devem ser removidos.
///
/// ## Conformidade e Sendability
/// Conformadores devem ser `Sendable` pois instâncias são tipicamente compartilhadas
/// entre threads (ex.: injetadas em um HTTPClient compartilhado).
///
/// ## Composição
/// Use `CompositeInstrumenter` para encadear múltiplos instrumentadores sem
/// acoplamento entre eles.
///
/// ```swift
/// let observability = CompositeInstrumenter([
///     USPContextInstrumenter(configuration: configuration),
///     anotherInstrumenter
/// ])
///
/// let request = try observability.instrument(originalRequest)
/// ```
public protocol HTTPRequestInstrumenting: Sendable {

    /// Recebe uma `URLRequest`, adiciona/modifica headers conforme a responsabilidade
    /// do instrumentador e retorna a request resultante.
    ///
    /// - Parameter request: A request original (não modificada).
    /// - Returns: A request com headers adicionados/modificados.
    /// - Throws: Erros de instrumentação (ex.: contexto de tracing indisponível).
    ///           Para os headers USP-* padrão, este método nunca lança.
    func instrument(_ request: URLRequest) throws -> URLRequest
}
