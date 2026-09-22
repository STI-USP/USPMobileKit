// AppInfoProviding.swift
// USPObservabilityKit
//
// Fornece metadados estáticos do aplicativo para instrumentação de requests.
// Valores derivados do Info.plist, sem acesso a dados do usuário.

import Foundation

// MARK: - Protocol

/// Fornece informações de identificação do aplicativo para os headers USP-*.
///
/// Permite injetar implementações alternativas em testes unitários sem
/// depender do Info.plist real.
public protocol AppInfoProviding: Sendable {

    /// Plataforma do aplicativo. Sempre `"ios"` em implementações iOS.
    var platform: String { get }

    /// Versão de marketing do aplicativo (`CFBundleShortVersionString`).
    /// Exemplo: `"3.2.1"`
    var version: String { get }

    /// Número de build do aplicativo (`CFBundleVersion`).
    /// Exemplo: `"472"`
    var build: String { get }
}

// MARK: - Default Implementation

/// Implementação padrão que lê `CFBundleShortVersionString` e `CFBundleVersion`
/// do Info.plist do bundle principal na inicialização.
///
/// Os valores são capturados uma única vez e imutáveis após a criação da instância.
public struct DefaultAppInfoProvider: AppInfoProviding {

    public let platform: String = "ios"
    public let version: String
    public let build: String

    /// - Parameter bundle: Bundle a ser lido. Padrão: `.main`.
    public init(bundle: Bundle = .main) {
        version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        build   = bundle.infoDictionary?["CFBundleVersion"]            as? String ?? ""
    }
}
