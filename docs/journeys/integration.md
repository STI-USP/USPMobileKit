# Integração incremental

Adicionar o produto `USPJourneyKit` ao target iOS somente após revisar o grafo
Firebase e a plataforma mínima. Esta alteração não foi publicada como release.
Não apontar apps automaticamente para uma tag ainda inexistente.

## Composição

O app configura seu Firebase padrão e suas políticas fora do kit. Criar uma
instância durável de reporter/coordenador por composição do app, em MainActor:

```swift
import USPJourneyKit

@MainActor
func makeJourneys(
    allowsAnalytics: @escaping @MainActor () -> Bool,
    allowsDiagnostics: @escaping @MainActor () -> Bool
) -> JourneyCoordinator {
    let reporter = FirebaseJourneyReporter(policy: JourneyCollectionPolicy(
        allowsAnalytics: allowsAnalytics,
        allowsDiagnostics: allowsDiagnostics
    ))
    return JourneyCoordinator(reporter: reporter, diagnosticReporter: reporter)
}
```

Fornecer decisões reais do app sobre ambiente, consentimento, Debug, teste e
dispositivo conforme a política institucional. Não passar `{ true }` sem essa
avaliação. Defaults são false. Os gates controlam apenas os envios deste reporter;
não desativam coleta automática de outros SDKs ou dados que o app já enviava.
Reavaliados a cada envio, podem gerar fluxo parcial ao mudar de estado; não
retroalimentar eventos de períodos sem consentimento nem classificá-los como abandono.

## Exemplo de definição e tentativa

Exemplo ilustrativo, não aprovação de regras CAP-J005:

```swift
let pix = try JourneyDefinition(
    type: "EXAMPLE-J005",
    initialStage: "gerar_codigo",
    stages: ["gerar_codigo", "disponibilizar_codigo"],
    completionStages: ["disponibilizar_codigo"],
    parameterValues: ["origem": ["rucard"]],
    cancellationReasons: ["voltar"]
)

// Após validar entrada e aceitar o comando de geração:
let attempt = try? journeys.start(pix, parameters: ["origem": "rucard"])

// Somente depois de o app validar e disponibilizar o código:
if let attempt {
    try? journeys.complete(attempt, at: "disponibilizar_codigo")
}
```

`try?` isola falhas de contrato do fluxo do usuário; em desenvolvimento, validar
as definições e investigar erros explicitamente nos testes. Falhas do registrador
já são isoladas pelo coordenador; não causam throw destas operações.
Não conter Error do backend no callback `onRecordingIssue`, que informa somente
tentativa/canal, nem usar o callback para repetir a operação funcional.

Em erro funcional conhecido, chamar `fail(at:category:code:)`. Para erro técnico
que a política do app classifica como reportável, acrescentar
`reporting: .reportableTechnical`. Isso exige também reporter diagnóstico e gate
de coleta; não encaminha automaticamente todo erro funcional ao Crashlytics.

## Lifecycle

- Guardar o handle no contexto da operação, não numa variável global de jornada
  corrente. Outro objetivo pode estar em andamento ao mesmo tempo.
- Nova tentativa após terminal recebe novo handle por `start`; retentativa técnica
  interna não exige nova jornada. Isso não implementa idempotência de backend.
- Preservar handle em login/foreground quando o contexto continuar válido.
- `cancel` só para ação explícita e inequívoca antes do terminal. Bool ambíguo
  de autenticação não distingue cancelamento de falha.
- `forget` libera contexto irrecuperável sem emitir terminal. Sem timer automático.
- Depois de concluir Pix, fechar/compartilhar/retornar do banco não chama ET/CA.
- Não terminar por HTTP 200, push recebido ou página iniciando carregamento.

## Release e aceite

Mudança aditiva de API, mas novo grafo externo Firebase afeta a resolução de todos
os consumidores. Antes de tag: revisar versão semântica pelo mantenedor, validar
consumidores representativos, manifest de privacidade e grafo no Xcode. Não
publicada/tagueada nesta tarefa. Aprovação de matrizes por app e recebimento real
dos eventos no Firebase/DebugView e diagnósticos controlados ficam no aceite STI-15.
