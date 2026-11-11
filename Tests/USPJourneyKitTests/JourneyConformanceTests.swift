import XCTest
import USPJourneyKit

@MainActor final class JourneyConformanceTests: XCTestCase {
    func testPortableGoldenContract() async throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "contract-v1", withExtension: "json"))
        let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
        XCTAssertEqual(fixture.contract_version, JourneyEvent.contractVersion)
        let d = fixture.definition
        let definition = try JourneyDefinition(type: d.type, initialStage: d.initial_stage,
            stages: Set(d.stages), completionStages: Set(d.completion_stages))
        for scenario in fixture.cases {
            let memory = InMemoryJourneyReporter()
            let coordinator = JourneyCoordinator(reporter: memory)
            var attempt: JourneyAttempt?
            for action in scenario.actions {
                if action == "start" { attempt = try coordinator.start(definition); continue }
                let a = try XCTUnwrap(attempt)
                switch action {
                case "advance": try coordinator.advance(a, to: "apresentar")
                case "complete": try coordinator.complete(a, at: "apresentar")
                case "fail": try coordinator.fail(a, at: "obter", category: .timeout)
                case "cancel": try coordinator.cancel(a)
                case "forget": coordinator.forget(a)
                default: XCTFail("Unknown fixture action")
                }
            }
            let actual = memory.events.map { event in
                Expected(name: event.name.rawValue, parameters: event.parameters.mapValues { value in
                    value == attempt?.id.uuidString.lowercased() ? "<attempt>" : value
                })
            }
            XCTAssertEqual(actual, scenario.expected, scenario.name)
        }
    }

    /// Example consumer: business validation remains outside the kit.
    func testPixExampleOnlyCompletesAfterUsableCodeIsAvailable() async throws {
        let memory = InMemoryJourneyReporter()
        let coordinator = JourneyCoordinator(reporter: memory)
        let definition = try JourneyDefinition(type: "EXAMPLE-J005", initialStage: "gerar_codigo",
            stages: ["gerar_codigo", "disponibilizar_codigo"], completionStages: ["disponibilizar_codigo"])
        let failed = try coordinator.start(definition)
        // The app, not a successful HTTP status, decides this response is unusable.
        try coordinator.fail(failed, at: "gerar_codigo", category: .invalidData)
        let valid = try coordinator.start(definition)
        // The app has validated and presented its result. No Pix content is sent.
        try coordinator.complete(valid, at: "disponibilizar_codigo")
        XCTAssertEqual(memory.events.map(\.name), [.started, .failed, .started, .completed])
        XCTAssertFalse(memory.events.contains { $0.parameters.keys.contains("codigo_pix") })
    }
}

private struct Fixture: Decodable {
    let contract_version: String
    let definition: Definition
    let cases: [Scenario]
    struct Definition: Decodable {
        let type: String; let initial_stage: String; let stages: [String]; let completion_stages: [String]
    }
    struct Scenario: Decodable { let name: String; let actions: [String]; let expected: [Expected] }
}
private struct Expected: Decodable, Equatable { let name: String; let parameters: [String: String] }
