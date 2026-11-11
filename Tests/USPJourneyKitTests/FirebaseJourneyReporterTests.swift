import XCTest
import USPJourneyKit

@MainActor final class FirebaseJourneyReporterTests: XCTestCase {
    private func definition() throws -> JourneyDefinition {
        try JourneyDefinition(type: "TEST-J001", initialStage: "obter", stages: ["obter"], completionStages: ["obter"])
    }

    func testDefaultPolicyNeverTouchesFirebase() async throws {
        let sink = SinkSpy()
        let reporter = sink.makeReporter()
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
        let reporter = sink.makeReporter(policy: JourneyCollectionPolicy(
            allowsAnalytics: { gate.analytics }, allowsDiagnostics: { gate.diagnostics }))
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
        XCTAssertEqual(sink.events.map(\.name), [JourneyEventName.started.rawValue, JourneyEventName.failed.rawValue])
        XCTAssertEqual(sink.diagnostics.count, 1)
    }

    func testUnconfiguredProjectDoesNotConsumeFunctionalFlow() async throws {
        let sink = SinkSpy()
        sink.configured = false
        let reporter = sink.makeReporter(policy: JourneyCollectionPolicy(allowsAnalytics: { true }))
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
        let reporter = sink.makeReporter(policy: JourneyCollectionPolicy(allowsDiagnostics: { true }))
        let coordinator = JourneyCoordinator(reporter: reporter, diagnosticReporter: reporter)
        let a = try coordinator.start(definition())
        let b = try coordinator.start(definition())
        try coordinator.fail(b, at: "obter", category: .timeout, reporting: .reportableTechnical)
        try coordinator.fail(a, at: "obter", category: .invalidData, reporting: .reportableTechnical)
        XCTAssertEqual(sink.diagnostics[0].parameters["id_jornada"] as? String, b.id.uuidString.lowercased())
        XCTAssertEqual(sink.diagnostics[1].parameters["id_jornada"] as? String, a.id.uuidString.lowercased())
        XCTAssertEqual(sink.diagnostics[1].parameters["categoria_erro"] as? String, "dados_invalidos")
        XCTAssertEqual(sink.diagnostics.map { $0.error.domain }, ["br.usp.mobile.journey", "br.usp.mobile.journey"])
        XCTAssertEqual(sink.diagnostics.map { $0.error.code }, [1, 1])
        XCTAssertNil(sink.diagnostics[0].error.userInfo["id_jornada"])
    }

    func testCollectionRevocationSuppressesLaterSendsWithoutInventingTerminal() async throws {
        let sink = SinkSpy()
        let gate = Gate()
        gate.analytics = true
        let reporter = sink.makeReporter(policy: JourneyCollectionPolicy(allowsAnalytics: { gate.analytics }))
        let coordinator = JourneyCoordinator(reporter: reporter)
        let a = try coordinator.start(definition())
        gate.analytics = false
        try coordinator.complete(a, at: "obter")
        XCTAssertEqual(sink.events.map(\.name), [JourneyEventName.started.rawValue])
        XCTAssertEqual(coordinator.activeAttemptCount, 0)
    }
}

@MainActor private final class Gate { var analytics = false; var diagnostics = false }
@MainActor private final class SinkSpy {
    var configured = true
    var configurationChecks = 0
    var events: [(name: String, parameters: [String: Any])] = []
    var diagnostics: [(error: NSError, parameters: [String: Any])] = []

    func makeReporter(policy: JourneyCollectionPolicy = JourneyCollectionPolicy()) -> FirebaseJourneyReporter {
        FirebaseJourneyReporter(
            policy: policy,
            isConfigured: {
                self.configurationChecks += 1
                return self.configured
            },
            logEvent: { self.events.append(($0, $1)) },
            recordError: { self.diagnostics.append(($0, $1)) }
        )
    }
}
