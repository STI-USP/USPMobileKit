import XCTest
@testable import USPJourneyKit

@MainActor final class JourneyCoordinatorTests: XCTestCase {
    private func definition(transitions: [String: Set<String>]? = nil) throws -> JourneyDefinition {
        try JourneyDefinition(type: "TEST-J001", initialStage: "solicitar",
                              stages: ["solicitar", "autenticar", "apresentar"], completionStages: ["apresentar"],
                              parameterValues: ["origem": ["home", "lista"], "disponibilidade": ["com_dados", "sem_dados"]],
                              errorCodes: ["servico_indisponivel"], cancellationReasons: ["voltar"], transitions: transitions)
    }

    func testSuccessSerializesContractWithoutSyntheticSteps() async throws {
        let memory = InMemoryJourneyReporter()
        let coordinator = JourneyCoordinator(reporter: memory)
        let attempt = try coordinator.start(definition(), parameters: ["origem": "home"])
        try coordinator.complete(attempt, at: "apresentar", parameters: ["disponibilidade": "com_dados"])
        XCTAssertEqual(memory.events.map(\.name), [.started, .completed])
        XCTAssertEqual(memory.events[0].parameters, ["id_jornada": attempt.id.uuidString.lowercased(),
            "tipo_jornada": "TEST-J001", "versao_contrato": "1", "origem": "home"])
        XCTAssertEqual(memory.events[1].parameters["resultado"], "sucesso")
        XCTAssertEqual(memory.events[1].parameters["disponibilidade"], "com_dados")
        XCTAssertNil(memory.events[1].parameters["etapa_jornada"])
        XCTAssertEqual(coordinator.activeAttemptCount, 0)
    }

    func testEveryPostTerminalMutationIsIgnored() async throws {
        let memory = InMemoryJourneyReporter()
        let coordinator = JourneyCoordinator(reporter: memory)
        let a = try coordinator.start(definition())
        XCTAssertEqual(try coordinator.complete(a, at: "apresentar"), .accepted)
        XCTAssertEqual(try coordinator.complete(a, at: "apresentar"), .inactive)
        XCTAssertEqual(try coordinator.fail(a, at: "solicitar", category: .timeout), .inactive)
        XCTAssertEqual(try coordinator.cancel(a), .inactive)
        XCTAssertEqual(try coordinator.advance(a, to: "autenticar"), .inactive)
        XCTAssertEqual(memory.events.count, 2)
    }

    func testInvalidTransitionDoesNotConsumeAttempt() async throws {
        let memory = InMemoryJourneyReporter()
        let coordinator = JourneyCoordinator(reporter: memory)
        let d = try definition(transitions: ["solicitar": ["autenticar"], "autenticar": ["apresentar"]])
        let a = try coordinator.start(d)
        XCTAssertThrowsError(try coordinator.complete(a, at: "apresentar"))
        XCTAssertThrowsError(try coordinator.complete(a, at: "solicitar"))
        XCTAssertEqual(memory.events.count, 1)
        try coordinator.advance(a, to: "autenticar")
        try coordinator.complete(a, at: "apresentar")
        XCTAssertEqual(memory.events.map(\.name), [.started, .stage, .completed])
    }

    func testInvalidParametersAreAtomicAndNeverReachReporter() async throws {
        let memory = InMemoryJourneyReporter()
        let coordinator = JourneyCoordinator(reporter: memory)
        let d = try definition()
        XCTAssertThrowsError(try coordinator.start(d, parameters: ["numero_usp": "123456"]))
        XCTAssertThrowsError(try coordinator.start(d, parameters: ["origem": "unreviewed"]))
        XCTAssertEqual(coordinator.activeAttemptCount, 0)
        let a = try coordinator.start(d, parameters: ["origem": "home"])
        XCTAssertThrowsError(try coordinator.advance(a, to: "autenticar", parameters: ["payload": "secret"]))
        XCTAssertThrowsError(try coordinator.fail(a, at: "solicitar", category: .business, code: "raw_backend_error"))
        XCTAssertThrowsError(try coordinator.cancel(a, reason: "arbitrary"))
        try coordinator.complete(a, at: "apresentar")
        XCTAssertEqual(memory.events.count, 2)
        XCTAssertEqual(memory.events.last?.parameters["origem"], "home")
    }

    func testConcurrentAttemptsHaveSeparateIDsAndTerminals() async throws {
        let memory = InMemoryJourneyReporter()
        let coordinator = JourneyCoordinator(reporter: memory)
        let d = try definition()
        let a = try coordinator.start(d, parameters: ["origem": "home"])
        let b = try coordinator.start(d, parameters: ["origem": "lista"])
        XCTAssertNotEqual(a.id, b.id)
        try coordinator.fail(a, at: "solicitar", category: .timeout)
        try coordinator.complete(b, at: "apresentar")
        XCTAssertEqual(memory.events[2].parameters["id_jornada"], a.id.uuidString.lowercased())
        XCTAssertEqual(memory.events[3].parameters["origem"], "lista")
        XCTAssertEqual(coordinator.activeAttemptCount, 0)
    }

    func testRacingTerminalTasksProduceOnlyOneTerminal() async throws {
        let memory = InMemoryJourneyReporter()
        let coordinator = JourneyCoordinator(reporter: memory)
        let a = try coordinator.start(definition())
        let accepted = await withTaskGroup(of: JourneyUpdateResult.self, returning: Int.self) { group in
            for _ in 0..<50 {
                group.addTask { try! await coordinator.complete(a, at: "apresentar") }
            }
            var count = 0
            for await result in group where result == .accepted { count += 1 }
            return count
        }
        XCTAssertEqual(accepted, 1)
        XCTAssertEqual(memory.events.map(\.name), [.started, .completed])
    }

    func testRetryAfterFailureRequiresNewID() async throws {
        let memory = InMemoryJourneyReporter()
        let coordinator = JourneyCoordinator(reporter: memory)
        let d = try definition()
        let first = try coordinator.start(d)
        try coordinator.fail(first, at: "solicitar", category: .connectivity)
        let retry = try coordinator.start(d)
        XCTAssertNotEqual(first.id, retry.id)
        XCTAssertEqual(try coordinator.advance(first, to: "autenticar"), .inactive)
        XCTAssertEqual(memory.events.map(\.name), [.started, .failed, .started])
    }

    func testForeignAndForgottenAttemptsCannotBeUsed() async throws {
        let memory = InMemoryJourneyReporter()
        let first = JourneyCoordinator(reporter: memory)
        let second = JourneyCoordinator(reporter: memory)
        let a = try first.start(definition())
        XCTAssertEqual(try second.complete(a, at: "apresentar"), .inactive)
        XCTAssertEqual(first.forget(a), .accepted)
        XCTAssertEqual(try first.cancel(a), .inactive)
        XCTAssertEqual(memory.events.map(\.name), [.started])
        XCTAssertEqual(first.activeAttemptCount, 0)
    }

    func testCancelUsesCurrentStageAndReviewedReason() async throws {
        let memory = InMemoryJourneyReporter()
        let coordinator = JourneyCoordinator(reporter: memory)
        let a = try coordinator.start(definition())
        try coordinator.advance(a, to: "autenticar")
        try coordinator.cancel(a, reason: "voltar")
        XCTAssertEqual(memory.events.last?.name, .cancelled)
        XCTAssertEqual(memory.events.last?.parameters["etapa_jornada"], "autenticar")
        XCTAssertEqual(memory.events.last?.parameters["resultado"], "cancelado")
        XCTAssertEqual(memory.events.last?.parameters["motivo_cancelamento"], "voltar")
    }

    func testOnlyExplicitTechnicalFailuresGenerateDiagnostics() async throws {
        let memory = InMemoryJourneyReporter()
        let coordinator = JourneyCoordinator(reporter: memory, diagnosticReporter: memory)
        let d = try definition()
        let first = try coordinator.start(d)
        try coordinator.fail(first, at: "solicitar", category: .business)
        XCTAssertTrue(memory.diagnostics.isEmpty)
        let second = try coordinator.start(d, parameters: ["origem": "home"])
        let correlation = try JourneyCorrelation(requestID: UUID(), traceID: "0123456789abcdef0123456789abcdef")
        try coordinator.fail(second, at: "solicitar", category: .timeout, code: "servico_indisponivel",
                             reporting: .reportableTechnical, correlation: correlation)
        let diagnostic = try XCTUnwrap(memory.diagnostics.first)
        XCTAssertEqual(diagnostic.parameters["id_jornada"], second.id.uuidString.lowercased())
        XCTAssertNil(diagnostic.parameters["origem"])
        XCTAssertEqual(diagnostic.parameters["id_trace"], correlation.traceID)
        XCTAssertEqual(diagnostic.parameters["codigo_erro"], "servico_indisponivel")
        XCTAssertEqual(memory.diagnostics.count, 1)
    }

    func testReporterFailuresDoNotThrowOrReopenTerminal() async throws {
        let broken = BrokenReporter()
        let memory = InMemoryJourneyReporter()
        var issues: [JourneyRecordingIssue] = []
        let coordinator = JourneyCoordinator(reporter: broken, diagnosticReporter: memory,
                                               onRecordingIssue: { issues.append($0) })
        let a = try coordinator.start(definition())
        try coordinator.fail(a, at: "solicitar", category: .invalidData, reporting: .reportableTechnical)
        XCTAssertEqual(coordinator.activeAttemptCount, 0)
        XCTAssertEqual(issues.count, 2)
        XCTAssertEqual(memory.diagnostics.count, 1)
        XCTAssertEqual(try coordinator.complete(a, at: "apresentar"), .inactive)
    }

    func testDiagnosticReporterFailureIsIsolated() async throws {
        let memory = InMemoryJourneyReporter()
        var issues: [JourneyRecordingIssue] = []
        let coordinator = JourneyCoordinator(reporter: memory, diagnosticReporter: BrokenReporter(),
                                               onRecordingIssue: { issues.append($0) })
        let a = try coordinator.start(definition())
        try coordinator.fail(a, at: "solicitar", category: .invalidData, reporting: .reportableTechnical)
        XCTAssertEqual(memory.events.map(\.name), [.started, .failed])
        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(coordinator.activeAttemptCount, 0)
    }

    func testReentrantReporterCannotDuplicateTerminal() async throws {
        let memory = InMemoryJourneyReporter()
        let reporter = ReentrantReporter(memory: memory)
        let coordinator = JourneyCoordinator(reporter: reporter)
        let a = try coordinator.start(definition())
        var reentrantResult: JourneyUpdateResult?
        reporter.onTerminal = { reentrantResult = try? coordinator.complete(a, at: "apresentar") }
        try coordinator.complete(a, at: "apresentar")
        XCTAssertEqual(reentrantResult, .inactive)
        XCTAssertEqual(memory.events.map(\.name), [.started, .completed])
    }
}

@MainActor private final class BrokenReporter: JourneyReporting, JourneyDiagnosticReporting {
    enum Failure: Error { case unavailable }
    func record(_ event: JourneyEvent) throws { throw Failure.unavailable }
    func record(_ diagnostic: JourneyDiagnostic) throws { throw Failure.unavailable }
}

@MainActor private final class ReentrantReporter: JourneyReporting {
    let memory: InMemoryJourneyReporter
    var onTerminal: (() -> Void)?
    init(memory: InMemoryJourneyReporter) { self.memory = memory }
    func record(_ event: JourneyEvent) {
        memory.record(event)
        if event.name == .completed { onTerminal?() }
    }
}
