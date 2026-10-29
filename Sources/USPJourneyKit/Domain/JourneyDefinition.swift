import Foundation

/// Configuration errors contain no rejected value, payload or personal data.
public enum JourneyValidationError: Error, Equatable, Sendable {
    case invalidIdentifier
    case reservedParameter
    case invalidSchema
    case parameterNotAllowed
    case valueNotAllowed
    case invalidTransition
    case invalidCorrelation
}

/// A reviewed, finite vocabulary owned by the consuming app. No user input.
public struct JourneyDefinition: Sendable {
    public let type: String
    public let initialStage: String
    public let stages: Set<String>
    public let completionStages: Set<String>
    public let parameterValues: [String: Set<String>]
    public let errorCodes: Set<String>
    public let cancellationReasons: Set<String>
    public let transitions: [String: Set<String>]?

    public init(
        type: String,
        initialStage: String,
        stages: Set<String>,
        completionStages: Set<String>,
        parameterValues: [String: Set<String>] = [:],
        errorCodes: Set<String> = [],
        cancellationReasons: Set<String> = [],
        transitions: [String: Set<String>]? = nil
    ) throws {
        guard JourneyVocabulary.catalogID(type) else {
            throw JourneyValidationError.invalidIdentifier
        }
        guard !stages.isEmpty, stages.count <= 64,
              stages.contains(initialStage), !completionStages.isEmpty,
              completionStages.isSubset(of: stages),
              stages.allSatisfy(JourneyVocabulary.token),
              parameterValues.count <= 10,
              errorCodes.count <= 64, cancellationReasons.count <= 32,
              errorCodes.allSatisfy(JourneyVocabulary.token),
              cancellationReasons.allSatisfy(JourneyVocabulary.token) else {
            throw JourneyValidationError.invalidSchema
        }
        for (key, values) in parameterValues {
            guard !JourneyVocabulary.forbiddenParameter(key) else {
                throw JourneyValidationError.reservedParameter
            }
            guard JourneyVocabulary.token(key), key.count <= 40,
                  !values.isEmpty, values.count <= 64,
                  values.allSatisfy(JourneyVocabulary.token) else {
                throw JourneyValidationError.invalidSchema
            }
        }
        if let transitions {
            guard Set(transitions.keys).isSubset(of: stages),
                  transitions.values.allSatisfy({ $0.isSubset(of: stages) }) else {
                throw JourneyValidationError.invalidSchema
            }
        }
        self.type = type
        self.initialStage = initialStage
        self.stages = stages
        self.completionStages = completionStages
        self.parameterValues = parameterValues
        self.errorCodes = errorCodes
        self.cancellationReasons = cancellationReasons
        self.transitions = transitions
    }

    func validate(_ parameters: [String: String]) throws {
        for (key, value) in parameters {
            guard let values = parameterValues[key] else {
                throw JourneyValidationError.parameterNotAllowed
            }
            guard values.contains(value) else { throw JourneyValidationError.valueNotAllowed }
        }
    }

    func validateTransition(from current: String, to next: String) throws {
        guard stages.contains(next) else { throw JourneyValidationError.invalidTransition }
        if current != next, let transitions, !(transitions[current] ?? []).contains(next) {
            throw JourneyValidationError.invalidTransition
        }
    }
}

enum JourneyVocabulary {
    static let reserved: Set<String> = [
        "id_jornada", "tipo_jornada", "versao_contrato", "etapa_jornada", "resultado",
        "etapa_falha", "categoria_erro", "codigo_erro", "motivo_cancelamento",
        "id_requisicao", "id_trace"
    ]
    // Defence in depth. Finite allowlists still require human semantic review.
    static let sensitive = [
        "user", "usuario", "nome", "name", "email", "mail", "cpf", "matricula", "numero_usp", "usp_number",
        "token", "senha", "password", "credential", "credencial", "payload", "json",
        "url", "uri", "phone", "telefone", "saldo", "balance", "amount", "valor",
        "qrcode", "qrcpix", "pixcode", "codigo_pix", "mensagem", "message", "titulo",
        "title", "texto", "text", "latitude", "longitude", "coordenada", "arquivo", "path"
    ]

    static func forbiddenParameter(_ key: String) -> Bool {
        let lower = key.lowercased()
        return reserved.contains(lower) || lower == "id" || lower.hasPrefix("id_")
            || lower.hasSuffix("_id") || sensitive.contains(where: lower.contains)
    }

    static func token(_ value: String) -> Bool {
        guard (1...64).contains(value.utf8.count), let first = value.utf8.first,
              (97...122).contains(first) else { return false }
        return value.utf8.allSatisfy { (97...122).contains($0) || (48...57).contains($0) || $0 == 95 }
    }

    static func catalogID(_ value: String) -> Bool {
        guard (1...64).contains(value.utf8.count), let first = value.utf8.first,
              (65...90).contains(first) || (97...122).contains(first) else { return false }
        return value.utf8.allSatisfy {
            (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0)
                || $0 == 95 || $0 == 45
        }
    }
}
