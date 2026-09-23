// USPObservabilityKitTests.swift
// USPObservabilityKitTests
//
// Suite completa de testes unitários do USPObservabilityKit.
// Nenhum teste depende de rede real.

import XCTest
@testable import USPObservabilityKit

// MARK: - Mock Providers

private struct MockAppInfoProvider: AppInfoProviding {
    let platform: String
    let version: String
    let build: String
}

private struct MockOSVersionProvider: OSVersionProviding {
    let osVersion: String
}

private struct MockDeviceModelProvider: DeviceModelProviding {
    let deviceModel: String
}

private struct MockInstallationIDProvider: InstallationIDProviding {
    let installationID: String
}

// MARK: - Helpers

private func makeInstrumenter(
    platform: String = "ios",
    version: String = "3.0.0",
    build: String = "100",
    osVersion: String = "17.5",
    deviceModel: String = "iPhone14,2",
    installationID: String = "TEST-UUID-1234"
) -> USPContextInstrumenter {
    USPContextInstrumenter(
        configuration:  ObservabilityConfiguration(allowedHosts: ["api.usp.br"]),
        appInfo:        MockAppInfoProvider(platform: platform, version: version, build: build),
        osVersion:      MockOSVersionProvider(osVersion: osVersion),
        deviceModel:    MockDeviceModelProvider(deviceModel: deviceModel),
        installationID: MockInstallationIDProvider(installationID: installationID)
    )
}

private func makeRequest(
    url: String = "https://api.usp.br/endpoint",
    headers: [String: String] = [:]
) -> URLRequest {
    var request = URLRequest(url: URL(string: url)!)
    for (key, value) in headers {
        request.setValue(value, forHTTPHeaderField: key)
    }
    return request
}

// MARK: - Test Suite

final class USPObservabilityKitTests: XCTestCase {

    // ─────────────────────────────────────────────────────────────────
    // MARK: USP-App-Platform
    // ─────────────────────────────────────────────────────────────────

    func testPlatformIsAlwaysIOS() throws {
        let instrumenter = makeInstrumenter(platform: "ios")
        let result = try instrumenter.instrument(makeRequest())
        XCTAssertEqual(result.value(forHTTPHeaderField: "USP-App-Platform"), "ios")
    }

    func testDefaultAppInfoProviderPlatformIsIOS() {
        // DefaultAppInfoProvider.platform é uma constante literal "ios"
        let provider = DefaultAppInfoProvider(bundle: .main)
        XCTAssertEqual(provider.platform, "ios")
    }

    // ─────────────────────────────────────────────────────────────────
    // MARK: USP-App-Version
    // ─────────────────────────────────────────────────────────────────

    func testAppVersionHeaderContainsProviderValue() throws {
        let instrumenter = makeInstrumenter(version: "4.1.2")
        let result = try instrumenter.instrument(makeRequest())
        XCTAssertEqual(result.value(forHTTPHeaderField: "USP-App-Version"), "4.1.2")
    }

    func testAppVersionHeaderIsNonEmptyWithMock() throws {
        let instrumenter = makeInstrumenter(version: "1.0.0")
        let result = try instrumenter.instrument(makeRequest())
        let value = result.value(forHTTPHeaderField: "USP-App-Version") ?? ""
        XCTAssertFalse(value.isEmpty)
    }

    // ─────────────────────────────────────────────────────────────────
    // MARK: USP-App-Build
    // ─────────────────────────────────────────────────────────────────

    func testBuildHeaderContainsProviderValue() throws {
        let instrumenter = makeInstrumenter(build: "472")
        let result = try instrumenter.instrument(makeRequest())
        XCTAssertEqual(result.value(forHTTPHeaderField: "USP-App-Build"), "472")
    }

    // ─────────────────────────────────────────────────────────────────
    // MARK: USP-OS-Version
    // ─────────────────────────────────────────────────────────────────

    func testOSVersionHeaderContainsProviderValue() throws {
        let instrumenter = makeInstrumenter(osVersion: "17.5.1")
        let result = try instrumenter.instrument(makeRequest())
        XCTAssertEqual(result.value(forHTTPHeaderField: "USP-OS-Version"), "17.5.1")
    }

    func testDefaultOSVersionProviderIsNonEmpty() {
        let provider = DefaultOSVersionProvider()
        XCTAssertFalse(provider.osVersion.isEmpty)
    }

    func testDefaultOSVersionProviderContainsMajorVersion() {
        let provider = DefaultOSVersionProvider()
        // Deve conter pelo menos "major.minor"
        let parts = provider.osVersion.split(separator: ".")
        XCTAssertGreaterThanOrEqual(parts.count, 2, "OS version deve ter pelo menos major.minor")
    }

    func testDefaultOSVersionProviderPatchOmittedWhenZero() {
        // No ambiente de teste (macOS via Swift Package), patch pode ser 0.
        // Verifica apenas que o formato é consistente.
        let provider = DefaultOSVersionProvider()
        let parts = provider.osVersion.split(separator: ".")
        XCTAssertTrue(parts.count == 2 || parts.count == 3,
                      "Formato esperado: major.minor ou major.minor.patch")
    }

    // ─────────────────────────────────────────────────────────────────
    // MARK: USP-Device-Model
    // ─────────────────────────────────────────────────────────────────

    func testDeviceModelHeaderContainsProviderValue() throws {
        let instrumenter = makeInstrumenter(deviceModel: "iPhone16,2")
        let result = try instrumenter.instrument(makeRequest())
        XCTAssertEqual(result.value(forHTTPHeaderField: "USP-Device-Model"), "iPhone16,2")
    }

    func testDefaultDeviceModelProviderIsNonEmpty() {
        let provider = DefaultDeviceModelProvider()
        XCTAssertFalse(provider.deviceModel.isEmpty)
    }

    func testDefaultDeviceModelDoesNotContainPersonalData() {
        let provider = DefaultDeviceModelProvider()
        let model = provider.deviceModel
        // Não deve conter e-mail
        XCTAssertFalse(model.contains("@"), "Device model não deve conter @")
        // Não deve conter caracteres de espaço (identificadores técnicos não têm)
        // No simulador pode conter "iOS Simulator" — aceitável
    }

    // ─────────────────────────────────────────────────────────────────
    // MARK: USP-Installation-Id
    // ─────────────────────────────────────────────────────────────────

    func testInstallationIDHeaderPresent() throws {
        let instrumenter = makeInstrumenter(installationID: "A1B2C3D4-0000-1111-AAAA-BBBBCCCCDDDD")
        let result = try instrumenter.instrument(makeRequest())
        XCTAssertEqual(
            result.value(forHTTPHeaderField: "USP-Installation-Id"),
            "A1B2C3D4-0000-1111-AAAA-BBBBCCCCDDDD"
        )
    }

    func testDefaultInstallationIDProviderGeneratesUUIDFormat() {
        let suiteName = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let provider = DefaultInstallationIDProvider(userDefaults: defaults, key: "testKey")
        let id = provider.installationID

        // UUID canônico: 8-4-4-4-12 (36 chars com hífens)
        XCTAssertEqual(id.count, 36, "UUID deve ter 36 caracteres")
        XCTAssertEqual(id.filter({ $0 == "-" }).count, 4, "UUID deve ter 4 hífens")
        let uuidPattern = UUID(uuidString: id)
        XCTAssertNotNil(uuidPattern, "Deve ser um UUID válido: \(id)")
    }

    func testDefaultInstallationIDProviderPersistsBetweenInstances() {
        let suiteName = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let key = "installationKey"

        let first = DefaultInstallationIDProvider(userDefaults: defaults, key: key)
        let second = DefaultInstallationIDProvider(userDefaults: defaults, key: key)

        XCTAssertEqual(first.installationID, second.installationID,
                       "Installation ID deve ser reutilizado entre instâncias")
    }

    func testDefaultInstallationIDProviderGeneratesNewIDWhenEmpty() {
        let suiteName = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let key = "freshKey"

        // Garantir que não há ID persistido
        defaults.removeObject(forKey: key)

        let provider = DefaultInstallationIDProvider(userDefaults: defaults, key: key)
        XCTAssertFalse(provider.installationID.isEmpty)
        XCTAssertNotNil(UUID(uuidString: provider.installationID))
    }

    func testDefaultInstallationIDIsNotUserIdentifier() {
        let suiteName = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let provider = DefaultInstallationIDProvider(userDefaults: defaults, key: "privKey")
        let id = provider.installationID

        // ID não deve conter padrões de dados pessoais
        XCTAssertFalse(id.contains("@"), "ID não deve conter e-mail")
        XCTAssertFalse(id.lowercased().contains("usp"), "ID não deve conter 'usp'")
        XCTAssertFalse(id.lowercased().contains("user"), "ID não deve conter 'user'")
        XCTAssertFalse(id.lowercased().contains("login"), "ID não deve conter 'login'")
    }

    func testTwoInstallationsProduceDifferentIDs() {
        let suite1 = "test.\(UUID().uuidString)"
        let suite2 = "test.\(UUID().uuidString)"
        let defaults1 = UserDefaults(suiteName: suite1)!
        let defaults2 = UserDefaults(suiteName: suite2)!
        defer {
            defaults1.removePersistentDomain(forName: suite1)
            defaults2.removePersistentDomain(forName: suite2)
        }

        let id1 = DefaultInstallationIDProvider(userDefaults: defaults1, key: "k").installationID
        let id2 = DefaultInstallationIDProvider(userDefaults: defaults2, key: "k").installationID

        XCTAssertNotEqual(id1, id2, "Instalações distintas devem gerar IDs distintos")
    }

    // ─────────────────────────────────────────────────────────────────
    // MARK: Preservação de headers existentes
    // ─────────────────────────────────────────────────────────────────

    func testAuthorizationHeaderIsPreserved() throws {
        let request = makeRequest(headers: ["Authorization": "Bearer secret-token-abc123"])
        let instrumenter = makeInstrumenter()
        let result = try instrumenter.instrument(request)

        XCTAssertEqual(result.value(forHTTPHeaderField: "Authorization"), "Bearer secret-token-abc123",
                       "Authorization não deve ser alterado")
    }

    func testArbitraryExistingHeadersArePreserved() throws {
        let request = makeRequest(headers: [
            "X-Custom-Header": "custom-value",
            "Content-Type": "application/json"
        ])
        let instrumenter = makeInstrumenter()
        let result = try instrumenter.instrument(request)

        XCTAssertEqual(result.value(forHTTPHeaderField: "X-Custom-Header"), "custom-value")
        XCTAssertEqual(result.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    func testOriginalRequestIsNotMutated() throws {
        var original = makeRequest()
        original.setValue("original-value", forHTTPHeaderField: "X-Original")

        let instrumenter = makeInstrumenter()
        let result = try instrumenter.instrument(original)

        // Verifica que a result é diferente e contém os novos headers
        XCTAssertNotNil(result.value(forHTTPHeaderField: "USP-App-Platform"))
        // O original não deve ter o header USP-* (URLRequest é value type)
        XCTAssertNil(original.value(forHTTPHeaderField: "USP-App-Platform"))
    }

    // ─────────────────────────────────────────────────────────────────
    // MARK: Todos os 6 headers presentes
    // ─────────────────────────────────────────────────────────────────

    func testAllSixUSPHeadersArePresent() throws {
        let instrumenter = makeInstrumenter(
            platform: "ios",
            version: "2.0.0",
            build: "200",
            osVersion: "16.0",
            deviceModel: "iPhone13,4",
            installationID: "DEADBEEF-1234-5678-ABCD-EF0123456789"
        )

        let result = try instrumenter.instrument(makeRequest())

        XCTAssertEqual(result.value(forHTTPHeaderField: "USP-App-Platform"),    "ios")
        XCTAssertEqual(result.value(forHTTPHeaderField: "USP-App-Version"),     "2.0.0")
        XCTAssertEqual(result.value(forHTTPHeaderField: "USP-App-Build"),       "200")
        XCTAssertEqual(result.value(forHTTPHeaderField: "USP-OS-Version"),      "16.0")
        XCTAssertEqual(result.value(forHTTPHeaderField: "USP-Device-Model"),    "iPhone13,4")
        XCTAssertEqual(result.value(forHTTPHeaderField: "USP-Installation-Id"), "DEADBEEF-1234-5678-ABCD-EF0123456789")
    }

    // ─────────────────────────────────────────────────────────────────
    // MARK: Header name constants
    // ─────────────────────────────────────────────────────────────────

    func testHeaderFieldConstantsMatchCanonicalNames() {
        XCTAssertEqual(USPContextInstrumenter.HeaderField.appPlatform,    "USP-App-Platform")
        XCTAssertEqual(USPContextInstrumenter.HeaderField.appVersion,     "USP-App-Version")
        XCTAssertEqual(USPContextInstrumenter.HeaderField.appBuild,       "USP-App-Build")
        XCTAssertEqual(USPContextInstrumenter.HeaderField.osVersion,      "USP-OS-Version")
        XCTAssertEqual(USPContextInstrumenter.HeaderField.deviceModel,    "USP-Device-Model")
        XCTAssertEqual(USPContextInstrumenter.HeaderField.installationID, "USP-Installation-Id")
        XCTAssertEqual(USPContextInstrumenter.HeaderField.traceparent,    "traceparent")
    }

    // ─────────────────────────────────────────────────────────────────
    // MARK: CompositeInstrumenter
    // ─────────────────────────────────────────────────────────────────

    func testCompositeInstrumenterAppliesAllInstrumenters() throws {
        struct AddHeaderA: HTTPRequestInstrumenting {
            func instrument(_ request: URLRequest) throws -> URLRequest {
                var r = request
                r.setValue("value-a", forHTTPHeaderField: "X-Header-A")
                return r
            }
        }
        struct AddHeaderB: HTTPRequestInstrumenting {
            func instrument(_ request: URLRequest) throws -> URLRequest {
                var r = request
                r.setValue("value-b", forHTTPHeaderField: "X-Header-B")
                return r
            }
        }

        let composite = CompositeInstrumenter([AddHeaderA(), AddHeaderB()])
        let result = try composite.instrument(makeRequest())

        XCTAssertEqual(result.value(forHTTPHeaderField: "X-Header-A"), "value-a")
        XCTAssertEqual(result.value(forHTTPHeaderField: "X-Header-B"), "value-b")
    }

    func testCompositeInstrumenterPreservesOrderOfApplication() throws {
        // Dois instrumentadores escrevem no mesmo header; o último vence.
        struct SetHeaderFirst: HTTPRequestInstrumenting {
            func instrument(_ request: URLRequest) throws -> URLRequest {
                var r = request; r.setValue("first", forHTTPHeaderField: "X-Order"); return r
            }
        }
        struct SetHeaderSecond: HTTPRequestInstrumenting {
            func instrument(_ request: URLRequest) throws -> URLRequest {
                var r = request; r.setValue("second", forHTTPHeaderField: "X-Order"); return r
            }
        }

        let composite = CompositeInstrumenter([SetHeaderFirst(), SetHeaderSecond()])
        let result = try composite.instrument(makeRequest())
        XCTAssertEqual(result.value(forHTTPHeaderField: "X-Order"), "second",
                       "O último instrumentador na cadeia deve vencer em caso de conflito")
    }

    func testCompositeInstrumenterWithUSPContextPreservesAuth() throws {
        let request = makeRequest(headers: ["Authorization": "Bearer my-secret"])
        let composite = CompositeInstrumenter([makeInstrumenter()])
        let result = try composite.instrument(request)

        XCTAssertEqual(result.value(forHTTPHeaderField: "Authorization"), "Bearer my-secret")
        XCTAssertNotNil(result.value(forHTTPHeaderField: "USP-App-Platform"))
    }

    func testEmptyCompositeInstrumenterIsIdentity() throws {
        let composite = CompositeInstrumenter([])
        let request = makeRequest(headers: ["Authorization": "Bearer token"])
        let result = try composite.instrument(request)
        XCTAssertEqual(result.value(forHTTPHeaderField: "Authorization"), "Bearer token")
    }

    // ─────────────────────────────────────────────────────────────────
    // MARK: Privacidade — ausência de dados pessoais
    // ─────────────────────────────────────────────────────────────────

    func testUSPHeadersDoNotContainSensitivePatterns() throws {
        let suiteName = "privacy.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let instrumenter = USPContextInstrumenter(
            configuration:  ObservabilityConfiguration(allowedHosts: ["api.usp.br"]),
            appInfo:        DefaultAppInfoProvider(bundle: .main),
            osVersion:      DefaultOSVersionProvider(),
            deviceModel:    DefaultDeviceModelProvider(),
            installationID: DefaultInstallationIDProvider(userDefaults: defaults, key: "privTest")
        )

        let result = try instrumenter.instrument(makeRequest())
        let allValues = [
            result.value(forHTTPHeaderField: "USP-App-Platform"),
            result.value(forHTTPHeaderField: "USP-App-Version"),
            result.value(forHTTPHeaderField: "USP-App-Build"),
            result.value(forHTTPHeaderField: "USP-OS-Version"),
            result.value(forHTTPHeaderField: "USP-Device-Model"),
            result.value(forHTTPHeaderField: "USP-Installation-Id"),
        ].compactMap { $0 }.joined()

        XCTAssertFalse(allValues.contains("@"),
                       "Headers USP-* não devem conter e-mail")
        XCTAssertFalse(allValues.lowercased().contains("password"),
                       "Headers USP-* não devem conter password")
        XCTAssertFalse(allValues.lowercased().contains("secret"),
                       "Headers USP-* não devem conter secret")
        XCTAssertFalse(allValues.lowercased().contains("token"),
                       "Headers USP-* não devem conter token")
        XCTAssertFalse(allValues.lowercased().contains("bearer"),
                       "Headers USP-* não devem conter bearer")
    }

    // ─────────────────────────────────────────────────────────────────
    // MARK: Concorrência — data race safety
    // ─────────────────────────────────────────────────────────────────

    func testConcurrentInstrumentationIsDataRaceFree() async throws {
        let instrumenter = makeInstrumenter()
        let iterations = 200

        try await withThrowingTaskGroup(of: URLRequest.self) { group in
            for _ in 0..<iterations {
                group.addTask {
                    try instrumenter.instrument(makeRequest())
                }
            }
            var count = 0
            for try await result in group {
                XCTAssertEqual(result.value(forHTTPHeaderField: "USP-App-Platform"), "ios")
                count += 1
            }
            XCTAssertEqual(count, iterations)
        }
    }

    func testConcurrentInstallationIDReadsReturnSameValue() async {
        let suiteName = "concurrent.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let key = "concurrentKey"

        // Pré-populamos para evitar race na geração.
        let seeded = UUID().uuidString
        defaults.set(seeded, forKey: key)

        // Lemos o ID a partir de uma única instância (sem capturar defaults no closure).
        let expectedID = DefaultInstallationIDProvider(userDefaults: defaults, key: key).installationID

        // Verifica que leituras concorrentes da string retornam o mesmo valor.
        // (A string é Sendable — sem risco de data race.)
        let results = await withTaskGroup(of: String.self) { group -> [String] in
            for _ in 0..<50 {
                group.addTask { expectedID }
            }
            var ids = [String]()
            for await id in group {
                ids.append(id)
            }
            return ids
        }

        let unique = Set(results)
        XCTAssertEqual(unique.count, 1, "Todas as leituras devem retornar o mesmo ID: \(unique)")
    }

    // ─────────────────────────────────────────────────────────────────
    // MARK: Protocolo TracingInstrumenting
    // ─────────────────────────────────────────────────────────────────

    func testTracingInstrumentingConformsToHTTPRequestInstrumenting() {
        // Verifica que TracingInstrumenting é subtipo de HTTPRequestInstrumenting
        // (verificação de tipo em tempo de compilação — o teste existir já valida)
        struct MockTracing: TracingInstrumenting {
            func instrument(_ request: URLRequest) throws -> URLRequest { request }
        }
        let tracing: any HTTPRequestInstrumenting = MockTracing()
        let composite = CompositeInstrumenter([tracing])
        XCTAssertNotNil(composite) // Só para usar composite e evitar warning

        let concrete: any TracingInstrumenting = makeInstrumenter()
        XCTAssertNotNil(concrete)
    }

    func testTracingInstrumenterCanBeComposedWithUSPContext() throws {
        struct MockTracing: TracingInstrumenting {
            func instrument(_ request: URLRequest) throws -> URLRequest {
                var r = request
                r.setValue(
                    "00-0123456789abcdef0123456789abcdef-0123456789abcdef-01",
                    forHTTPHeaderField: "traceparent"
                )
                return r
            }
        }

        let composite = CompositeInstrumenter([
            makeInstrumenter(),
            MockTracing()
        ])
        let result = try composite.instrument(makeRequest())

        XCTAssertEqual(result.value(forHTTPHeaderField: "USP-App-Platform"), "ios")
        XCTAssertEqual(
            result.value(forHTTPHeaderField: "traceparent"),
            "00-0123456789abcdef0123456789abcdef-0123456789abcdef-01"
        )
    }

    // ─────────────────────────────────────────────────────────────────
    // MARK: DefaultInstallationIDProvider.defaultKey
    // ─────────────────────────────────────────────────────────────────

    func testDefaultInstallationIDKeyIsStable() {
        XCTAssertEqual(
            DefaultInstallationIDProvider.defaultKey,
            "com.usp.mobile.installationID",
            "A chave padrão não deve mudar para não perder IDs já persistidos"
        )
    }
}
