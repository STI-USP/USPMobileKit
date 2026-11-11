import Foundation

@MainActor public protocol JourneyReporting: AnyObject {
    func record(_ event: JourneyEvent) throws
}

@MainActor public protocol JourneyDiagnosticReporting: AnyObject {
    func record(_ diagnostic: JourneyDiagnostic) throws
}

/// Useful for deterministic consumer tests; does not contact Firebase.
@MainActor public final class InMemoryJourneyReporter: JourneyReporting, JourneyDiagnosticReporting {
    public private(set) var events: [JourneyEvent] = []
    public private(set) var diagnostics: [JourneyDiagnostic] = []
    public init() {}
    public func record(_ event: JourneyEvent) { events.append(event) }
    public func record(_ diagnostic: JourneyDiagnostic) { diagnostics.append(diagnostic) }
    public func reset() { events.removeAll(); diagnostics.removeAll() }
}
