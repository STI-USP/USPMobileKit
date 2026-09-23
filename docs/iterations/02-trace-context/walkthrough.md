# Iteração 2 — W3C Trace Context

## Objetivo

Permitir correlação App → Backend no `USPObservabilityKit` por meio de W3C Trace
Context, com allowlist explícita e sem OpenTelemetry SDK.

## Estado anterior

O product já possuía providers testáveis para contexto do app, identidade de
instalação persistente, instrumentação de `URLRequest` e composição de
instrumentadores. O `USPContextInstrumenter` adicionava seis headers `USP-*` a
qualquer destino. `TracingInstrumenting` era somente um ponto de extensão, sem
implementação concreta.

O package já mantinha `USPAuthKit` e `USPObservabilityKit` desacoplados e não tinha
dependências externas.

## Estado resultante

```text
Feature
  ↓
Repository / Service
  ↓
HTTPClient
  ↓
USPContextInstrumenter
  ├── compara o host com allowlist exata
  ├── preserva headers existentes
  ├── adiciona USP-App-* e USP-Installation-Id
  ├── cria ou preserva traceparent W3C 00
  └── devolve TraceContext ao chamador
  ↓
URLSession → API
```

Requests para hosts não autorizados são devolvidas intactas e sem contexto de
trace associado pelo package.

## Alterações realizadas

### Modelo W3C

`TraceContext` representa `traceID`, `parentID`, `TraceFlags` e a serialização
`traceparent`.

- trace ID: 16 bytes / 32 caracteres hex lowercase;
- parent ID: 8 bytes / 16 caracteres hex lowercase;
- IDs zero são rejeitados;
- versão suportada: `00`;
- flags suportadas: `00` e `01`, com geração padrão em `01`;
- geração: `SystemRandomNumberGenerator`, fonte aleatória segura do sistema;
- testes: gerador interno injetável permite bytes determinísticos.

`TraceContext.create()` inicia uma operação lógica. `nextAttempt()` mantém o trace
ID e gera outro parent ID.

### Allowlist

`ObservabilityConfiguration(allowedHosts:)` recebe apenas hostnames, sem scheme,
porta, path ou wildcard. Os nomes são normalizados para lowercase e podem ter ponto
DNS final. A comparação é exata; subdomínios não são autorizados implicitamente.

A configuração padrão possui allowlist vazia. Essa decisão elimina o envio
automático de headers institucionais a terceiros.

### Instrumentação e idempotência

A API existente foi preservada:

```swift
func instrument(_ request: URLRequest) throws -> URLRequest
```

Foram adicionadas APIs que devolvem `InstrumentedRequest`, contendo a request e o
`TraceContext?`:

```swift
func instrumentWithTraceContext(_ request: URLRequest) throws -> InstrumentedRequest
func instrumentWithTraceContext(
    _ request: URLRequest,
    context: TraceContext
) throws -> InstrumentedRequest
```

Política de headers:

- host não autorizado: nenhuma alteração;
- `Authorization`, `Content-Type` e headers arbitrários: preservados;
- `USP-*` preexistente: preservado;
- `traceparent` válido preexistente: preservado e retornado como `TraceContext`;
- `traceparent` inválido em host autorizado: substituído por contexto válido;
- contexto explícito de retry: prevalece sobre o header da tentativa anterior;
- reinstrumentação normal: idempotente para contexto válido.

## Arquivos criados

- `Sources/USPObservabilityKit/ObservabilityConfiguration.swift`
- `Sources/USPObservabilityKit/TraceContext.swift`
- `Sources/USPObservabilityKit/InstrumentedRequest.swift`
- `Tests/USPObservabilityKitTests/TraceContextTests.swift`
- `Tests/USPObservabilityKitTests/ObservabilitySecurityTests.swift`
- `docs/iterations/02-trace-context/plan.md`
- `docs/iterations/02-trace-context/walkthrough.md`

## Arquivos modificados

- `Package.swift` — comentários do escopo, sem mudar products ou dependências;
- `Sources/USPObservabilityKit/USPContextInstrumenter.swift`;
- `Sources/USPObservabilityKit/HTTPRequestInstrumenting.swift`;
- `Sources/USPObservabilityKit/TracingInstrumenting.swift`;
- `Sources/USPObservabilityKit/CompositeInstrumenter.swift`;
- `Tests/USPObservabilityKitTests/USPObservabilityKitTests.swift`;
- `README.md`.

Nenhum arquivo de implementação do `USPAuthKit` foi alterado.

## Decisões técnicas

- O tracing mínimo ficou no product existente; não foi criado target adicional nem
  adicionada dependência OpenTelemetry.
- Não existe contexto global ou singleton mutável. Cada operação carrega seu próprio
  valor imutável e `Sendable`.
- A API de `URLRequest` existente foi mantida para consumidores protocolados por
  `HTTPRequestInstrumenting`; a recuperação do trace ID é uma API adicional no
  instrumentador concreto.
- A allowlist falha de forma segura: entrada inválida é ignorada e ausência de match
  não lança erro.

## Testes e validações

- Baseline antes da mudança: 39 testes (33 Observability, 5 Auth, 1 compatibilidade),
  todos passando.
- Estado final: `swift test --parallel` executou 65 testes (59 Observability, 5 Auth,
  1 compatibilidade), sem falhas.
- `swift build -c release`: concluído com sucesso.
- `swift package show-dependencies`: `No external dependencies found`.
- `git diff --check`: sem erros de whitespace.
- Os testes não realizam chamadas reais de rede.

Os novos testes cobrem formato e validação W3C, geração determinística, IDs não
zero, independência entre operações, retry, concorrência, allowlist exata, domínio
malicioso, terceiros, preservação de headers, reinstrumentação, contexto explícito
e ausência de dados do app no `traceparent`. Os testes anteriores de Installation
ID foram preservados.

## Compatibilidade

- APIs públicas existentes: os dois inicializadores e `instrument(_:)` foram
  preservados sem remoção ou renomeação.
- Products/targets: inalterados e independentes.
- Deployment target: inalterado (iOS 14+).
- Persistência do Installation ID: inalterada.
- Dependências: nenhuma adicionada.
- Breaking change de compilação: nenhum.
- Mudança comportamental intencional: `USPContextInstrumenter()` sem configuração
  agora possui allowlist vazia e não adiciona headers. Consumidores devem fornecer
  seus hosts institucionais explicitamente.

## Limitações

Não foram implementados `tracestate`, `baggage`, spans internos, sampling
configurável, exporter, OTLP, Collector, OpenTelemetry SDK, Firebase, Crashlytics,
retry automático, HTTPClient institucional ou UI de correlação.

## Próximos passos

Uma iteração futura pode consumir o trace ID em erros de UI/suporte e integrar
telemetria, ou avaliar um adapter OpenTelemetry completo. Essas evoluções devem
preservar a allowlist e não acoplar `USPAuthKit` ao módulo de observabilidade.
