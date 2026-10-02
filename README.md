# USPMobileKit

Infraestrutura compartilhada para os aplicativos iOS da STI/USP.

O repositório hospeda **products SPM independentes** — cada aplicativo importa somente os módulos de que precisa, sem carregar dependências desnecessárias.

```
USPMobileKit
├── USPAuthKit           — autenticação, sessão e perfil USP
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

Package que fornece **autenticação, sessão local e acesso padronizado à identidade
e ao perfil USP** para aplicativos iOS em Swift e Objective-C.

```text
USPAuthKit
├── autenticação
├── sessão
└── perfil USP
    ├── identidade básica
    ├── wsuserid
    └── vínculos institucionais
```

- [Integração de novos aplicativos](docs/integration/new-integration.md)
- [Migração de aplicativos legados](docs/integration/legacy-migration.md)
- [Arquitetura interna](docs/authentication/architecture.md)

O consumidor trabalha com `USPAuthService`, `USPAuthUser` e `USPAuthVinculo`.
OAuth1 é o provider atualmente implementado, um detalhe interno do fluxo.

### Requisitos e instalação

iOS **14+ declarado**, Swift Package Manager e toolchain compatível com Swift tools
**6.1**. Sem dependências SPM externas. UIKit fornece o `UIViewController` que
apresenta o login. Há validação automatizada no Simulator iOS27 e homologação
real do Cardápio no iPhone; runtime iOS14 ainda não tem validação registrada.
Veja [evidências e limites](docs/modernization/validation.md).

No Xcode, use **File → Add Package Dependencies** com
`https://github.com/STI-USP/USPMobileKit.git`, escolha a release publicada aprovada
para seu app e adicione o product **USPAuthKit** ao target. Importe `USPAuthKit`;
o nome do package é `USPMobileKit`. Não é necessário adicionar Observability.

### Quick Start

Configure uma vez no bootstrap com os dados próprios do aplicativo. Chame o login
na UI, com um controller apto a apresentar, e continue somente com usuário e sem
erro. As funções abaixo são exemplos do app, não novos métodos do package:

```swift
import UIKit
import USPAuthKit

func configurarAutenticacaoUSP() {
    USPAuthService.configure(
        with: .prod,
        consumerKey: "CONSUMER_KEY_DO_APP",
        consumerSecret: "CONSUMER_SECRET_DO_APP",
        appKey: "APP_KEY_DO_APP"
    )
}

func entrarNaUSP(from presenter: UIViewController,
                aoConcluir: @escaping @MainActor @Sendable (USPAuthUser) -> Void) {
    USPAuthService.shared().ensureLoggedIn(from: presenter) { user, error in
        DispatchQueue.main.async {
            guard error == nil, let user else {
                // Apresente falha/cancelamento na UI, sem registrar dados sensíveis.
                return
            }
            // Perfil: user.nomeUsuario e user.loginUsuario.
            // Recursos USP: user.wsuserid, conforme o contrato do serviço.
            // Vínculos: user.vinculos, lista de USPAuthVinculo.
            aoConcluir(user)
        }
    }
}

func perfilUSPEmCache() -> USPAuthUser? {
    USPAuthService.shared().currentUser()
}

func sairDaUSP() {
    USPAuthService.shared().logout()
}
```

`consumerKey`/`consumerSecret` são configuração do provider OAuth1 atual por app;
secret embarcado no aplicativo não é segredo seguro. `appKey` identifica o app
no backend mobile. Base custom e `backendHeaderValue` estão no
[guia de configuração](docs/integration/new-integration.md#4-configuração-do-aplicativo).

`wsuserid` é o identificador operacional USP retornado no perfil e utilizado pelos
aplicativos para consumir recursos dos serviços mobile que adotam esse contrato.
Não é OAuth access token nem número USP. Strings podem ser vazias; vínculos podem
estar ausentes conforme a resposta. Consuma o perfil tipado, sem ler JSON/defaults.

`currentUser()` consulta o perfil local e pode existir com sessão incompleta.
`isLoggedIn()` verifica estado local, sem comprovar validade remota. `logout()`
limpa sessão/perfil/push/registro local e cancela operações em curso; não promete
revogação, invalidação mobile automática, encerramento SSO ou limpeza de cookies.
O aplicativo limpa seus próprios caches pessoais.

Push e operações mobile são complementares; veja
[push e backend mobile](docs/integration/new-integration.md#10-push-e-backend-mobile).
`userData`, tokens OAuth e login com WebView própria permanecem por compatibilidade,
mas não são recomendados para novas integrações. Use o
[playbook de migração](docs/integration/legacy-migration.md) para remover esses
acoplamentos progressivamente. Persistência atual ainda é legada; este guia não
introduz migração para Keychain nem especifica outro provider.

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

## Arquitetura

```
               USPMobileKit (repositório)
                      │
         ┌────────────┴────────────┐
         │                         │
    USPAuthKit              USPObservabilityKit
         │                         │
   autenticação              observabilidade
   perfil / provider          USP-* + traceparent
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

O host não executa o serviço Auth iOS. Para a suíte do serviço e fixtures
Swift/Objective-C, use o [harness iOS](Tests/iOSSessionHarness/README.md) e consulte
a [validação registrada](docs/modernization/validation.md).

---

## Decisão: USPMobileCore não criado

Após auditar os internos do `USPAuthKit` (`HTTPClient`, `USPAuthSessionStore`, `OAuth1Controller`, `Base64/HMAC/SHA1`), nenhuma dessas abstrações é genuinamente compartilhada com observabilidade. O target `USPMobileCore` seria justificado apenas quando dois ou mais módulos precisarem de uma abstração comum real. O nome está reservado no roadmap para essa ocasião.
