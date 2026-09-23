# Iteração 2 — W3C Trace Context

## Objetivo

Evoluir o `USPObservabilityKit` para correlacionar requisições App → Backend com
`traceparent` W3C versão `00`, sem OpenTelemetry SDK, mantendo `USPAuthKit`
independente.

## Contexto auditado

- `USPContextInstrumenter` injeta seis headers `USP-*` e preserva os demais.
- `HTTPRequestInstrumenting` e `CompositeInstrumenter` são as abstrações públicas
  atuais e devem permanecer compatíveis.
- `TracingInstrumenting` é apenas um marker protocol; não há implementação W3C.
- Não existem dependências entre `USPAuthKit` e `USPObservabilityKit`, nem
  dependências de Firebase/OpenTelemetry.
- A implementação atual envia headers para qualquer host e sobrescreve valores
  `USP-*` preexistentes.

## Escopo e abordagem

1. Adicionar uma configuração pública com allowlist de hosts por comparação exata,
   case-insensitive e sem matching por substring.
2. Adicionar um `TraceContext` público, imutável e `Sendable`, com criação segura,
   parsing/validação, serialização e `nextAttempt()`.
3. Integrar a geração de `traceparent` ao `USPContextInstrumenter`, preservando
   `instrument(_:) -> URLRequest` e adicionando resultado tipado com contexto.
4. Tornar a instrumentação idempotente: preservar `traceparent` válido e headers
   `USP-*` preexistentes; substituir `traceparent` inválido somente em host autorizado.
5. Atualizar testes, README e walkthrough da iteração.

## Componentes afetados

- `Sources/USPObservabilityKit`
- `Tests/USPObservabilityKitTests`
- `Tests/USPMobileKitCompatibilityTests`
- `README.md`
- `docs/iterations/02-trace-context`

`USPAuthKit` e `Package.swift` não devem exigir mudanças.

## Estratégia de testes

- Testes determinísticos de parsing/validação com IDs conhecidos.
- Testes de geração, independência entre operações e semântica de retry.
- Testes da allowlist, incluindo domínio malicioso por substring.
- Testes de preservação de headers e reinstrumentação.
- Testes concorrentes sem estado global.
- `swift test` completo para validar também `USPAuthKit` e compatibilidade conjunta.

## Riscos

- O inicializador existente continua compilando, mas a allowlist vazia passa a ser
  o padrão seguro. Consumidores precisam configurar hosts para receber os headers.
- Uma request de retry que reutilize a request já instrumentada precisa passar o
  novo contexto explicitamente para trocar o `parent-id`.

## Critérios de conclusão

- Host autorizado recebe seis headers `USP-*` e `traceparent` válido.
- Host não autorizado permanece intacto.
- O trace ID é recuperável sem parsing manual.
- Operações independentes recebem trace IDs distintos.
- Retry preserva trace ID e troca parent ID.
- Suíte completa passa sem novas dependências.
