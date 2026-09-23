# USPMobileKit

Infraestrutura compartilhada para os aplicativos iOS da STI/USP.

O repositório hospeda **products SPM independentes** — cada aplicativo importa somente os módulos de que precisa, sem carregar dependências desnecessárias.

```
USPMobileKit
├── USPAuthKit           — autenticação OAuth 1.0a
└── USPObservabilityKit  — observabilidade (Mobile API Observability Contract)
```

Os módulos podem coexistir no mesmo app, mas **não possuem dependência entre si**. Importar `USPObservabilityKit` não requer `USPAuthKit` e vice-versa.

---

## Instalação

O nome do package é **`USPMobileKit`** e os products SPM são
**`USPAuthKit`** e **`USPObservabilityKit`**. A URL Git canônica é:

```
https://github.com/STI-USP/USPMobileKit.git
```

O GitLab legado é preservado somente como remote `legacy` para rastreabilidade.
Novas integrações devem usar a URL GitHub canônica acima.

Selecione somente o(s) product(s) necessários para o target. O product
`USPAuthKit` mantém seu nome e APIs públicas existentes.

---

## USPAuthKit

Autenticação interna via OAuth 1.0a + pós-processamento de usuário USP.

### O que faz

1. Executa OAuth 1.0a (`request_token → authorize → access_token`).
2. Obtém dados do usuário via `POST /wsusuario/oauth/usuariousp`.
3. Monta e cacheia `USPAuthUser` com vínculos institucionais.
4. Usa `wsuserid` para registrar o token no backend mobile (`/mobile/servicos/oauth/registrar`).

### Instalação

No Xcode, selecione o produto **USPAuthKit**.

### Uso rápido (Swift)

```swift
import USPAuthKit

// Configuração (uma vez, na inicialização do app)
USPAuthService.configure(
    withEnvironment: .prod,
    consumerKey:     "SEU_CONSUMER_KEY",
    consumerSecret:  "SEU_CONSUMER_SECRET",
    appKey:          "SUA_APP_KEY"
)

// Login
USPAuthService.shared().ensureLoggedIn(from: viewController) { user, error in
    guard let user, error == nil else { return }
    print("Autenticado: \(user.nomeUsuario)")
    print("Token interno: \(USPAuthService.shared().currentWSUserId() ?? "")")
}
```

### API pública principal

| Símbolo | Descrição |
|---|---|
| `USPAuthService.shared()` | Singleton do serviço em Swift (`+sharedService` em Objective-C) |
| `+configureWithEnvironment:consumerKey:consumerSecret:appKey:` | Configuração rápida |
| `+configureWithConfig:` | Configuração explícita com `USPAuthConfig` |
| `-ensureLoggedInFromViewController:completion:` | Login via WebView |
| `-currentUser` | Usuário autenticado atual (`USPAuthUser?`) |
| `-currentWSUserId` | Token funcional para APIs internas |
| `-isLoggedIn` | Verifica se há sessão válida em cache |
| `-logout` | Invalida sessão e limpa credenciais |
| `-updateNotificationToken:` | Atualiza token de push |
| `-registerTokenWithCompletion:` | Registra token no backend |
| `-invalidateTokenWithCompletion:` | Invalida token no backend |
| `-checkTokenWithCompletion:` | Consulta status do token |

### Modelos

- `USPAuthUser`: usuário autenticado com vínculos institucionais.
- `USPAuthVinculo`: vínculo de unidade/setor do usuário.
- `USPAuthConfig`: configuração de ambiente (dev / prod / custom).
- `USPAuthEnvironment`: enum `.dev`, `.prod`, `.custom`.

### Requisitos

- iOS 14+
- Sem dependências SPM externas

---

## USPObservabilityKit

Implementação iOS do **Mobile API Observability Contract** da STI/USP.

Fornece instrumentação reutilizável de `URLRequest`, adicionando contexto do app e
um `traceparent` W3C para correlacionar cada operação entre App e Backend.

O módulo **não implementa um HTTPClient**. Cada app mantém sua própria camada de networking e injeta o instrumentador.

### Instalação

No Xcode, selecione o produto **USPObservabilityKit**.

### Headers adicionados

| Header | Origem | Exemplo |
|---|---|---|
| `USP-App-Platform` | constante `"ios"` | `ios` |
| `USP-App-Version` | `CFBundleShortVersionString` | `3.2.1` |
| `USP-App-Build` | `CFBundleVersion` | `472` |
| `USP-OS-Version` | `ProcessInfo.operatingSystemVersion` | `17.5` |
| `USP-Device-Model` | `sysctlbyname("hw.machine")` | `iPhone14,2` |
| `USP-Installation-Id` | UUID pseudônimo persistido | `A3F1B2C4-…` |
| `traceparent` | contexto W3C aleatório por operação | `00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01` |

O fluxo resultante é:

```text
Feature → Repository / Service → HTTPClient → USPObservabilityKit
        → valida host → adiciona USP-App-* + traceparent → URLSession → API
```

O `trace_id` possui 16 bytes aleatórios e identifica uma operação lógica. O
`installation_id` é um UUID persistido que identifica a instalação do app. Um não
é derivado do outro e nenhum deles representa o usuário.

### Privacidade e segurança

- ✗ Nenhum dado pessoal (sem e-mail, nome, CPF, número USP)
- ✗ Sem IDFA, IDFV, serial number
- ✗ Sem user ID, número USP, token ou installation ID dentro do `traceparent`
- ✓ `Authorization`, `Content-Type` e outros headers existentes são **preservados**
- ✓ Headers de observabilidade são enviados somente para a allowlist do app
- ✓ Todos os providers são injetáveis e substituíveis em testes

### Allowlist de hosts

A configuração pertence ao app consumidor; o package não contém hosts
institucionais hardcoded:

```swift
let configuration = ObservabilityConfiguration(allowedHosts: [
    "api.usp.br",
    "cardapio.usp.br",
])
let observability = USPContextInstrumenter(configuration: configuration)
```

O matching é exato e case-insensitive. Subdomínios não são incluídos
implicitamente: autorizar `api.usp.br` não autoriza `sub.api.usp.br`, e
`api.usp.br.attacker.com` nunca corresponde. Informe cada host necessário. Schemes,
portas, paths e wildcards não são aceitos como entradas.

A allowlist padrão é vazia. Nesse caso — ou quando a URL aponta para terceiro — a
request é devolvida intacta, sem adicionar `traceparent` ou `USP-App-*` e sem erro.

### Uso mínimo

```swift
import USPObservabilityKit

let observability = USPContextInstrumenter(
    configuration: ObservabilityConfiguration(allowedHosts: ["api.usp.br"])
)

// No HTTPClient do app
let instrumented = try observability.instrument(request)
let (data, response) = try await URLSession.shared.data(for: instrumented)
```

### Integração com HTTPClient existente

```swift
import USPObservabilityKit

final class HTTPClient {
    private let observability: USPContextInstrumenter

    init(observability: USPContextInstrumenter) {
        self.observability = observability
    }

    func execute(_ request: URLRequest) async throws -> (Data, URLResponse) {
        let result = try observability.instrumentWithTraceContext(request)
        do {
            return try await URLSession.shared.data(for: result.request)
        } catch {
            // Integração do app: UI, suporte ou telemetria de uma etapa futura.
            reportNetworkFailure(error, traceID: result.traceContext?.traceID)
            throw error
        }
    }
}
```

### Recuperação do trace ID e retry

```swift
let first = try observability.instrumentWithTraceContext(request)
let traceID = first.traceContext?.traceID // UI, suporte ou integração futura

// A política de retry continua no HTTPClient do app.
if let retryContext = first.traceContext?.nextAttempt() {
    let retry = try observability.instrumentWithTraceContext(
        retryRequest,
        context: retryContext
    )
    // retry.traceContext?.traceID == traceID
    // retry.traceContext?.parentID != first.traceContext?.parentID
}
```

Cada chamada nova gera outro `trace_id`. `nextAttempt()` preserva o `trace_id` da
operação e cria outro `parent-id` para a tentativa seguinte. Se a request já contém
um `traceparent` válido, a instrumentação normal o preserva; um contexto passado
explicitamente para retry prevalece. Um `traceparent` inválido é substituído apenas
em host autorizado. Headers `USP-*` preexistentes também são preservados.

O `CompositeInstrumenter` permanece disponível para encadear outras preocupações
independentes. O `USPContextInstrumenter` já adiciona tanto `USP-*` quanto
`traceparent`, portanto não é necessário compor outro instrumentador de tracing.

### Injeção de providers customizados (testes)

```swift
struct MockAppInfo: AppInfoProviding {
    let platform = "ios"
    let version  = "1.0.0"
    let build    = "1"
}

let instrumenter = USPContextInstrumenter(
    configuration: ObservabilityConfiguration(allowedHosts: ["api.usp.br"]),
    appInfo:        MockAppInfo(),
    osVersion:      MockOSVersionProvider(osVersion: "17.0"),
    deviceModel:    MockDeviceModelProvider(deviceModel: "iPhone14,2"),
    installationID: MockInstallationIDProvider(installationID: UUID().uuidString)
)
```

### Installation ID — comportamento documentado

| Evento | Comportamento |
|---|---|
| Primeira instalação | UUID gerado e persistido em `UserDefaults` |
| Atualização do app | ID **preservado** (`UserDefaults` sobrevive) |
| Desinstalação | ID **removido** pelo SO |
| Reinstalação | Novo UUID gerado |
| Restore de backup iCloud | ID do dispositivo de origem é restaurado* |

\* Em um restore de backup, dois dispositivos podem ter o mesmo ID temporariamente. Comportamento aceitável para um identificador pseudônimo de correlação de volume. Nunca associar ao usuário autenticado. O ID permanece em `UserDefaults` deliberadamente: não usar Keychain para fazê-lo sobreviver a reinstalações.

### Protocolos públicos

```swift
// Instrumentação de request
public protocol HTTPRequestInstrumenting: Sendable {
    func instrument(_ request: URLRequest) throws -> URLRequest
}

// Ponto de extensão para W3C Trace Context (Iteração 2)
public protocol TracingInstrumenting: HTTPRequestInstrumenting {}

public struct ObservabilityConfiguration: Sendable, Equatable {
    public let allowedHosts: Set<String>
    public init(allowedHosts: [String])
}

public struct TraceContext: Sendable, Equatable {
    public let traceID: String
    public let parentID: String
    public let flags: TraceFlags
    public var traceparent: String { get }
    public static func create(flags: TraceFlags = .sampled) -> TraceContext
    public func nextAttempt() -> TraceContext
}

public struct InstrumentedRequest: Sendable {
    public let request: URLRequest
    public let traceContext: TraceContext?
}

public struct USPContextInstrumenter: TracingInstrumenting {
    // instrument(_:) -> URLRequest continua disponível.
    public func instrumentWithTraceContext(
        _ request: URLRequest
    ) throws -> InstrumentedRequest

    public func instrumentWithTraceContext(
        _ request: URLRequest,
        context: TraceContext
    ) throws -> InstrumentedRequest
}

// Providers injetáveis
public protocol AppInfoProviding: Sendable { ... }
public protocol OSVersionProviding: Sendable { ... }
public protocol DeviceModelProviding: Sendable { ... }
public protocol InstallationIDProviding: Sendable { ... }
```

### Requisitos

- iOS 14+
- Sem dependências SPM externas
- Sem Firebase ou OpenTelemetry SDK

### Limitações atuais

Esta iteração propaga apenas `traceparent` versão `00`. Ainda não há `tracestate`,
`baggage`, spans internos, sampling configurável, exporter, OTLP, Collector,
Crashlytics, Firebase Performance ou retry automático.

---

## Exemplo: app usando somente Auth

```swift
import USPAuthKit
// Sem import USPObservabilityKit

USPAuthService.configure(withEnvironment: .prod, consumerKey: "…", consumerSecret: "…", appKey: "…")
USPAuthService.shared().ensureLoggedIn(from: self) { user, _ in … }
```

## Exemplo: app usando somente Observabilidade

```swift
import USPObservabilityKit
// Sem import USPAuthKit

let observability = USPContextInstrumenter(
    configuration: ObservabilityConfiguration(allowedHosts: ["api.usp.br"])
)
let request = try observability.instrument(URLRequest(url: url))
let (data, _) = try await URLSession.shared.data(for: request)
```

## Exemplo: app usando Auth + Observabilidade

```swift
import USPAuthKit
import USPObservabilityKit

// Auth — configuração
USPAuthService.configure(withEnvironment: .prod, consumerKey: "…", consumerSecret: "…", appKey: "…")

// Observabilidade — injetada no HTTPClient
let observability = USPContextInstrumenter(
    configuration: ObservabilityConfiguration(allowedHosts: ["api.usp.br"])
)

final class APIClient {
    private let observability: any HTTPRequestInstrumenting
    init(observability: any HTTPRequestInstrumenting) { self.observability = observability }

    func get(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        // Auth adiciona Authorization via wsuserid
        if let token = USPAuthService.shared().currentWSUserId() {
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }
        // Observabilidade adiciona USP-* e traceparent somente ao host autorizado
        let instrumented = try observability.instrument(request)
        let (data, _) = try await URLSession.shared.data(for: instrumented)
        return data
    }
}
```

---

## Arquitetura

```
               USPMobileKit (repositório)
                      │
         ┌────────────┴────────────┐
         │                         │
    USPAuthKit              USPObservabilityKit
         │                         │
   autenticação              observabilidade
   OAuth 1.0a                USP-* + traceparent
   sessão / logout           allowlist de hosts
   usuário USP               composição de
                             instrumentadores
```

Os módulos **não se conhecem** e podem ser usados independentemente.

---

## Privacy

Cada product distribui seu próprio `PrivacyInfo.xcprivacy`, incluído como resource
do respectivo target para agregação pelo Xcode:

- `USPAuthKit` declara `NSUserDefaults` com reason `CA92.1`. Os defaults privados
  do app guardam sessão OAuth, token/plataforma de push, estado de registro e o
  cache do usuário. O fluxo de autenticação declara User ID e Device ID vinculados
  para App Functionality, pois o identificador do usuário e o token de push são
  registrados juntos no backend.
- `USPObservabilityKit` declara `UserDefaults` com reason `CA92.1`. Ele guarda um
  UUID aleatório de instalação, sem IDFA, IDFV, serial, App Group ou Keychain. O
  Installation ID é declarado como Device ID; versão/build do app, versão do SO,
  modelo do dispositivo e contexto da operação são Other Diagnostic Data. Ambos
  têm finalidade App Functionality e são enviados somente a hosts da allowlist.

O package declara `NSPrivacyTracking = false`, não contém tracking domains, não
faz publicidade, compartilhamento com data brokers nem fingerprinting. O
`trace_id` é aleatório por operação e não representa usuário ou instalação.

O `USPObservabilityKit` não conhece identidade e não vincula o Installation ID por
conta própria. Se o app ou backend associar os headers de observabilidade a uma
conta autenticada, retiver outros dados ou usar uma suite compartilhada de
`UserDefaults`, o consumidor deve revisar suas declarações. Antes de distribuir,
o app deve criar um archive no Xcode, gerar o relatório pelo menu de contexto do
archive em **Generate Privacy Report** e manter seu manifest, política de
privacidade e App Privacy no App Store Connect coerentes com o comportamento real
do app e do backend.

Referências: [Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files),
[Required Reason APIs](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)
e [App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/).

---

## Roadmap

| Iteração | Módulo | Status |
|---|---|---|
| 1 | `USPAuthKit` | ✅ Disponível |
| 1 | `USPObservabilityKit` | ✅ Disponível |
| 2 | W3C Trace Context no `USPObservabilityKit` | ✅ Disponível — sem OTel SDK |
| 3 | `USPObservabilityFirebase` | 🔲 Planejado — Performance + Crashlytics |

---

## Testes

```bash
swift test --parallel
```

---

## Decisão: USPMobileCore não criado

Após auditar os internos do `USPAuthKit` (`HTTPClient`, `USPAuthSessionStore`, `OAuth1Controller`, `Base64/HMAC/SHA1`), nenhuma dessas abstrações é genuinamente compartilhada com observabilidade. O target `USPMobileCore` seria justificado apenas quando dois ou mais módulos precisarem de uma abstração comum real. O nome está reservado no roadmap para essa ocasião.
