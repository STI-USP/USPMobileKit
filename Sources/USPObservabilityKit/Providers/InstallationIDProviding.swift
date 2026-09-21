// InstallationIDProviding.swift
// USPObservabilityKit
//
// Fornece um identificador pseudônimo de instalação para o header
// USP-Installation-Id.
//
// ═══════════════════════════════════════════════════════════════
//  O que é o Installation ID
// ═══════════════════════════════════════════════════════════════
//
//  • UUID aleatório gerado na primeira execução após a instalação.
//  • NÃO representa o usuário (sem login, sem e-mail, sem CPF).
//  • NÃO representa o dispositivo (sem IDFA, IDFV, serial).
//  • NÃO representa uma sessão (não é regenerado a cada sessão).
//  • Representa uma instalação específica do aplicativo.
//
// ═══════════════════════════════════════════════════════════════
//  Ciclo de vida
// ═══════════════════════════════════════════════════════════════
//
//  Atualização do app  → ID preservado (UserDefaults sobrevive)
//  Desinstalação       → ID removido (UserDefaults limpo pelo SO)
//  Reinstalação        → Novo ID gerado
//  Restore de backup   → ID do dispositivo de origem é restaurado*
//
//  * Em um restore do iCloud, o UserDefaults é copiado junto com o
//    backup. Por um curto período, dois dispositivos podem ter o
//    mesmo ID se o usuário restaurou um backup em novo dispositivo
//    e ainda usa o original. Esse comportamento é aceitável para
//    um identificador pseudônimo de volume/correlação e é análogo
//    ao comportamento do Firebase Installation ID em modo padrão.
//
//    Para evitar completamente esse cenário, o ID poderia ser
//    armazenado no Keychain com kSecAttrSynchronizable = false
//    (não incluído no backup). Essa migração pode ser feita em
//    Iteração futura sem breaking change na API pública.
//
// ═══════════════════════════════════════════════════════════════
//  Privacidade
// ═══════════════════════════════════════════════════════════════
//
//  ✗ Não use como dimensão de alta cardinalidade em métricas
//    (ex.: não enviar ao Firebase Analytics como user_property).
//  ✗ Não associar ao usuário autenticado.
//  ✗ Não logar em sistemas que correlacionam com dados pessoais.
//  ✓ Adequado para correlação de requests de uma mesma instalação
//    em logs de infraestrutura (baixa cardinalidade efetiva no
//    contexto de um backend institucional).

import Foundation

// MARK: - Protocol

/// Fornece um identificador pseudônimo e estável para a instalação atual do app.
public protocol InstallationIDProviding: Sendable {

    /// UUID string representando a instalação atual.
    /// Reutilizado entre chamadas e entre execuções do app.
    /// Exemplo: `"A3F1B2C4-1234-5678-ABCD-9876543210EF"`
    var installationID: String { get }
}

// MARK: - Default Implementation

/// Gera um UUID aleatório na primeira execução e o persiste em `UserDefaults`.
///
/// O identificador é lido e imutável após a inicialização da instância.
/// A inicialização deve ocorrer uma única vez (ex.: ao criar o `USPContextInstrumenter`)
/// para garantir consistência dentro de uma sessão de execução do app.
///
/// ## Armazenamento
/// Chave padrão: `"com.usp.mobile.installationID"` no suite fornecido.
///
/// ## Thread Safety
/// A geração inicial usa `UserDefaults` que é thread-safe para leitura/escrita
/// de strings. Em condições de corrida extremamente raras na primeira instalação,
/// a última gravação vence — ambos os UUIDs são válidos e pseudônimos.
public struct DefaultInstallationIDProvider: InstallationIDProviding {

    /// Chave padrão no UserDefaults.
    public static let defaultKey = "com.usp.mobile.installationID"

    public let installationID: String

    /// - Parameters:
    ///   - userDefaults: Suite de defaults onde o ID é persistido. Padrão: `.standard`.
    ///   - key: Chave de armazenamento. Use o padrão, a não ser em testes isolados.
    public init(
        userDefaults: UserDefaults = .standard,
        key: String = defaultKey
    ) {
        if let existing = userDefaults.string(forKey: key), !existing.isEmpty {
            installationID = existing
        } else {
            let newID = UUID().uuidString
            userDefaults.set(newID, forKey: key)
            installationID = newID
        }
    }
}
