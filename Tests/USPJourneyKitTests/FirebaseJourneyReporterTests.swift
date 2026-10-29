import XCTest
@testable import USPJourneyKit

@MainActor final class FirebaseJourneyReporterTests: XCTestCase {
    private func definition() throws -> JourneyDefinition {
        try JourneyDefinition(type: "TEST-J001", initialStage: "obter", stages: ["obter"], completionStages: ["obter"])
    }

    func testDefaultPolicyNeverTouchesFirebase() async throws {
        let sink = SinkSpy()
        let reporter = FirebaseJourneyReporter(policy: JourneyCollectionPolicy(), sink: sink)
        let coordinator = JourneyCoordinator(reporter: reporter, diagnosticReporter: reporter)
        let a = try coordinator.start(definition())
        try coordinator.fail(a, at: "obter", category: .timeout, reporting: .reportableTechnical)
        XCTAssertEqual(sink.configurationChecks, 0)
        XCTAssertTrue(sink.events.isEmpty)
        XCTAssertTrue(sink.diagnostics.isEmpty)
    }

    func testCollectionPolicyIsDynamicAndChannelsAreIndependent() async throws {
        let gate = Gate()
        let sink = SinkSpy()
        let reporter = FirebaseJourneyReporter(policy: JourneyCollectionPolicy(
            allowsAnalytics: { gate.analytics }, allowsDiagnostics: { gate.diagnostics }), sink: sink)
        let coordinator = JourneyCoordinator(reporter: reporter, diagnosticReporter: reporter)
        let a = try coordinator.start(definition()) // both false
        gate.diagnostics = true
        try coordinator.fail(a, at: "obter", category: .timeout, reporting: .reportableTechnical)
        XCTAssertTrue(sink.events.isEmpty)
        XCTAssertEqual(sink.diagnostics.count, 1)
        gate.analytics = true
        gate.diagnostics = false
        let b = try coordinator.start(definition())
        try coordinator.fail(b, at: "obter", category: .timeout, reporting: .reportableTechnical)
        XCTAssertEqual(sink.events.map(\.name), [.started, .failed])
        XCTAssertEqual(sink.diagnostics.count, 1)
    }

    func testUnconfiguredProjectDoesNotConsumeFunctionalFlow() async throws {
        let sink = SinkSpy()
        sink.configured = false
        let reporter = FirebaseJourneyReporter(policy: JourneyCollectionPolicy(allowsAnalytics: { true }), sink: sink)
        var issueCount = 0
        let coordinator = JourneyCoordinator(reporter: reporter, onRecordingIssue: { _ in issueCount += 1 })
        let a = try coordinator.start(definition())
        try coordinator.complete(a, at: "obter")
        XCTAssertEqual(issueCount, 2)
        XCTAssertEqual(coordinator.activeAttemptCount, 0)
        XCTAssertTrue(sink.events.isEmpty)
    }

    func testEachDiagnosticKeepsItsOwnContextAcrossConcurrentAttempts() async throws {
        let sink = SinkSpy()
        let reporter = FirebaseJourneyReporter(policy: JourneyCollectionPolicy(allowsDiagnostics: { true }), sink: sink)
        let coordinator = JourneyCoordinator(reporter: reporter, diagnosticReporter: reporter)
        let a = try coordinator.start(definition())
        let b = try coordinator.start(definition())
        try coordinator.fail(b, at: "obter", category: .timeout, reporting: .reportableTechnical)
        try coordinator.fail(a, at: "obter", category: .invalidData, reporting: .reportableTechnical)
        XCTAssertEqual(sink.diagnostics[0].parameters["id_jornada"], b.id.uuidString.lowercased())
        XCTAssertEqual(sink.diagnostics[1].parameters["id_jornada"], a.id.uuidString.lowercased())
        XCTAssertEqual(sink.diagnostics[1].parameters["categoria_erro"], "dados_invalidos")
    }

    func testCollectionRevocationSuppressesLaterSendsWithoutInventingTerminal() async throws {
        let sink = SinkSpy()
        let gate = Gate()
        gate.analytics = true
        let reporter = FirebaseJourneyReporter(policy: JourneyCollectionPolicy(allowsAnalytics: { gate.analytics }), sink: sink)
        let coordinator = JourneyCoordinator(reporter: reporter)
        let a = try coordinator.start(definition())
        gate.analytics = false
        try coordinator.complete(a, at: "obter")
        XCTAssertEqual(sink.events.map(\.name), [.started])
        XCTAssertEqual(coordinator.activeAttemptCount, 0)
    }
}

@MainActor private final class Gate { var analytics = false; var diagnostics = false }
@MainActor private final class SinkSpy: JourneyFirebaseSink {
    var configured = true
    var configurationChecks = 0
    var isConfigured: Bool { configurationChecks += 1; return configured }
    var events: [JourneyEvent] = []
    var diagnostics: [JourneyDiagnostic] = []
    func log(_ event: JourneyEvent) { events.append(event) }
    func record(_ diagnostic: JourneyDiagnostic) { diagnostics.append(diagnostic) }
}
