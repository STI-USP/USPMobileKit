// TracingInstrumenting.swift
// USPObservabilityKit
//
// Ponto de extensão para integração de W3C Trace Context / OpenTelemetry.
//
// ═══════════════════════════════════════════════════════════════
//  Estado atual (Iteração 1)
// ═══════════════════════════════════════════════════════════════
//
//  Este protocolo existe apenas como contrato de extensão.
//  Nenhuma implementação concreta é fornecida nesta iteração.
//
//  A implementação real — geração de traceparent, spanId, traceId
//  via OpenTelemetry — será fornecida pelo target:
//
//      USPObservabilityOpenTelemetry   (Iteração 2)
//
// ═══════════════════════════════════════════════════════════════
//  Separação de responsabilidades
// ═══════════════════════════════════════════════════════════════
//
//  USP-* headers           ←  USPObservabilityKit (este módulo)
//  traceparent / tracestate ←  USPObservabilityOpenTelemetry
//
//  Um app pode usar USPObservabilityKit sem distributed tracing.
//  Um app pode adicionar USPObservabilityOpenTelemetry sem alterar
//  o USPContextInstrumenter nem nenhuma outra classe existente —
//  basta compor via CompositeInstrumenter:
//
//      CompositeInstrumenter([
//          USPContextInstrumenter(),        // USP-* headers
//          OTelTracingInstrumenter(tracer)  // traceparent (Iteração 2)
//      ])
//
// ═══════════════════════════════════════════════════════════════
//  Padrão de implementação esperado (Iteração 2)
// ═══════════════════════════════════════════════════════════════
//
//  O conformador em USPObservabilityOpenTelemetry deverá:
//    1. Receber um Tracer OpenTelemetry como dependência.
//    2. Iniciar um Span para cada request instrumentada.
//    3. Injetar `traceparent` (e opcionalmente `tracestate`) na URLRequest.
//    4. Seguir o padrão W3C Trace Context (RFC: https://www.w3.org/TR/trace-context/)
//
//  O USPObservabilityKit NÃO deve conter algoritmos próprios de geração
//  de trace_id ou span_id.

import Foundation

/// Protocolo de extensão para implementações de W3C Trace Context.
///
/// Conformadores devem injetar os headers `traceparent` e opcionalmente
/// `tracestate` conforme o padrão W3C Trace Context.
///
/// A implementação de referência é `USPObservabilityOpenTelemetry` (Iteração 2).
///
/// ## Headers esperados
///
/// ```
/// traceparent: 00-{32-hex-traceId}-{16-hex-spanId}-{2-hex-flags}
/// tracestate:  (opcional, vendor-specific)
/// ```
///
/// ## Uso
///
/// ```swift
/// // Iteração 2 — não disponível ainda
/// import USPObservabilityOpenTelemetry
///
/// let tracing: any TracingInstrumenting = OTelTracingInstrumenter(tracer: myTracer)
///
/// let observability = CompositeInstrumenter([
///     USPContextInstrumenter(),
///     tracing
/// ])
/// ```
public protocol TracingInstrumenting: HTTPRequestInstrumenting {}
