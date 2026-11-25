import Foundation

/// Opaque capability: consumers cannot manufacture handles for other attempts.
public struct JourneyAttempt: Hashable, Sendable {
    public let id: UUID
    public let type: String
    fileprivate let owner: UUID
}

public enum JourneyUpdateResult: Equatable, Sendable {
    /// Accepted by the coordinator, not a Firebase delivery acknowledgement.
    case accepted
    /// Already finished/forgotten, or owned by another coordinator.
    case inactive
}

public struct JourneyRecordingIssue: Sendable {
    public enum Channel: Sendable { case analytics, diagnostics }
    public let attempt: JourneyAttempt
    public let channel: Channel
}

/// All transitions and reporter calls are synchronous on MainActor. No suspension
/// point can interleave a duplicate terminal with its state update.
@MainActor public final class JourneyCoordinator {
    private struct State {
        let definition: JourneyDefinition
        var stage: String
        var parameters: [String: String]
    }
    private let owner = UUID()
    private var active: [UUID: State] = [:]
    private let reporter: any JourneyReporting
    private let diagnosticReporter: (any JourneyDiagnosticReporting)?
    private let onRecordingIssue: (@MainActor (JourneyRecordingIssue) -> Void)?

    public var activeAttemptCount: Int { active.count }

    public init(
        reporter: any JourneyReporting,
        diagnosticReporter: (any JourneyDiagnosticReporting)? = nil,
        onRecordingIssue: (@MainActor (JourneyRecordingIssue) -> Void)? = nil
    ) {
        self.reporter = reporter
        self.diagnosticReporter = diagnosticReporter
        self.onRecordingIssue = onRecordingIssue
    }

    @discardableResult public func start(
        _ definition: JourneyDefinition,
        parameters: [String: String] = [:]
    ) throws -> JourneyAttempt {
        try definition.validate(parameters)
        let attempt = JourneyAttempt(id: UUID(), type: definition.type, owner: owner)
        active[attempt.id] = State(definition: definition, stage: definition.initialStage, parameters: parameters)
        emit(event(.started, attempt, parameters), for: attempt)
        return attempt
    }

    @discardableResult public func advance(
        _ attempt: JourneyAttempt, to stage: String,
        parameters: [String: String] = [:], correlation: JourneyCorrelation? = nil
    ) throws -> JourneyUpdateResult {
        guard var state = state(for: attempt) else { return .inactive }
        try state.definition.validate(parameters)
        try state.definition.validateTransition(from: state.stage, to: stage)
        state.stage = stage
        state.parameters.merge(parameters) { _, new in new }
        active[attempt.id] = state
        var fields = state.parameters
        fields["etapa_jornada"] = stage
        fields.merge(correlation?.parameters ?? [:]) { _, new in new }
        emit(event(.stage, attempt, fields), for: attempt)
        return .accepted
    }

    @discardableResult public func complete(
        _ attempt: JourneyAttempt, at stage: String,
        parameters: [String: String] = [:], correlation: JourneyCorrelation? = nil
    ) throws -> JourneyUpdateResult {
        guard let state = state(for: attempt) else { return .inactive }
        guard state.definition.completionStages.contains(stage) else {
            throw JourneyValidationError.invalidTransition
        }
        return try finish(attempt, state: state, name: .completed, stage: stage,
                          fields: ["resultado": "sucesso"], parameters: parameters, correlation: correlation)
    }

    @discardableResult public func fail(
        _ attempt: JourneyAttempt, at stage: String, category: JourneyErrorCategory,
        code: String? = nil, reporting: JourneyFailureReporting = .functionalOnly,
        parameters: [String: String] = [:], correlation: JourneyCorrelation? = nil
    ) throws -> JourneyUpdateResult {
        guard let state = state(for: attempt) else { return .inactive }
        if let code, !state.definition.errorCodes.contains(code) {
            throw JourneyValidationError.valueNotAllowed
        }
        var fields = ["resultado": "falha", "etapa_falha": stage, "categoria_erro": category.rawValue]
        if let code { fields["codigo_erro"] = code }
        return try finish(attempt, state: state, name: .failed, stage: stage,
                          fields: fields, parameters: parameters, correlation: correlation,
                          technical: reporting == .reportableTechnical)
    }

    @discardableResult public func cancel(
        _ attempt: JourneyAttempt, reason: String? = nil,
        parameters: [String: String] = [:]
    ) throws -> JourneyUpdateResult {
        guard let state = state(for: attempt) else { return .inactive }
        if let reason, !state.definition.cancellationReasons.contains(reason) {
            throw JourneyValidationError.valueNotAllowed
        }
        var fields = ["resultado": "cancelado", "etapa_jornada": state.stage]
        if let reason { fields["motivo_cancelamento"] = reason }
        return try finish(attempt, state: state, name: .cancelled, stage: state.stage,
                          fields: fields, parameters: parameters, correlation: nil)
    }

    /// Release lost context without claiming a result, cancellation or abandonment.
    @discardableResult public func forget(_ attempt: JourneyAttempt) -> JourneyUpdateResult {
        guard state(for: attempt) != nil else { return .inactive }
        active.removeValue(forKey: attempt.id)
        return .accepted
    }

    private func state(for attempt: JourneyAttempt) -> State? {
        guard attempt.owner == owner else { return nil }
        return active[attempt.id]
    }

    private func finish(
        _ attempt: JourneyAttempt, state: State, name: JourneyEventName, stage: String,
        fields: [String: String], parameters: [String: String], correlation: JourneyCorrelation?,
        technical: Bool = false
    ) throws -> JourneyUpdateResult {
        try state.definition.validate(parameters)
        try state.definition.validateTransition(from: state.stage, to: stage)
        var all = state.parameters.merging(parameters) { _, new in new }
        all.merge(fields) { _, new in new }
        all.merge(correlation?.parameters ?? [:]) { _, new in new }
        let terminal = event(name, attempt, all)
        // Commit first, including when a reporter synchronously calls back into us.
        active.removeValue(forKey: attempt.id)
        emit(terminal, for: attempt)
        if technical, let diagnosticReporter {
            // No business dimensions or global Crashlytics context are attached.
            let keys: Set<String> = ["id_jornada", "tipo_jornada", "versao_contrato", "etapa_falha",
                                     "categoria_erro", "codigo_erro", "id_requisicao", "id_trace"]
            let diagnostic = JourneyDiagnostic(parameters: terminal.parameters.filter { keys.contains($0.key) })
            do { try diagnosticReporter.record(diagnostic) }
            catch { onRecordingIssue?(JourneyRecordingIssue(attempt: attempt, channel: .diagnostics)) }
        }
        return .accepted
    }

    private func event(_ name: JourneyEventName, _ attempt: JourneyAttempt, _ fields: [String: String]) -> JourneyEvent {
        var parameters = fields
        parameters["id_jornada"] = attempt.id.uuidString.lowercased()
        parameters["tipo_jornada"] = attempt.type
        parameters["versao_contrato"] = JourneyEvent.contractVersion
        return JourneyEvent(name: name, parameters: parameters)
    }

    private func emit(_ event: JourneyEvent, for attempt: JourneyAttempt) {
        do { try reporter.record(event) }
        catch { onRecordingIssue?(JourneyRecordingIssue(attempt: attempt, channel: .analytics)) }
    }
}
