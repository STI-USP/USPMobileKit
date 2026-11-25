import Foundation

public enum JourneyEventName: String, Sendable, CaseIterable {
    case started = "jornada_iniciada"
    case stage = "etapa_jornada"
    case completed = "jornada_concluida"
    case failed = "jornada_falhou"
    case cancelled = "jornada_cancelada"
}

public enum JourneyErrorCategory: String, Sendable, CaseIterable {
    case connectivity = "conectividade"
    case timeout = "tempo_esgotado"
    case authentication = "autenticacao"
    case business = "negocio"
    case invalidData = "dados_invalidos"
    case unavailable = "indisponibilidade"
    case destinationOpening = "abertura_destino"
    case unclassified = "nao_classificada"
}

/// Created only by the coordinator after schema and transition validation.
public struct JourneyEvent: Equatable, Sendable {
    public static let contractVersion = "1"
    public let name: JourneyEventName
    public let parameters: [String: String]

    init(name: JourneyEventName, parameters: [String: String]) {
        self.name = name
        self.parameters = parameters
    }
}

/// Optional correlation, never required to start/finish a journey.
public struct JourneyCorrelation: Equatable, Sendable {
    public let requestID: UUID?
    public let traceID: String?

    public init(requestID: UUID? = nil, traceID: String? = nil) throws {
        if let traceID {
            guard traceID.utf8.count == 32,
                  traceID.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }),
                  traceID.contains(where: { $0 != "0" }) else {
                throw JourneyValidationError.invalidCorrelation
            }
        }
        self.requestID = requestID
        self.traceID = traceID
    }

    var parameters: [String: String] {
        var result: [String: String] = [:]
        if let requestID { result["id_requisicao"] = requestID.uuidString.lowercased() }
        if let traceID { result["id_trace"] = traceID }
        return result
    }
}

/// No raw Error, localized message or backend payload crosses this boundary.
public struct JourneyDiagnostic: Equatable, Sendable {
    public let parameters: [String: String]
    init(parameters: [String: String]) { self.parameters = parameters }
}

public enum JourneyFailureReporting: Sendable {
    case functionalOnly
    /// Explicit classification by the app; independently subject to collection policy.
    case reportableTechnical
}
