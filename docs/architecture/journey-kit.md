# USPJourneyKit

Implementação da infraestrutura STI-212, conforme contrato STI-13 e decisão
de 28/10/2026. Um produto/módulo público no USPMobileKit. Sem dependência dos
targets USPAuthKit/USPObservabilityKit; sem produto Firebase separado.

| Camada | Responsabilidade |
| --- | --- |
| Domain | `JourneyDefinition`, cinco nomes de evento, categorias controladas, correlação opcional, eventos imutáveis |
| Coordination | `JourneyCoordinator`, tentativas opacas e transições no MainActor |
| Integration | Protocolos de registro, reporter em memória, política dinâmica e reporter Firebase |

## Estado e entrega

`start` gera UUID e registra IN. `advance` registra marco declarado. `complete`,
`fail` e `cancel` removem estado antes de chamar o reporter, impedindo terminal
duplicado mesmo em callback reentrante. Novas tentativas têm IDs distintos.
Todas as operações são síncronas no MainActor, sem suspensão no meio da transição.
Múltiplas jornadas coexistem; não há um identificador global de jornada corrente.

A definição declara etapas, etapas válidas de conclusão e, opcionalmente, grafo
de transições. Sem grafo, permite qualquer etapa declarada. Com grafo, transição
entre etapas diferentes exige aresta; mesma etapa pode ser registrada novamente.
Conclusão nunca é deduzida de HTTP, navigation lifecycle ou status remoto.
`complete(at:)`/`fail(at:)` podem transicionar diretamente para etapa permitida
sem emitir um marco intermediário artificial. Regras funcionais pertencem ao app.

Handle de tentativa é uma capability com proprietário privado; outra instância
de coordenador o rejeita. Uso após terminal/forget retorna `.inactive` sem evento.
Sem histórico de terminais retido: memória cresce com tentativas ativas, não com
todas as tentativas encerradas. O app deve chamar `forget` ao perder contexto
irrecuperável; isso não emite cancelamento nem abandono. Não há persistência,
timer, retry de negócio/rede, observador de background ou inferência de abandono.

O reporter é síncrono e pode lançar; a coordenação captura falhas e notifica um
callback sanitizado de canal/tentativa, sem propagar erro de envio ao fluxo.
`accepted` confirma transição local, não entrega. Não há retry de telemetria,
buffer adicional nem promessa de exactly-once. SDK cuida de seu próprio transporte.
Desabilitar coleta ou mudar consentimento pode produzir tentativas sem terminal
ou eventos parciais; análises devem considerar elegibilidade e integridade.

## Parâmetros e privacidade

`versao_contrato=1` acompanha `id_jornada` e `tipo_jornada` em todos os eventos.
Novos campos/enums desta implementação são contrato técnico inicial, a revisar
antes de instrumentar o piloto; não aprovam os critérios propostos do Cardápio.
Versão de schema não é versão semântica do pacote.

Dimensões específicas são strings de enumeração em allowlists finitas definidas
no app. Máximo dez dimensões, 64 valores por dimensão, tokens ASCII snake_case
até 64 caracteres; chave até 40. Campos de protocolo são reservados; nomes
sensíveis/identificadores livres são rejeitados mesmo quando listados. Erros de
validação não contêm os dados rejeitados. O total do envelope fica abaixo de
25 parâmetros. Uma allowlist sintaticamente válida não substitui revisão humana:
não declarar valores pessoais como categorias, nem jornadas por usuário/objeto.

Nenhum Error arbitrário, payload, URL, código Pix ou texto livre é aceito como
diagnóstico. Categorias são controladas; códigos e motivos opcionais precisam
estar declarados na definição. Correlação aceita request UUID e trace W3C de
32 hexadecimais minúsculos não nulos. Não depende do módulo de tracing; um formato
de request ID diferente precisará de extensão revisada, sem coercer PII em IDs.

`reportableTechnical` é explícito, separado do evento funcional. Reporter de
diagnóstico é opcional e o Firebase exige permissão independente. Crashlytics
recebe NSError sintético de domínio/código/mensagem fixos e contexto por ocorrência
via `record(error:userInfo:)`, sem custom keys globais. Isso registra a classificação
técnica sanitizada, não stack/cause original. Investigações detalhadas continuam
nas políticas de observabilidade do app. Falha funcional não cria não fatal por padrão.

O manifest do módulo declara Product Interaction para Analytics e Other Diagnostic
Data para App Functionality; sem Required Reason APIs próprias. Não declara ID
persistente, pois o UUID identifica tentativa. SDKs Firebase possuem manifests
próprios. O app deve revisar agregação, App Privacy e vínculo à identidade quando
configura user ID, outras propriedades/coletores; o módulo não garante anonimato
do conjunto Firebase do consumidor.

## Distribuição e compatibilidade

O target iOS depende de FirebaseCore, FirebaseAnalyticsWithoutAdIdSupport e
FirebaseCrashlytics; a implementação faz parte do único produto. Domínio e
coordenação conhecem apenas protocolos/eventos. Não há FirebaseApp.configure,
outro projeto Firebase, mudança de consentimento/coleta global, setUserID ou
alterações no USPAuthKit/USPObservabilityKit.

Mantido iOS 14. Firebase 12 e 13 declaram iOS 15; por isso a faixa desta entrega
é 11.15..<12. Em macOS o domínio/testes compilam sem SDK Firebase; o reporter real
é iOS. A distribuição iOS continua vinculada ao Firebase mesmo usando mock em
runtime. `Package.resolved` serve à validação deste repositório; consumidores
resolvem o grafo e lockfile próprios.

Cardápio atualmente exige Firebase >=12.12.1: existe conflito de resolução.
Não adotar esta faixa no piloto sem decisão explícita. Alternativas a avaliar
separadamente: revisão aprovada da plataforma mínima e Firebase do package, ou
estratégia de versões compatíveis para consumidores legados. Não efetuar downgrade
do app nem elevar iOS mínimo incidentalmente.

Referências: [STI-13](https://linear.app/sti-mobile/issue/STI-13),
[STI-212](https://linear.app/sti-mobile/issue/STI-212),
[Firebase release notes](https://firebase.google.com/support/release-notes/ios),
[manifest Firebase 11.15](https://github.com/firebase/firebase-ios-sdk/blob/11.15.0/Package.swift).
