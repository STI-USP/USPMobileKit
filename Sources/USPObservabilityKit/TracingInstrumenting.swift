// TracingInstrumenting.swift
// USPObservabilityKit
//
// Ponto de extensão para instrumentação com W3C Trace Context.
//
// ═══════════════════════════════════════════════════════════════
//  Estado atual (Iteração 2)
// ═══════════════════════════════════════════════════════════════
//
//  USPContextInstrumenter implementa propagação mínima de traceparent
//  sem depender do OpenTelemetry SDK.
//
// ═══════════════════════════════════════════════════════════════
//  Separação de responsabilidades
// ═══════════════════════════════════════════════════════════════
//
//  Não há spans, exporter, tracestate, baggage ou telemetria interna.

import Foundation

/// Marker protocol para instrumentadores que propagam W3C Trace Context.
///
/// Nesta iteração, `USPContextInstrumenter` fornece a implementação concreta sem
/// OpenTelemetry SDK e injeta apenas `traceparent`.
///
/// ## Headers esperados
///
/// ```
/// traceparent: 00-{32-hex-traceId}-{16-hex-parentId}-{2-hex-flags}
/// ```
public protocol TracingInstrumenting: HTTPRequestInstrumenting {}
