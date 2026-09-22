// USPContextInstrumenter.swift
// USPObservabilityKit
//
// Implementação do Mobile API Observability Contract — lado cliente iOS.
//
// Headers adicionados:
//
//   USP-App-Platform    → "ios"
//   USP-App-Version     → CFBundleShortVersionString
//   USP-App-Build       → CFBundleVersion
//   USP-OS-Version      → versão do iOS (ex.: "17.5")
//   USP-Device-Model    → identificador técnico (ex.: "iPhone14,2")
//   USP-Installation-Id → UUID pseudônimo da instalação
//
// Privacidade e segurança:
//   ✗ Não adiciona Authorization nem qualquer token
//   ✗ Não modifica headers existentes na request
//   ✗ Não loga conteúdo dos headers
//   ✓ Todos os providers são injetáveis e testáveis

import Foundation

/// Instrumentador principal do `USPObservabilityKit`.
///
/// Adiciona os seis headers `USP-*` que compõem o Mobile API Observability Contract
/// da STI/USP, permitindo correlação de requests com contexto de plataforma e instalação.
///
/// ## Uso padrão (configuração mínima)
///
/// ```swift
/// let observability = USPContextInstrumenter()
/// let request = try observability.instrument(originalRequest)
/// ```
///
/// ## Uso com injeção de dependências
///
/// ```swift
/// let observability = USPContextInstrumenter(
///     appInfo:        DefaultAppInfoProvider(bundle: .main),
///     osVersion:      DefaultOSVersionProvider(),
///     deviceModel:    DefaultDeviceModelProvider(),
///     installationID: DefaultInstallationIDProvider()
/// )
/// ```
///
/// ## Composição com tracing (Iteração 2)
///
/// ```swift
/// let observability = CompositeInstrumenter([
///     USPContextInstrumenter(),
///     myOTelTracingInstrumenter   // USPObservabilityOpenTelemetry
/// ])
/// ```
///
/// ## Integração com HTTPClient
///
/// ```swift
/// final class HTTPClient {
///     private let observability: any HTTPRequestInstrumenting
///
///     init(observability: any HTTPRequestInstrumenting = USPContextInstrumenter()) {
///         self.observability = observability
///     }
///
///     func execute(_ request: URLRequest) async throws -> (Data, URLResponse) {
///         let instrumented = try observability.instrument(request)
///         return try await URLSession.shared.data(for: instrumented)
///     }
/// }
/// ```
public struct USPContextInstrumenter: HTTPRequestInstrumenting {

    // MARK: - Header Names

    /// Nomes canônicos dos headers USP do contrato de observabilidade.
    public enum HeaderField {
        public static let appPlatform    = "USP-App-Platform"
        public static let appVersion     = "USP-App-Version"
        public static let appBuild       = "USP-App-Build"
        public static let osVersion      = "USP-OS-Version"
        public static let deviceModel    = "USP-Device-Model"
        public static let installationID = "USP-Installation-Id"
    }

    // MARK: - Providers

    private let appInfo: any AppInfoProviding
    private let osVersionProvider: any OSVersionProviding
    private let deviceModelProvider: any DeviceModelProviding
    private let installationIDProvider: any InstallationIDProviding

    // MARK: - Init

    /// Cria um instrumentador com os providers padrão.
    ///
    /// Em testes, injete mocks via `init(appInfo:osVersion:deviceModel:installationID:)`.
    public init() {
        self.init(
            appInfo:        DefaultAppInfoProvider(),
            osVersion:      DefaultOSVersionProvider(),
            deviceModel:    DefaultDeviceModelProvider(),
            installationID: DefaultInstallationIDProvider()
        )
    }

    /// Cria um instrumentador com providers customizados.
    ///
    /// - Parameters:
    ///   - appInfo: Provider de informações do aplicativo.
    ///   - osVersion: Provider da versão do SO.
    ///   - deviceModel: Provider do modelo do dispositivo.
    ///   - installationID: Provider do identificador de instalação.
    public init(
        appInfo:        any AppInfoProviding,
        osVersion:      any OSVersionProviding,
        deviceModel:    any DeviceModelProviding,
        installationID: any InstallationIDProviding
    ) {
        self.appInfo               = appInfo
        self.osVersionProvider     = osVersion
        self.deviceModelProvider   = deviceModel
        self.installationIDProvider = installationID
    }

    // MARK: - HTTPRequestInstrumenting

    /// Adiciona os seis headers `USP-*` à request.
    ///
    /// Headers pré-existentes na request (incluindo `Authorization`) são preservados.
    /// Nenhuma informação sensível é adicionada ou logada.
    ///
    /// - Parameter request: A request original.
    /// - Returns: Cópia da request com os headers `USP-*` adicionados.
    public func instrument(_ request: URLRequest) throws -> URLRequest {
        var modified = request
        modified.setValue(appInfo.platform,               forHTTPHeaderField: HeaderField.appPlatform)
        modified.setValue(appInfo.version,                forHTTPHeaderField: HeaderField.appVersion)
        modified.setValue(appInfo.build,                  forHTTPHeaderField: HeaderField.appBuild)
        modified.setValue(osVersionProvider.osVersion,    forHTTPHeaderField: HeaderField.osVersion)
        modified.setValue(deviceModelProvider.deviceModel, forHTTPHeaderField: HeaderField.deviceModel)
        modified.setValue(installationIDProvider.installationID, forHTTPHeaderField: HeaderField.installationID)
        return modified
    }
}
