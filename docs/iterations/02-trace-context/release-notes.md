# Iteração 2 --- W3C Trace Context e Allowlist de Hosts

Esta versão evolui o `USPObservabilityKit` com suporte à correlação de
requisições entre os aplicativos e os serviços backend, seguindo o
padrão W3C Trace Context.

## Novidades

-   Suporte à geração e validação do header `traceparent`.
-   Geração criptograficamente segura de `trace_id` e `parent_id`.
-   Nova API para acesso ao contexto de tracing associado à requisição.
-   Suporte a retries preservando o `trace_id` e gerando um novo
    `parent_id`.
-   Allowlist explícita de hosts autorizados a receber os headers de
    observabilidade.
-   Proteção contra envio de `traceparent` e `USP-App-*` para serviços
    de terceiros.
-   Preservação de `traceparent` válido e headers institucionais
    previamente definidos.
-   Novos testes de segurança, concorrência, retry, privacidade e
    compatibilidade.

## Configuração necessária

Os aplicativos consumidores devem declarar explicitamente os hosts
autorizados:

``` swift
let configuration = ObservabilityConfiguration(
    allowedHosts: [
        "api.exemplo.usp.br"
    ]
)
```

Por segurança, uma configuração sem hosts autorizados não adiciona
headers de observabilidade às requisições.

O matching de hosts é exato e case-insensitive. Subdomínios não são
autorizados implicitamente.

## Compatibilidade

As APIs anteriores foram preservadas, sem breaking changes de
compilação.

Há uma mudança comportamental intencional: `USPContextInstrumenter()`
sem uma allowlist configurada não envia headers de observabilidade.
Aplicativos que já utilizam o instrumentador devem configurar
explicitamente seus hosts institucionais.

`USPAuthKit` permanece inalterado e independente do
`USPObservabilityKit`.

## Validação

-   65 testes executados com sucesso.
-   59 testes do `USPObservabilityKit`.
-   5 testes do `USPAuthKit`.
-   1 teste de compatibilidade entre os products.
-   `swift build -c release` concluído com sucesso.
-   Nenhuma dependência externa adicionada.

## Fora do escopo desta versão

Esta versão ainda não inclui OpenTelemetry SDK no aplicativo, Firebase
Crashlytics, Firebase Performance, spans mobile, exporters,
`tracestate`, `baggage`, retry automático ou interface de correlação de
erros.

O próximo passo é validar o contrato em um aplicativo real, confirmando
a propagação do mesmo `trace_id` do app até os logs da
infraestrutura/backend.
