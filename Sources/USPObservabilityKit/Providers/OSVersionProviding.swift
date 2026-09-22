// OSVersionProviding.swift
// USPObservabilityKit
//
// Fornece a versão do sistema operacional para o header USP-OS-Version.
// Usa ProcessInfo (thread-safe, disponível desde iOS 8) em vez de UIDevice
// (que é @MainActor e exigiria execução na main thread).

import Foundation

// MARK: - Protocol

/// Fornece a versão do sistema operacional iOS para os headers USP-*.
public protocol OSVersionProviding: Sendable {

    /// Versão do sistema operacional.
    /// Exemplo: `"17.5.1"`
    var osVersion: String { get }
}

// MARK: - Default Implementation

/// Lê a versão do SO via `ProcessInfo.processInfo.operatingSystemVersion`,
/// que é thread-safe e não requer main thread.
///
/// O valor é capturado na inicialização e imutável após a criação da instância.
public struct DefaultOSVersionProvider: OSVersionProviding {

    public let osVersion: String

    public init() {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        if v.patchVersion == 0 {
            osVersion = "\(v.majorVersion).\(v.minorVersion)"
        } else {
            osVersion = "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
        }
    }
}
