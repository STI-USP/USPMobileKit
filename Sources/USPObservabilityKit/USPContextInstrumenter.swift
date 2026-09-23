// USPContextInstrumenter.swift
// USPObservabilityKit
//
// Implementação do Mobile API Observability Contract — lado cliente iOS.
//
// Headers adicionados para hosts autorizados:
//
//   USP-App-Platform    → "ios"
//   USP-App-Version     → CFBundleShortVersionString
//   USP-App-Build       → CFBundleVersion
//   USP-OS-Version      → versão do iOS (ex.: "17.5")
//   USP-Device-Model    → identificador técnico (ex.: "iPhone14,2")
//   USP-Installation-Id → UUID pseudônimo da instalação
//   traceparent          → contexto W3C versão 00
//
// Privacidade e segurança:
//   ✗ Não adiciona Authorization nem qualquer token
//   ✓ Preserva headers existentes, inclusive traceparent válido
//   ✗ Não loga conteúdo dos headers
//   ✓ Todos os providers são injetáveis e testáveis

import Foundation

/// Instrumentador principal do `USPObservabilityKit`.
///
/// Adiciona os seis headers `USP-*` e um `traceparent` W3C somente a hosts
/// explicitamente autorizados.
///
/// ## Uso padrão (configuração mínima)
///
/// ```swift
/// let observability = USPContextInstrumenter(
///     configuration: ObservabilityConfiguration(allowedHosts: ["api.usp.br"])
/// )
/// let request = try observability.instrument(originalRequest)
/// ```
///
/// ## Uso com injeção de dependências
///
/// ```swift
/// let observability = USPContextInstrumenter(
///     configuration: ObservabilityConfiguration(allowedHosts: ["api.usp.br"]),
///     appInfo:        DefaultAppInfoProvider(bundle: .main),
///     osVersion:      DefaultOSVersionProvider(),
///     deviceModel:    DefaultDeviceModelProvider(),
///     installationID: DefaultInstallationIDProvider()
/// )
/// ```
///
/// ## Integração com HTTPClient
///
/// ```swift
/// final class HTTPClient {
///     private let observability: any HTTPRequestInstrumenting
///
///     init(observability: any HTTPRequestInstrumenting) {
///         self.observability = observability
///     }
///
///     func execute(_ request: URLRequest) async throws -> (Data, URLResponse) {
///         let instrumented = try observability.instrument(request)
///         return try await URLSession.shared.data(for: instrumented)
///     }
/// }
/// ```
public struct USPContextInstrumenter: TracingInstrumenting {

    // MARK: - Header Names

    /// Nomes canônicos dos headers USP do contrato de observabilidade.
    public enum HeaderField {
        public static let appPlatform    = "USP-App-Platform"
        public static let appVersion     = "USP-App-Version"
        public static let appBuild       = "USP-App-Build"
        public static let osVersion      = "USP-OS-Version"
        public static let deviceModel    = "USP-Device-Model"
        public static let installationID = "USP-Installation-Id"
        public static let traceparent    = "traceparent"
    }

    // MARK: - Providers

    private let appInfo: any AppInfoProviding
    private let osVersionProvider: any OSVersionProviding
    private let deviceModelProvider: any DeviceModelProviding
    private let installationIDProvider: any InstallationIDProviding
    private let configuration: ObservabilityConfiguration

    // MARK: - Init

    /// Preserva o inicializador da Iteração 1 com allowlist vazia e segura.
    public init() {
        self.init(configuration: .init(allowedHosts: []))
    }

    /// Cria um instrumentador com os providers padrão e uma allowlist explícita.
    public init(configuration: ObservabilityConfiguration) {
        self.init(
            configuration: configuration,
            appInfo:        DefaultAppInfoProvider(),
            osVersion:      DefaultOSVersionProvider(),
            deviceModel:    DefaultDeviceModelProvider(),
            installationID: DefaultInstallationIDProvider()
        )
    }

    /// Preserva o inicializador de providers da Iteração 1 com allowlist vazia.
    public init(
        appInfo:        any AppInfoProviding,
        osVersion:      any OSVersionProviding,
        deviceModel:    any DeviceModelProviding,
        installationID: any InstallationIDProviding
    ) {
        self.init(
            configuration: .init(allowedHosts: []),
            appInfo: appInfo,
            osVersion: osVersion,
            deviceModel: deviceModel,
            installationID: installationID
        )
    }

    /// Cria um instrumentador com allowlist e providers customizados.
    ///
    /// - Parameters:
    ///   - configuration: Allowlist explícita de hosts institucionais.
    ///   - appInfo: Provider de informações do aplicativo.
    ///   - osVersion: Provider da versão do SO.
    ///   - deviceModel: Provider do modelo do dispositivo.
    ///   - installationID: Provider do identificador de instalação.
    public init(
        configuration: ObservabilityConfiguration,
        appInfo:        any AppInfoProviding,
        osVersion:      any OSVersionProviding,
        deviceModel:    any DeviceModelProviding,
        installationID: any InstallationIDProviding
    ) {
        self.configuration         = configuration
        self.appInfo               = appInfo
        self.osVersionProvider     = osVersion
        self.deviceModelProvider   = deviceModel
        self.installationIDProvider = installationID
    }

    // MARK: - HTTPRequestInstrumenting

    /// Adiciona os headers de observabilidade quando o host está autorizado.
    ///
    /// Headers pré-existentes na request (incluindo `Authorization`, `Content-Type`,
    /// valores `USP-*` explícitos e `traceparent` válido) são preservados.
    ///
    /// - Parameter request: A request original.
    /// - Returns: Cópia da request instrumentada, ou a request intacta para terceiros.
    public func instrument(_ request: URLRequest) throws -> URLRequest {
        try instrumentWithTraceContext(request).request
    }

    /// Instrumenta uma nova operação lógica e devolve o trace ID sem exigir parsing.
    ///
    /// Se a request já contém um `traceparent` válido, ele é preservado. Para hosts
    /// não autorizados, a request é devolvida intacta e `traceContext` é `nil`.
    public func instrumentWithTraceContext(_ request: URLRequest) throws -> InstrumentedRequest {
        try instrumentWithTraceContext(request, context: nil)
    }

    /// Instrumenta uma request com um contexto explícito, usado principalmente em retry.
    ///
    /// O contexto fornecido prevalece sobre um `traceparent` preexistente. Crie-o com
    /// `previousContext.nextAttempt()` para preservar o trace ID e renovar o parent ID.
    public func instrumentWithTraceContext(
        _ request: URLRequest,
        context: TraceContext
    ) throws -> InstrumentedRequest {
        try instrumentWithTraceContext(request, context: Optional(context))
    }

    private func instrumentWithTraceContext(
        _ request: URLRequest,
        context explicitContext: TraceContext?
    ) throws -> InstrumentedRequest {
        guard configuration.allows(request.url) else {
            return InstrumentedRequest(request: request, traceContext: nil)
        }

        var modified = request
        modified.setValueIfAbsent(appInfo.platform, forHTTPHeaderField: HeaderField.appPlatform)
        modified.setValueIfAbsent(appInfo.version, forHTTPHeaderField: HeaderField.appVersion)
        modified.setValueIfAbsent(appInfo.build, forHTTPHeaderField: HeaderField.appBuild)
        modified.setValueIfAbsent(osVersionProvider.osVersion, forHTTPHeaderField: HeaderField.osVersion)
        modified.setValueIfAbsent(deviceModelProvider.deviceModel, forHTTPHeaderField: HeaderField.deviceModel)
        modified.setValueIfAbsent(
            installationIDProvider.installationID,
            forHTTPHeaderField: HeaderField.installationID
        )

        let context: TraceContext
        if let explicitContext {
            context = explicitContext
        } else if let existing = modified.value(forHTTPHeaderField: HeaderField.traceparent),
                  let parsed = TraceContext(traceparent: existing) {
            context = parsed
        } else {
            context = TraceContext.create()
        }

        modified.setValue(context.traceparent, forHTTPHeaderField: HeaderField.traceparent)
        return InstrumentedRequest(request: modified, traceContext: context)
    }
}

private extension URLRequest {
    mutating func setValueIfAbsent(_ value: String, forHTTPHeaderField field: String) {
        guard self.value(forHTTPHeaderField: field) == nil else { return }
        setValue(value, forHTTPHeaderField: field)
    }
}
