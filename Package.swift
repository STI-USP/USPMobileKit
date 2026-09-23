// Package.swift
// swift-tools-version: 6.1
// USPMobileKit — infraestrutura compartilhada para apps iOS da STI/USP.
//
// Products independentes:
//   • USPAuthKit          — autenticação OAuth 1.0a
//   • USPObservabilityKit — instrumentação de requests (Mobile API Observability Contract)
//
// Cada app importa somente o(s) product(s) de que precisa.
// Não existe dependência entre USPAuthKit e USPObservabilityKit.

import PackageDescription
import Foundation

// Captura as compilation conditions vindas do app
let extraFlags: [SwiftSetting] = {
    guard let raw = ProcessInfo.processInfo
            .environment["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] else { return [] }

    let flags = raw.split(whereSeparator: \.isWhitespace).map(String.init)
    return flags.contains("DEV") ? [.define("DEV")] : []
}()

let package = Package(
  name: "USPMobileKit",
  platforms: [
    .iOS(.v14),
  ],
  products: [
    // ─── Autenticação ──────────────────────────────────────────────────────────
    .library(
      name: "USPAuthKit",
      targets: ["USPAuthKit"]
    ),

    // ─── Observabilidade ───────────────────────────────────────────────────────
    .library(
      name: "USPObservabilityKit",
      targets: ["USPObservabilityKit"]
    ),

    // W3C Trace Context mínimo pertence ao USPObservabilityKit e não usa OTel SDK.
    // Um adapter OpenTelemetry futuro só deve existir quando tracing completo for aprovado.

    // ─── (Iteração 3) USPObservabilityFirebase — Performance + Crashlytics ─────
    // Será adicionado quando a integração Firebase for introduzida.
  ],
  targets: [

    // ── USPAuthKit ─────────────────────────────────────────────────────────────
    // Target Objective-C/C legado. Não possui dependências SPM externas.
    // API pública preservada integralmente (zero breaking changes).
    .target(
      name: "USPAuthKit",
      publicHeadersPath: "include",
      cSettings: [
        .headerSearchPath("Core"),
        .headerSearchPath("UI"),
        .headerSearchPath("Adapters")
      ],
      swiftSettings: extraFlags
    ),
    .testTarget(
      name: "USPAuthKitTests",
      dependencies: ["USPAuthKit"]
    ),

    // ── USPObservabilityKit ────────────────────────────────────────────────────
    // Target Swift puro. Não depende de USPAuthKit nem de dependências externas.
    // Responsabilidade: Mobile API Observability Contract (USP-* + traceparent).
    .target(
      name: "USPObservabilityKit",
      path: "Sources/USPObservabilityKit",
      swiftSettings: [
        .swiftLanguageMode(.v6)
      ]
    ),
    .testTarget(
      name: "USPObservabilityKitTests",
      dependencies: ["USPObservabilityKit"],
      path: "Tests/USPObservabilityKitTests"
    ),
    .testTarget(
      name: "USPMobileKitCompatibilityTests",
      dependencies: ["USPAuthKit", "USPObservabilityKit"],
      path: "Tests/USPMobileKitCompatibilityTests"
    ),

  ]
)
