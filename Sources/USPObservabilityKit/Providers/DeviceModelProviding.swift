// DeviceModelProviding.swift
// USPObservabilityKit
//
// Fornece o identificador técnico do modelo do dispositivo para o header
// USP-Device-Model. Ex.: "iPhone14,2", "iPad13,4".
//
// Fontes de dados:
//   • Dispositivo real: sysctlbyname("hw.machine") → identificador Apple
//   • Simulador:        SIMULATOR_MODEL_IDENTIFIER da env do processo
//
// Privacidade:
//   ✗ Não usa IDFA
//   ✗ Não usa IDFV
//   ✗ Não usa serial number
//   ✓ Identifica a classe de hardware, não o dispositivo individual

import Foundation

#if canImport(Darwin)
import Darwin
#endif

// MARK: - Protocol

/// Fornece o identificador técnico do modelo do dispositivo para os headers USP-*.
public protocol DeviceModelProviding: Sendable {

    /// Identificador técnico do modelo.
    /// - Em dispositivos reais: `"iPhone14,2"`, `"iPad13,4"`, etc.
    /// - No simulador: identifica o modelo simulado.
    var deviceModel: String { get }
}

// MARK: - Default Implementation

/// Usa `sysctlbyname("hw.machine")` em dispositivos reais e
/// `SIMULATOR_MODEL_IDENTIFIER` no simulador.
///
/// O valor é capturado na inicialização e imutável após a criação da instância.
public struct DefaultDeviceModelProvider: DeviceModelProviding {

    public let deviceModel: String

    public init() {
        deviceModel = Self.resolveModel()
    }

    private static func resolveModel() -> String {
        #if targetEnvironment(simulator)
        return ProcessInfo.processInfo
            .environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "iOS Simulator"
        #else
        return sysctlModel()
        #endif
    }

    private static func sysctlModel() -> String {
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        guard size > 0 else { return "unknown" }
        var buffer = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &buffer, &size, nil, 0)
        // Truncate at null terminator and decode as UTF-8.
        let bytes = buffer.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) }
        let model = String(decoding: bytes, as: UTF8.self)
        return model.isEmpty ? "unknown" : model
    }
}
