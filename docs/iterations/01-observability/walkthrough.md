# USPMobileKit — Iteração 1: Walkthrough

## 1. Arquitetura anterior

```
Package "USPAuthKit"
│
├── Product:  USPAuthKit (library)
│   └── Target: USPAuthKit (ObjC/C)
│
└── Target: USPAuthKitTests (Swift)
```

**Características**: 1 product, 0 dependências externas, iOS 12+, ObjC+C, testes only em Swift.

---

## 2. Arquitetura resultante

```
Package "USPMobileKit"
│
├── Product: USPAuthKit ──────────────────────▶  Target: USPAuthKit (ObjC/C)
│                                                  └─ sem dependências externas
│                                                  └─ API pública intacta (zero breaking change)
│
└── Product: USPObservabilityKit ────────────▶  Target: USPObservabilityKit (Swift 6)
                                                   └─ sem dependências externas
                                                   └─ sem dependência de USPAuthKit

                   ┌─────────── futuros ───────────┐
                   │                               │
  (Iteração 2)     │   USPObservabilityOpenTelemetry │
  (Iteração 3)     │   USPObservabilityFirebase     │
                   └───────────────────────────────┘
```

**USPAuthKit e USPObservabilityKit não se conhecem. Podem coexistir sem acoplamento.**

---

## 3. Árvore de arquivos

```
USPMobileKit/                              ← repositório (era USPAuthKit)
│
├── Package.swift                          ← MODIFICADO
├── README.md                             ← MODIFICADO
│
├── Sources/
│   ├── USPAuthKit/                        ← inalterado
│   │   ├── Adapters/
│   │   │   ├── USPAuthKitMutableURLRequest.h/.m
│   │   │   └── USPAuthService.m
│   │   ├── Core/
│   │   │   ├── Base64Transcoder.c/.h
│   │   │   ├── HTTPClient.h/.m
│   │   │   ├── KeychainItemWrapper.h/.m
│   │   │   ├── NSString+URLEncoding.h/.m
│   │   │   ├── OAuth1Controller.h/.m
│   │   │   ├── OAuthConfig.h
│   │   │   ├── USPAuthConfig.m
│   │   │   ├── USPAuthSessionStore.h/.m
│   │   │   ├── USPAuthUser.m
│   │   │   ├── USPAuthVinculo.m
│   │   │   ├── hmac.c/.h
│   │   │   └── sha1.c/.h
│   │   ├── UI/
│   │   │   └── LoginWebViewController.h/.m
│   │   └── include/                      ← API pública (todos preservados)
│   │       ├── USPAuthKit.h
│   │       ├── USPAuthService.h
│   │       ├── USPAuthUser.h
│   │       ├── USPAuthVinculo.h
│   │       └── USPAuthConfig.h
│   │
│   └── USPObservabilityKit/               ← NOVO
│       ├── HTTPRequestInstrumenting.swift
│       ├── CompositeInstrumenter.swift
│       ├── USPContextInstrumenter.swift
│       ├── TracingInstrumenting.swift
│       └── Providers/
│           ├── AppInfoProviding.swift
│           ├── OSVersionProviding.swift
│           ├── DeviceModelProviding.swift
│           └── InstallationIDProviding.swift
│
└── Tests/
    ├── USPAuthKitTests/
    │   └── USPAuthKitTests.swift          ← inalterado (5 testes)
    └── USPObservabilityKitTests/          ← NOVO
        └── USPObservabilityKitTests.swift ← 33 testes
    └── USPMobileKitCompatibilityTests/    ← NOVO
        └── USPMobileKitCompatibilityTests.swift ← consumidor com ambos os products
```

---

## 4. Products e Targets SPM

```swift
products: [
    .library(name: "USPAuthKit",          targets: ["USPAuthKit"]),
    .library(name: "USPObservabilityKit", targets: ["USPObservabilityKit"]),
]
```

| Product | Target | Linguagem | iOS mín. | Deps externas |
|---|---|---|---|---|
| `USPAuthKit` | `USPAuthKit` | ObjC/C | 14+ | Nenhuma |
| `USPObservabilityKit` | `USPObservabilityKit` | Swift 6 | 14+ | Nenhuma |

---

## 5. Dependências entre targets

```
USPAuthKit              USPObservabilityKit
    │                          │
    │   (sem dependência)      │
    └──────────────────────────┘
         coexistem, mas independentes
```

```
USPObservabilityKitTests ──────▶  USPObservabilityKit
USPAuthKitTests          ──────▶  USPAuthKit
```

---

## 6. Dependências externas

**Nenhuma.** O package continua com zero dependências SPM externas.

---

## 7. Alterações no USPAuthKit

**Nenhuma alteração nos arquivos fonte.** As mudanças no `Package.swift` são:

- `name: "USPAuthKit"` → `name: "USPMobileKit"` (não-breaking: consumers resolvem por URL + product name)
- O product `USPAuthKit` e o target `USPAuthKit` permanecem com os mesmos nomes
- A versão mínima de iOS foi ajustada de `v12` para `v14`, decisão aprovada para esta evolução. Consumidores que ainda suportam iOS 12/13 devem elevar seu deployment target antes de atualizar.

---

## 8. Implementação do USPObservabilityKit

### Protocolo central

```swift
public protocol HTTPRequestInstrumenting: Sendable {
    func instrument(_ request: URLRequest) throws -> URLRequest
}
```

### Instrumentador principal

`USPContextInstrumenter` adiciona os 6 headers `USP-*` via providers injetáveis:

```
USP-App-Platform    = "ios"
USP-App-Version     = CFBundleShortVersionString
USP-App-Build       = CFBundleVersion
USP-OS-Version      = ProcessInfo.operatingSystemVersion (ex: "17.5")
USP-Device-Model    = sysctlbyname("hw.machine") (ex: "iPhone14,2")
USP-Installation-Id = UUID pseudônimo persistido em UserDefaults
```

### Composição

```swift
public struct CompositeInstrumenter: HTTPRequestInstrumenting {
    // Aplica instrumentadores em sequência (reduce)
}
```

### Providers

| Provider | Protocolo | Implementação padrão |
|---|---|---|
| App info | `AppInfoProviding` | `DefaultAppInfoProvider` — lê Info.plist no init |
| OS version | `OSVersionProviding` | `DefaultOSVersionProvider` — ProcessInfo, thread-safe |
| Device model | `DeviceModelProviding` | `DefaultDeviceModelProvider` — sysctlbyname/SIMULATOR_MODEL_IDENTIFIER |
| Installation ID | `InstallationIDProviding` | `DefaultInstallationIDProvider` — UUID em UserDefaults |

Todos os providers: **structs imutáveis, `Sendable` nativo, sem @MainActor**.

### Ponto de extensão (Iteração 2)

```swift
public protocol TracingInstrumenting: HTTPRequestInstrumenting {}
// Nenhuma implementação nesta iteração — contrato reservado para OTel
```

---

## 9. APIs públicas

### USPObservabilityKit

```swift
// Instrumentação
public protocol HTTPRequestInstrumenting: Sendable {
    func instrument(_ request: URLRequest) throws -> URLRequest
}
public protocol TracingInstrumenting: HTTPRequestInstrumenting {}

// Implementações
public struct USPContextInstrumenter: HTTPRequestInstrumenting
public struct CompositeInstrumenter: HTTPRequestInstrumenting

// Providers — protocolos
public protocol AppInfoProviding: Sendable {
    var platform: String { get }  // sempre "ios"
    var version: String  { get }
    var build: String    { get }
}
public protocol OSVersionProviding: Sendable {
    var osVersion: String { get }
}
public protocol DeviceModelProviding: Sendable {
    var deviceModel: String { get }
}
public protocol InstallationIDProviding: Sendable {
    var installationID: String { get }
}

// Providers — implementações padrão
public struct DefaultAppInfoProvider: AppInfoProviding
public struct DefaultOSVersionProvider: OSVersionProviding
public struct DefaultDeviceModelProvider: DeviceModelProviding
public struct DefaultInstallationIDProvider: InstallationIDProviding {
    public static let defaultKey: String  // "com.usp.mobile.installationID"
}

// Header names
extension USPContextInstrumenter {
    public enum HeaderField {
        public static let appPlatform:    String  // "USP-App-Platform"
        public static let appVersion:     String  // "USP-App-Version"
        public static let appBuild:       String  // "USP-App-Build"
        public static let osVersion:      String  // "USP-OS-Version"
        public static let deviceModel:    String  // "USP-Device-Model"
        public static let installationID: String  // "USP-Installation-Id"
    }
}
```

---

## 10. Testes executados e resultados

```
swift test               exit code: 0
```

### USPObservabilityKitTests — 33 testes, 0 falhas

| Grupo | Teste | Status |
|---|---|---|
| App Platform | `testPlatformIsAlwaysIOS` | ✅ |
| App Platform | `testDefaultAppInfoProviderPlatformIsIOS` | ✅ |
| App Version | `testAppVersionHeaderContainsProviderValue` | ✅ |
| App Version | `testAppVersionHeaderIsNonEmptyWithMock` | ✅ |
| Build | `testBuildHeaderContainsProviderValue` | ✅ |
| OS Version | `testOSVersionHeaderContainsProviderValue` | ✅ |
| OS Version | `testDefaultOSVersionProviderIsNonEmpty` | ✅ |
| OS Version | `testDefaultOSVersionProviderContainsMajorVersion` | ✅ |
| OS Version | `testDefaultOSVersionProviderPatchOmittedWhenZero` | ✅ |
| Device Model | `testDeviceModelHeaderContainsProviderValue` | ✅ |
| Device Model | `testDefaultDeviceModelProviderIsNonEmpty` | ✅ |
| Device Model | `testDefaultDeviceModelDoesNotContainPersonalData` | ✅ |
| Installation ID | `testInstallationIDHeaderPresent` | ✅ |
| Installation ID | `testDefaultInstallationIDProviderGeneratesUUIDFormat` | ✅ |
| Installation ID | `testDefaultInstallationIDProviderPersistsBetweenInstances` | ✅ |
| Installation ID | `testDefaultInstallationIDProviderGeneratesNewIDWhenEmpty` | ✅ |
| Installation ID | `testDefaultInstallationIDIsNotUserIdentifier` | ✅ |
| Installation ID | `testTwoInstallationsProduceDifferentIDs` | ✅ |
| Installation ID | `testDefaultInstallationIDKeyIsStable` | ✅ |
| Headers | `testAllSixUSPHeadersArePresent` | ✅ |
| Headers | `testHeaderFieldConstantsMatchCanonicalNames` | ✅ |
| Preservação | `testAuthorizationHeaderIsPreserved` | ✅ |
| Preservação | `testArbitraryExistingHeadersArePreserved` | ✅ |
| Preservação | `testOriginalRequestIsNotMutated` | ✅ |
| Composite | `testCompositeInstrumenterAppliesAllInstrumenters` | ✅ |
| Composite | `testCompositeInstrumenterPreservesOrderOfApplication` | ✅ |
| Composite | `testCompositeInstrumenterWithUSPContextPreservesAuth` | ✅ |
| Composite | `testEmptyCompositeInstrumenterIsIdentity` | ✅ |
| Privacidade | `testUSPHeadersDoNotContainSensitivePatterns` | ✅ |
| Concorrência | `testConcurrentInstrumentationIsDataRaceFree` (200 tasks) | ✅ |
| Concorrência | `testConcurrentInstallationIDReadsReturnSameValue` (50 tasks) | ✅ |
| Tracing | `testTracingInstrumentingConformsToHTTPRequestInstrumenting` | ✅ |
| Tracing | `testTracingInstrumenterCanBeComposedWithUSPContext` | ✅ |

### USPAuthKitTests — 5 testes, 0 falhas (preservados)

| Teste | Status |
|---|---|
| `testUserMappingPreservesWSUserIDAndVinculos` | ✅ |
| `testUserMappingHandlesMissingOptionalFields` | ✅ |
| `testConfigFactoryMethodsExposeExpectedBaseURL` | ✅ |
| `testOAuthQueryParserIgnoresInvalidPairsWithoutCrashing` | ✅ |
| `testOAuthQueryParserDecodesEncodedValues` | ✅ |

Além dos testes de cada product isolado, `USPMobileKitCompatibilityTests` importa
`USPAuthKit` e `USPObservabilityKit` no mesmo consumidor, comprovando que os
dois products podem coexistir.

**Total: 39 testes, 0 falhas.**

---

## 11. Breaking Changes

**Um requisito de compatibilidade foi alterado:** o package agora exige iOS 14 ou superior. Não há mudança de assinatura ou remoção de API pública.

| Verificação | Resultado |
|---|---|
| `import USPAuthKit` continua funcionando em apps iOS 14+ | ✅ |
| Product name `USPAuthKit` preservado | ✅ |
| Todos os headers públicos de USPAuthKit inalterados | ✅ |
| URL Git canônica | `https://github.com/STI-USP/USPMobileKit.git` |
| Apps com deployment target iOS 12/13 precisam elevar para iOS 14 | ⚠️ |
| Testes de USPAuthKit todos passando | ✅ |

A mudança de `name: "USPAuthKit"` para `name: "USPMobileKit"` no `Package.swift` não afeta consumers: o SPM resolve packages por URL + product name, não por package name interno.

---

## 12. Identidade do package e rename do repositório

| Conceito | Estado final auditado |
|---|---|
| Package name SPM | `USPMobileKit` |
| Nome físico local | `USPMobileKit` |
| URL Git canônica atual | `https://github.com/STI-USP/USPMobileKit.git` |
| Product Auth | `USPAuthKit` (preservado) |

O repositório canônico já existe no GitHub e é o `origin` deste checkout. O
GitLab `authkit.git` é preservado somente como remote `legacy`, para
rastreabilidade; novas integrações devem usar a URL GitHub canônica e não
depender de redirects.

---

## 13. Estratégia de migração

| Cenário | Ação necessária | Esforço |
|---|---|---|
| App usa só `USPAuthKit` com deployment target iOS 14+ | **Nenhuma** — imports e APIs continuam iguais | Zero |
| App usa só `USPAuthKit` com deployment target iOS 12/13 | Elevar deployment target para iOS 14 | Necessário |
| App quer adicionar observabilidade | Adicionar `USPObservabilityKit` no target Xcode | ~5 min |
| App usa ambos | Adicionar `USPObservabilityKit` ao target existente | ~5 min |

---

## 14. Exemplo: app usando somente Auth

```swift
// AppDelegate.swift
import USPAuthKit
// Sem import USPObservabilityKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ app: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        USPAuthService.configure(
            withEnvironment: .prod,
            consumerKey:     "CK",
            consumerSecret:  "CS",
            appKey:          "APPKEY"
        )
        return true
    }
}

// ViewController.swift
func login() {
    USPAuthService.shared().ensureLoggedIn(from: self) { user, error in
        guard let user else { return }
        print(user.nomeUsuario)
    }
}
```

---

## 15. Exemplo: app usando somente Observabilidade

```swift
import USPObservabilityKit
// Sem import USPAuthKit

final class HTTPClient {
    private let observability: any HTTPRequestInstrumenting =
        USPContextInstrumenter()

    func get(_ url: URL) async throws -> Data {
        let request = URLRequest(url: url)
        let instrumented = try observability.instrument(request)
        let (data, _) = try await URLSession.shared.data(for: instrumented)
        return data
    }
}
```

---

## 16. Exemplo: app usando Auth + Observabilidade

```swift
import USPAuthKit
import USPObservabilityKit

// Configuração (AppDelegate / @main)
USPAuthService.configure(withEnvironment: .prod, consumerKey: "CK", consumerSecret: "CS", appKey: "APP")

// HTTPClient com observabilidade
final class APIClient {
    private let observability: any HTTPRequestInstrumenting

    init(observability: any HTTPRequestInstrumenting = USPContextInstrumenter()) {
        self.observability = observability
    }

    func request(_ url: URL) async throws -> Data {
        var req = URLRequest(url: url)

        // Auth: adiciona o token funcional
        if let wsUserId = USPAuthService.shared().currentWSUserId() {
            req.setValue(wsUserId, forHTTPHeaderField: "Authorization")
        }

        // Observabilidade: adiciona USP-* headers
        // (não conhece Auth, não acessa tokens, não altera Authorization)
        let instrumented = try observability.instrument(req)

        let (data, _) = try await URLSession.shared.data(for: instrumented)
        return data
    }
}

// Auth flow — sem conhecer observabilidade
func ensureSession(from vc: UIViewController) {
    USPAuthService.shared().ensureLoggedIn(from: vc) { user, error in
        // observability.instrument já está configurado no APIClient
        // Auth e Observability não se comunicam
    }
}
```

---

## Decisões abertas para a Iteração 2

### Escopo de `HTTPRequestInstrumenting`

`HTTPRequestInstrumenting.instrument(_:)` prepara uma `URLRequest` e injeta
contexto; ele não representa o lifecycle completo de uma operação HTTP. A ADR
da Iteração 2 deve avaliar uma API separada para o fluxo completo:

```
start span → request → URLSession → response/error → end span
```

Não presumir que um span possa ser iniciado e encerrado dentro de `instrument(_:)`:
nessa etapa ainda não existem resposta, erro nem duração da operação.

### Antes de iniciar USPObservabilityOpenTelemetry

1. **Versão do opentelemetry-swift**: qual versão mínima aceita? A API de `Tracer`/`Span` foi estabilizada na 1.x. Confirmar versão compatível com iOS 14+.

2. **Inicialização do Tracer**: quem é responsável por criar e configurar o `TracerProvider`? O app? Um inicializador do módulo? Isso define a API pública de `OTelTracingInstrumenter`.

3. **Propagador de contexto**: W3C `traceparent` é o padrão, mas o `opentelemetry-swift` suporta também B3. Usar exclusivamente W3C?

4. **Contexto de span por request**: `URLSession` não suporta contexto de span nativo. O span será criado e finalizado dentro do `instrument()` (sem lifetime management) ou o app precisará gerenciar o ciclo de vida?

5. **Exportador**: o módulo deve incluir um exportador padrão (OTLP/gRPC) ou deixar para o app configurar? Manter o módulo sem opinião sobre exportador é mais correto arquiteturalmente.

### Recomendação antes da Iteração 2

Abrir uma ADR (Architecture Decision Record) respondendo os itens 2 e 4 antes de implementar, pois impactam diretamente a API pública do `USPObservabilityOpenTelemetry`.
