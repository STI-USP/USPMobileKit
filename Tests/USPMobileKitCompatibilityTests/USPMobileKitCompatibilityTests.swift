import XCTest
import USPAuthKit
import USPObservabilityKit
import USPJourneyKit

final class USPMobileKitCompatibilityTests: XCTestCase {
    func testConsumerCanImportAuthAndObservabilityTogether() {
        XCTAssertTrue(true)
    }

    @MainActor func testConsumerCanUseJourneyAlongsideAuthAndObservability() async throws {
        let definition = try JourneyDefinition(type: "COMPAT-J001", initialStage: "consultar",
            stages: ["consultar"], completionStages: ["consultar"])
        let memory = InMemoryJourneyReporter()
        let coordinator = JourneyCoordinator(reporter: memory)
        let attempt = try coordinator.start(definition)
        try coordinator.complete(attempt, at: "consultar")
        XCTAssertEqual(memory.events.map(\.name), [.started, .completed])
    }
}
