import Foundation

/// Configuração de segurança do `USPObservabilityKit`.
///
/// Apenas requests cujo host corresponda exatamente a um item de `allowedHosts`
/// recebem headers de observabilidade. A comparação ignora maiúsculas/minúsculas
/// e um ponto final de DNS, mas não inclui subdomínios implicitamente.
public struct ObservabilityConfiguration: Sendable, Equatable {

    /// Hosts canônicos autorizados, sem scheme, porta ou path.
    public let allowedHosts: Set<String>

    /// Cria uma configuração com allowlist explícita.
    ///
    /// Entradas inválidas são ignoradas de forma segura. Uma lista vazia desabilita
    /// a instrumentação para todos os destinos.
    public init(allowedHosts: [String]) {
        self.allowedHosts = Set(allowedHosts.compactMap(Self.canonicalHost))
    }

    func allows(_ url: URL?) -> Bool {
        guard let host = url?.host,
              let canonical = Self.canonicalHost(host) else {
            return false
        }
        return allowedHosts.contains(canonical)
    }

    private static func canonicalHost(_ host: String) -> String? {
        var candidate = host
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        while candidate.hasSuffix(".") {
            candidate.removeLast()
        }

        let labels = candidate.split(separator: ".", omittingEmptySubsequences: false)
        guard !candidate.isEmpty,
              candidate.utf8.count <= 253,
              !candidate.contains(where: \Character.isWhitespace),
              candidate.allSatisfy({
                  ("a"..."z").contains($0)
                      || ("0"..."9").contains($0)
                      || $0 == "-"
                      || $0 == "."
              }),
              labels.allSatisfy({
                  !$0.isEmpty && $0.utf8.count <= 63 && $0.first != "-" && $0.last != "-"
              }),
              let parsed = URL(string: "https://\(candidate)"),
              parsed.host?.lowercased() == candidate,
              parsed.port == nil,
              parsed.user == nil,
              parsed.password == nil,
              parsed.path.isEmpty,
              parsed.query == nil,
              parsed.fragment == nil else {
            return nil
        }

        return candidate
    }
}
