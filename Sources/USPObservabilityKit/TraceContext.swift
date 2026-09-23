import Foundation

/// Flags suportadas pelo Trace Context versão `00` nesta iteração.
public enum TraceFlags: String, Sendable, Equatable {
    case notSampled = "00"
    case sampled = "01"
}

/// Contexto mínimo W3C usado para correlacionar uma operação HTTP.
public struct TraceContext: Sendable, Equatable {

    public let traceID: String
    public let parentID: String
    public let flags: TraceFlags

    /// Representação W3C versão `00` pronta para o header `traceparent`.
    public var traceparent: String {
        "00-\(traceID)-\(parentID)-\(flags.rawValue)"
    }

    /// Cria e valida um contexto explícito.
    public init?(traceID: String, parentID: String, flags: TraceFlags = .sampled) {
        guard Self.isValidIdentifier(traceID, length: 32),
              Self.isValidIdentifier(parentID, length: 16) else {
            return nil
        }
        self.traceID = traceID
        self.parentID = parentID
        self.flags = flags
    }

    /// Faz parsing do subconjunto de W3C Trace Context suportado pelo package.
    public init?(traceparent: String) {
        let fields = traceparent.split(separator: "-", omittingEmptySubsequences: false)
        guard fields.count == 4,
              fields[0] == "00",
              let flags = TraceFlags(rawValue: String(fields[3])) else {
            return nil
        }
        self.init(
            traceID: String(fields[1]),
            parentID: String(fields[2]),
            flags: flags
        )
    }

    /// Cria um novo contexto para uma operação lógica independente.
    public static func create(flags: TraceFlags = .sampled) -> TraceContext {
        make(flags: flags, using: SecureRandomBytesGenerator())
    }

    /// Cria o contexto da próxima tentativa, preservando o trace ID e renovando
    /// o parent ID.
    public func nextAttempt() -> TraceContext {
        nextAttempt(using: SecureRandomBytesGenerator())
    }

    static func make(
        flags: TraceFlags = .sampled,
        using generator: any RandomBytesGenerating
    ) -> TraceContext {
        TraceContext(
            traceID: nonZeroIdentifier(byteCount: 16, using: generator),
            parentID: nonZeroIdentifier(byteCount: 8, using: generator),
            flags: flags
        )!
    }

    func nextAttempt(using generator: any RandomBytesGenerating) -> TraceContext {
        TraceContext(
            traceID: traceID,
            parentID: Self.nonZeroIdentifier(byteCount: 8, using: generator),
            flags: flags
        )!
    }

    private static func isValidIdentifier(_ value: String, length: Int) -> Bool {
        guard value.count == length,
              value.allSatisfy({ ("0"..."9").contains($0) || ("a"..."f").contains($0) }) else {
            return false
        }
        return value.contains { $0 != "0" }
    }

    private static func nonZeroIdentifier(
        byteCount: Int,
        using generator: any RandomBytesGenerating
    ) -> String {
        while true {
            let bytes = generator.bytes(count: byteCount)
            precondition(bytes.count == byteCount, "Random byte generator returned an invalid byte count")
            if bytes.contains(where: { $0 != 0 }) {
                return bytes.map { String(format: "%02x", $0) }.joined()
            }
        }
    }
}

protocol RandomBytesGenerating: Sendable {
    func bytes(count: Int) -> [UInt8]
}

private struct SecureRandomBytesGenerator: RandomBytesGenerating {
    func bytes(count: Int) -> [UInt8] {
        var generator = SystemRandomNumberGenerator()
        return (0..<count).map { _ in
            UInt8.random(in: .min ... .max, using: &generator)
        }
    }
}
