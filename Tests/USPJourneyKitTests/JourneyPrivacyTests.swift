import XCTest
@testable import USPJourneyKit

final class JourneyPrivacyTests: XCTestCase {
    private func definition(key: String, values: Set<String> = ["permitido"]) throws -> JourneyDefinition {
        try JourneyDefinition(type: "CAP-J001", initialStage: "inicio", stages: ["inicio"],
                              completionStages: ["inicio"], parameterValues: [key: values])
    }

    func testReservedAndSensitiveKeysAreRejectedEvenWhenAllowlisted() throws {
        let keys = ["id_jornada", "tipo_jornada", "versao_contrato", "resultado", "etapa_jornada",
                    "codigo_erro", "categoria_erro", "etapa_falha", "motivo_cancelamento",
                    "id_trace", "id_requisicao", "numero_usuario", "numero_usp", "EMAIL", "token",
                    "banner_json", "url_destino", "payload", "saldo", "valor_pix", "id_aviso",
                    "aviso_id", "nome", "mensagem_erro", "coordenada", "file_path"]
        for key in keys { XCTAssertThrowsError(try definition(key: key), key) }
    }

    func testOnlyFiniteControlledValuesFitTheSchema() throws {
        for value in ["", "https://usp.br", "someone@usp.br", "123456", "texto livre",
                      "ação", String(repeating: "a", count: 65)] {
            XCTAssertThrowsError(try definition(key: "origem", values: [value]), value)
        }
        XCTAssertNoThrow(try definition(key: "origem", values: ["home", "push"]))
        XCTAssertThrowsError(try definition(key: "origem", values: []))
    }

    func testSchemaCapsParameterCountAndPreservesFirebaseBudget() throws {
        let many = Dictionary(uniqueKeysWithValues: (0..<11).map { ("dim_\($0)", Set(["yes"])) })
        XCTAssertThrowsError(try JourneyDefinition(type: "CAP-J001", initialStage: "inicio", stages: ["inicio"],
                                                  completionStages: ["inicio"], parameterValues: many))
    }

    func testSchemaRejectsUnknownAndEmptyCompletionStages() throws {
        XCTAssertThrowsError(try JourneyDefinition(type: "CAP-J001", initialStage: "a", stages: ["a"], completionStages: ["b"]))
        XCTAssertThrowsError(try JourneyDefinition(type: "CAP-J001", initialStage: "a", stages: ["a"], completionStages: []))
        XCTAssertThrowsError(try JourneyDefinition(type: "CAP-J001", initialStage: "a", stages: ["a"], completionStages: ["a"],
                                                  transitions: ["a": ["unknown"]]))
        XCTAssertThrowsError(try JourneyDefinition(type: "https://usp.br", initialStage: "a", stages: ["a"], completionStages: ["a"]))
    }

    func testOptionalCorrelationRejectsPayloadsAndZeroTrace() throws {
        XCTAssertNoThrow(try JourneyCorrelation())
        XCTAssertNoThrow(try JourneyCorrelation(requestID: UUID(), traceID: "0123456789abcdef0123456789abcdef"))
        for value in [String(repeating: "0", count: 32), "https://usp.br", "0123456789ABCDEf0123456789abcdef", "someone@usp.br"] {
            XCTAssertThrowsError(try JourneyCorrelation(traceID: value))
        }
    }

    func testContractHasExactlyFiveEventsAndNoAbandonment() {
        XCTAssertEqual(Set(JourneyEventName.allCases.map(\.rawValue)),
                       ["jornada_iniciada", "etapa_jornada", "jornada_concluida", "jornada_falhou", "jornada_cancelada"])
    }
}
