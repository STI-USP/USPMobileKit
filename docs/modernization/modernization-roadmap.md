# Roadmap de modernização do USPAuthKit — estado consolidado

2026-10-02, branch feature/auth-architecture-modernization. Fonte de verdade:
[arquitetura implementada](../authentication/architecture.md). Integração:
[README](../../README.md#uspauthkit), [apps legados](../authentication/consumer-migration.md),
[apps novos](../authentication/new-integration.md). [Validação](validation.md) e
[consolidação](../iterations/10-auth-consolidation/walkthrough.md) registram evidência.

OAuth1 permanece implementação atual/default. OAuth2 não foi implementado nem
modelado. Compatibilidade é mantida com adapters baratos, não exige perpetuar
keys/WK/credenciais OAuth nos consumidores. Nenhuma API pública removida/deprecada
por annotation, endpoint ou schema alterado na consolidação. Sem commit.

## Status atual por entrega

| Item | Implementação | Testes automáticos | Homologação real / pendência |
|---|---|---|---|
| R01 | Inventário Cardápio disponível | Não é tarefa de implementação | Parcial: lista autoritativa e demais consumidores pendentes |
| R02 | Concluído: contrato de sessão e fixtures | 24 testes baseline intactos, Swift/ObjC executados, checker5 | Runtime14 não validado; não reabrir R02 por tarefa posterior |
| R03 | Não executado: contrato de mecanismo futuro | Fake não especifica backend futuro | Pendência com responsável/backend |
| R04 | Transporte privado injetável com URLSession/cancel handle, aplicado tokens/perfil/mobile | URLProtocol/fakes: sucesso/status/erro/vazio/cancel | Integração OAuth1+mobile validada no Cardápio |
| R05 | Store contratual + adapter UserDefaults legado | Load/save/partial/corrupt/clear/isolamento/restauração | Perfil/vínculos restaurados no piloto; Keychain e outro envelope pendentes |
| R06 | UI por instância e browser abstraction | Callback único, cancel/finish/handoff, erro antes/depois | Login válido iPhone homologado; todas variantes swipe/iPad não certificadas |
| R07 | Clock/nonce e signer determinísticos privados | Encoding/header/base string/HMAC/request/access | Wire válido no fluxo real; não significa todas políticas R15 concluídas |
| R08 | Provider OAuth1/coordinator/fachada e compatibility adapters | Fake independente OAuth1 entrega perfil completo | Provider atual homologado; outro mecanismo inexistente |
| R09 | Perfil canônico + backend mobile separado sem tokenSecret | Perfil/vínculos/raw shape/registro/check/invalidate/push | Perfil/wsuserid/registro/completion homologados; DEV vazio vs PROD vínculos |
| R10 | Não executado: Keychain | Não há teste de migração Keychain | Secrets continuam defaults; etapa própria transacional/versionada |
| R11 | Callback/correlation, cancel/logout/generation/late results implementados | Regressão WK102, reentrância, invalid callback, pré-callback, cancel/logout/late | Callback real correlacionado e sucesso após correção homologados; UI completa não certificada |
| R12 | Concluído no escopo buffers C S04 | Quatro casos, vetores, entradas intactas, ASan/UBSan/concorrência | Digests preservados; não substitui auditoria crypto completa |
| R13 | Não concluído: status/payload/parser/registro/atomicidade | Baseline permissivo caracterizado | Contrato/política explícita ainda necessária |
| R14 | Parcial: exemplos seguros e diagnóstico temporário removido | Testes comportamentais preservados | description/erros/logs legados ainda exigem hardening próprio |
| R15 | Não concluído: nonce/time/redirect/cache/TLS policies | Vetores atuais são baseline, não nova política | Backend/evidência necessários |
| R16 | Fronteira neutra demonstrada, config app/provider privada separada | Fake sem consumer fields/tokens/WK com duas configs | Envelope/config/capabilities futuros dependem R03; não concluído |
| R17 | Harness iOS/fixtures/checker existentes | Build/link/execução local disponíveis | CI/runner/runtime14 e todos ambientes ainda pendentes |
| R18–R20 | Não executados como entregas próprias | Nenhum gate novo declarado | Observer/frameworks/helper cleanup/UI opcional separados |
| R21 | OAuth2 não implementado | Nenhum código/speculativo | Só após contrato backend |
| R22 | Piloto OAuth1 Cardápio homologado no escopo documentado | Regressões permanentes executáveis | Demais apps/rollout/rollback ensaiado e migração futura ainda pendentes |

## Gates por fase

- Fase0: R02 completo; R01 parcial, lista de consumidores ainda necessária.
- Fases1/2: composição/transporte/store/browser/provider/coordinator/mobile
  implementados, protegidos por testes e caminho válido homologado no Cardápio.
- Fase3: S04 corrigido, callback/cancel/late protegidos; fase inteira aberta por
  Keychain, status/payload/logs/policies e variantes de integração não executadas.
- Fase4: domínio/config/perfil neutros demonstrados; contrato backend/envelope
  futuro não definido. Não exigir formato OAuth1 de mecanismo futuro.
- Fase5: nenhum OAuth2/modelo refresh/scopes/PKCE/bearer fictício implementado.
- Fase6: primeiro piloto OAuth1 validado; não equivale a migrar todos consumidores.

## Evidência Cardápio e próxima tarefa

Responsável homologou pacote local no iPhone: request/auth/callback/verifier/access,
perfil/USPAuthUser/wsuserid/vínculos/persistência/restauração, registro e completion,
uso do identificador em recursos. DEV retornou vinculo:[] e PROD vínculos esperados:
nenhuma perda em parsing/identity/userData. Regressão WK102 pós-callback foi corrigida
com handoff de ownership, não remoção de validação. Testes permanentes reproduzem
sequência e controles. AuthDebug/helpers temporários removidos nesta consolidação.

Única próxima tarefa recomendada: **R03 — especificar com o responsável/backend
como um mecanismo futuro autentica e entrega o perfil USP/wsuserid**, configuração
por aplicativo, serviços mobile, redirects e capacidades efetivamente suportadas.
Usar contratos existentes como evidência, sem projetar campos/endpoints de OAuth2
por suposição. Esta tarefa não foi executada.

---

## Organização física implementada — 2026-10-02

Diretórios produtivos e de testes espelham as responsabilidades existentes;
[árvore real](../authentication/architecture.md#organização-do-código) e
[mapa47moves](../iterations/11-auth-layout/file-map.md). Nenhum protocolo novo,
provider2, API renomeada, endpoint/schema ou comportamento alterado. Perfil separado
fisicamente da sessão (mesmo USPIdentity), provider1/crypto confinados. R02 e fake
neutro intactos;64Auth iOS executados após reorganização. R01/R03/R10 e demais
pendências anteriores mantidas. Não equivale a novo gate de OAuth2/Keychain/runtime14.

## Histórico da auditoria e das iterações

O conteúdo abaixo registra o baseline e o progresso por data. Afirmações como
"proposta", "nenhum login real" ou "homologação pendente" descrevem aquele momento,
não o estado consolidado acima. Prioridades/esforços originais permanecem rastreáveis.

# Registro histórico do roadmap e progresso

**Documento principal da auditoria — 2026-10-01, baseline `11d9582`.** Nesta entrega somente documentação; nenhum OAuth2, endpoint, API, dependência, criptografia ou comportamento foi alterado. O USPAuthKit integra o package **USPMobileKit**.

## Documentos de apoio

- [Arquitetura atual e qualidade do package](current-architecture.md): estrutura, fluxo, networking, sessão e testes.
- [Inventário público e classificação de compatibilidade](public-api-inventory.md): elementos exportados e uso local comprovado.
- [Mapa de acoplamento OAuth1](oauth1-coupling-audit.md): O01–O19, localização, dificuldade, risco e estratégia.
- [Auditoria de segurança](security-audit.md): S01–S15, severidade e limites da evidência.
- [Arquitetura alvo proposta](target-architecture.md): responsabilidades, dados, composição, configuração e coexistência.
- [Validação executada](validation.md): comandos, 66 testes, warnings e limitações de iOS.
- [Walkthrough da auditoria](../iterations/03-auth-audit/walkthrough.md).

## Diagnóstico e estratégia

A API principal é uma fachada ObjC importável em Swift. A implementação OAuth1 usa WKWebView, requests assinadas HMAC-SHA1 e profile USP; backend mobile recebe **wsuserid**, app/push. O signer não é público, mas tokens/secret, consumer config e modo WKWebView vazaram para o contrato. Store/HTTP internos já existem: evoluí-los é menor e mais seguro que uma reescrita.

Preservar a fachada e modelos, compor instâncias explicitamente, criar fronteiras internas de transporte/store/browser e só então encapsular provider1. Provider é responsável por identidade e protocolo; backend mobile e sessão são responsabilidades distintas. Não adicionar refresh obrigatório inexistente, arquitetura de plugins, shared core, Swift no target Clang ou dependência entre Auth/Observability.

Há risco alto em credenciais nos defaults, callback não correlacionado, callbacks tardios após logout e mutação de buffers C. O logout atual é local. `isLoggedIn` só testa presença local e não expiração/validade remota. Uma extração que preserve esses comportamentos não é hardening por si só; os testes devem distinguir baseline, bug conhecido e comportamento desejado.

**Não é possível prometer troca transparente para todos os apps.** Propriedades de tokenSecret e login WK antigos exigem permanência no provider1 até migração explícita. Mesmo apps que usam só ensure/currentUser dependem de wsuserid e backend: contrato futuro dessa credencial é gate P0. Não existem consumidores reais neste workspace para comprovar sua distribuição de uso.

## Priorização rastreável

P0 = impede/coloca em risco substituição; P1 = desacoplamento, segurança/testabilidade; P2 = desejável; P3 = opcional. Esforço/risco são relativos a tarefas pequenas neste SDK; não são prazos. Breaking indica a entrega proposta, não remoções futuras. Cada referência O/S é detalhada nos documentos vinculados.

| Item / achados | Prioridade | Esforço | Risco | Breaking | Dependências | Fase |
|---|---|---|---|---|---|---|
| R01 Inventariar apps, seletores/Swift import/runtime/defaults e usos token/WK (O01–O04,O15,O18) | P0 | Médio | Baixo | Não | Acesso aos consumidores/equipes | 0 |
| R02 Characterization de sessão/API + baseline iOS/ObjC; host exclui Service (O11,O12,O16,O17) | P0 | Médio | Baixo | Não | Toolchain iOS14 adequada + app/harness iOS | 0 |
| R03 Confirmar emissão de perfil/wsuserid e contrato mobile com futuro mecanismo (O13–O15) | P0 | Médio | Baixo | Não | Backend USP, R01 | 4; investigação pode começar em 0 |
| R04 Transporte request arbitrária injetável, status/errors/cancel handle (O05,O08,O13; S06,S13) | P1 | Médio | Médio | Não | R02 e fixtures HTTP | 1 |
| R05 Store contratual injetável, schema/escopo e baseline keys (O01,O11; S01,S07) | P1 | Médio | Alto | Não | R02; migração segura só R10 | 1 |
| R06 UI usa instância, browser/lifecycle/completion única (O04,O06,O16; S02,S03,S09) | P1 | Médio | Alto | Não | R02,R04; testes UI | 1, correções de segurança em 3 |
| R07 Clock/nonce/signer privados, encoding/vetores e callbacks testáveis (O07–O10,O17; S08,S15) | P1 | Médio | Alto | Não | R02 e vetores backend/RFC | 1–2 |
| R08 Fronteira provider1 + adapter public tokens/config/etapa WK (O01–O08,O12,O13) | P0 | Alto | Alto | Não | R04–R07; R01 | 2 |
| R09 Separar perfil e cliente mobile do signer/coordenar registro (O12–O15; S06) | P1 | Médio | Alto | Não | R04,R08; semântica baseline | 2 |
| R10 Migrar credenciais a Keychain com rollback/schema/escopo; avaliar wrapper (O11; S01,S07,S10) | P1 | Alto | Alto | Não* | R05 + falhas Keychain/upgrade/logout/downgrade | 3, antecipar se exposição exigir |
| R11 Validar destino/token do callback; cancelamento, geração e operações tardias (O06,O16; S02,S03,S09) | P1 | Médio | Alto | Não* | R06,R07, contrato callback | 3, antecipar com testes focados |
| R12 Hardening C de buffers mantendo digest; vetores, sanitizers (O10; S04,S15) | P1 | Médio | Alto | Não* | Reprodução isolada já feita; teste permanente equivalência | 3; pode preceder extração em patch próprio |
| R13 Status HTTP/access token/payload/erros; parsing numérico e atomicidade da sessão (O05,O12–O15; S06,S11) | P1 | Médio | Alto | Não* | R04,R09, política de sucesso/registro | 3 |
| R14 Logs/description/exemplos sem credenciais ou PII (S05,S12) | P1 | Baixo | Baixo | Não* | Testes de redaction; classificação backend | 3; docs antecipáveis |
| R15 Policies de nonce/time/normalização/redirect/cache/TLS (O06–O10; S08,S13) | P1 | Médio | Alto | Não* | R07, backend, characterization | 3 |
| R16 API neutra/config aditiva, envelope e capability semantics; seleção interna provider (O01–O04,O11,O15) | P0 | Médio | Alto | Não | R01,R03,R08–R13 | 4 |
| R17 CI iOS + fixture Swift/ObjC, warnings, linkage de constantes e docs/SemVer (O17,O18) | P1 | Médio | Médio | Não | R02; runner/SDK compatível | 0 baseline; automação 3 |
| R18 Observer opcional sanitizado e medição de resultados/duração | P2 | Baixo | Baixo | Não | R08,R11,R14; política do app | 3–4 |
| R19 Helper request legado/OAuthConfig.h/wrapper sem calls; decoder C (O19; S10,S14) | P2 | Baixo | Médio | Não para auditoria; sim se remover uso externo | R01, inventário runtime/licenças | 3, sem remoção automática |
| R20 Atualizar UI deprecated/KVO; async Swift facade/crypto plataforma se benefício (O09,O10; S15) | P3 | Médio | Médio | Não se aditivo | R07,R12; necessidade comprovada | Após 3 |
| R21 Implementar provider2 depois do contrato, segurança e contrato neutro | P0 futuro | Alto | Alto | Não para caminho antigo | R03,R16, contrato servidor, security review | 5, **não executar** |
| R22 Pilotos, coexistência, rollout/rollback e futura retirada de legacy (O01–O04,O18) | P0 futuro | Alto | Alto | Não no rollout; **sim** na retirada em major | R01,R16,R21, backend/equipes | 6 |

(*) Não remove seletores nem muda tipos, mas é alteração comportamental/persistência potencialmente relevante. Keys de defaults podem ser usadas diretamente por apps; R01 pode revelar incompatibilidade que exige opt-in/major. Não anunciar zero impacto sem piloto. Corrigir vulnerabilidade não precisa esperar todas as fases: após reprodução e teste focado, R10–R15 podem ser patches isolados; esta auditoria não os executa.

## Fase 0 — Baseline e inventário

Objetivo: estabelecer contrato observável antes de mover código. Esta auditoria entrega documentação e baseline local, **não completa o gate de refatoração**.

Entregas seguintes: R01/R02, snapshots de seletores/names Swift/headers, fixture ObjC e Swift que compile/linke serviço, testes de persistência/cache/logout/config/erros e baseline de um app real iOS14+. Manter testes existentes. Registrar ausências de runtime UI no host e corrigir infra de CI/testes sem alterar mínimo do package. Caracterizar comportamento atual defeituoso e rotular qual será mudado em hardening; não eternizar bug como requisito.

**Gate:** suíte iOS determinística cobre caminho público básico, sessões incompletas, cache, restauração e logout; fixture Swift/ObjC linka; consumidores classificados por API; nenhum falso sinal de sucesso baseado só em build macOS.

## Fase 1 — Fronteiras internas

Objetivo: reduzir dependências concretas sem mudar wire format/contrato.

Entregas: R04–R07, execução HTTP arbitrária e fake transporte, contrato mínimo de store preservando defaults, browser adapter/instância correta, clock/nonce determinísticos, composição de instância. Testes de cancelamento têm casos baseline e desejados explícitos. Sem protocolos públicos e sem migração geral async/await.

**Gate:** requests, headers, encoding, payloads, keys, cache e callbacks continuam equivalentes nos casos válidos; doubles exercitam falhas sem internet; nenhuma UI de instância autentica singleton inadvertidamente.

## Fase 2 — Encapsulamento OAuth1

Objetivo: concentrar handshake, signer e credencial de identidade em provider1.

Entregas: R08/R09; fachada delega ao coordenador, adapter mantém propriedades/config e etapa WK; provider entrega resultado de identidade sem accessParams vazando ao domínio; backend mobile separado, modelos USP preservados.

**Gate:** testes de contrato público e de provider1 passam; app legado Swift/ObjC mantém selectors/uso; OAuth aparece majoritariamente em provider1/config/adapter e seus testes. Exceção explícita: API legada exportada continua OAuth1 por compatibilidade, sem remoção.

## Fase 3 — Hardening

Objetivo: tornar a implementação existente mais segura e determinística em patches pequenos.

Entregas: R10–R15 e R17, com revisão própria para cada comportamento (Keychain, callback, operação tardia, buffers, payload/status, logs). Provar mudança intencional e retorno compatível por casos. Definir registro obrigatório/opcional, evitando sessão bem-sucedida após registro falho sem política explícita. Documentar logout local/mobile/SSO e expiração desconhecida. R18/R19 opcionais após riscos altos; R20 só se benefício.

**Gate:** nenhum high de cliente sem mitigação ou aceite explícito justificado; tests de falha/concorrência/upgrade/cancelamento passam; servidor e app piloto confirmam OAuth1 válido; observabilidade redigida caso adicionada. Não exigir troca de HMAC ou browser OAuth1 para concluir fase.

## Fase 4 — Preparação da transição

Objetivo: tornar adição do segundo mecanismo localizada, sem implementar OAuth2.

Entregas: R03/R16/R18; contrato do backend especificado e revisado; operações provider, envelope/session policy, config aditiva, escolha interna por app, requisitos de apresentação/cancelamento e limites de wsuserid definidos. Validar provider com double alternativo nos testes sem um segundo protocolo de produção.

**Gate:** um provider de teste pode cumprir o contrato neutro sem tokenSecret; perfil e credencial mobile têm origem/semântica definidas; API antiga continua provider1; refresh/revogação/expiração são capacidades conforme contrato, não assumptions. Rollout/rollback documentados e schemas convivem sem dual-write inseguro.

## Fase 5 — OAuth2 — futura, proibida nesta entrega

Só após contrato/endpoints reais: Authorization Code/PKCE quando aplicáveis, validação de state/redirect, apresentação de sistema, TTL/refresh/scopes/revogação conforme servidor. Reutilizar testes neutros e adicionar testes de protocolo2. Confirmar suporte do backend mobile e autorização de APIs internas; não tratar bearer como wsuserid por inferência.

**Gate futuro:** suite de contrato/provider, security review, backend homologado, piloto e rollback ensaiados. Nenhum código dessa fase nesta auditoria.

## Fase 6 — Migração dos consumidores

Selecionar piloto com uso predominante ensure/currentUser/wsuserid e outro híbrido ObjC/Swift. Primeiro comparar sucesso/cancelamento/falhas e tempos com baseline1, sem IDs pessoais/credenciais. Definir limiares e janela com dados do piloto; não inventar percentuais de sucesso agora. Expandir em pequenos lotes por configuração/release; backend precisa aceitar coexistência.

Rollback: retornar configuração/release para provider1, usar envelope1 ainda válido ou reautenticar explicitamente; nunca converter token2/refresh em secret1. Downgrade deve detectar schema incompatível sem corrompê-lo. Não manter secrets em defaults como estratégia de rollback de Keychain. Não mudar de conta silenciosamente.

Deprecar só após alternativa e guia por API; monitorar versões de consumidores e confirmar eliminação de reads/writes legados. Retirar adapter/API OAuth1 apenas em major planejada com todos os consumidores afetados conhecidos e janela comunicada. OAuth1 no servidor não é desligado pelo SDK unilateralmente.

## Plano de testes prioritário

| Contrato observável | Baseline/lacuna e estratégia | Reuso futuro |
|---|---|---|
| Sucesso completo vs loginInWebView | Zero cobertura; simular tokens→perfil→registro; callback/main uma vez; preservar distinção | Sessão completa neutra reutiliza; handshake/WK específico1 separado |
| Cache/restauração | Suite defaults isolada; tokens+user e todas combinações faltantes, NSNull/JSON inválido, sem wsuserid | Store/session contracts reutilizáveis por envelope |
| Public properties/config | round-trip token/secret/push, precedence appKey/config, Custom, instances vs singleton | Adapter1 permanece testado; API neutra não exige secrets |
| Cancelamento/lifecycle | Botão, swipe iPad, reapresentação, falha WK, callback repetido, delegate substituído, completion uma vez | Resultado cancelado reutiliza; detalhes WK não |
| HTTP/transporte | NSError transporte, 401/403/500, body vazio/form inválido/JSON scalar/dictionary, redirect, non-HTTP | Transport/error contracts comuns; status/payload por endpoint |
| Token inválido | Par request/access incompleto e callback token mismatch; cache sem credential mobile | Sessão inválida/ausente comum; campos OAuth por provider |
| Persistência/logout | ClearSession vs ClearAll, push e flag, falha serialization; logout local não chama invalidar | Contrato store comum; keys antigas só adapter |
| Corrida/concorrência | Dois ensure, login direto paralelo, cancel/logout enquanto token/perfil/registro em voo; ignorar writes tardios | Reutilizável no coordenador e providers |
| Registro/consulta/invalidação | 2xx com body erro, flag, falta wsuserid, status e empty query payload; erro de registro não limpa cache hoje | Cliente mobile comum se contrato permanece |
| Expiração/revalidação | Ausentes; caracterizar ausência/validade desconhecida, check não renova nem invalida | Só adicionar expectativa de TTL/refresh após contrato |
| Callback/deep link | Hoje callback WK/localhost e não app deep link; fixtures destino/mismatch/sufixo/duplicates | Resultado/correlação comum, roteamento por browser/provider |
| Assinatura/encoding | Vetores determinísticos HMAC/base64/base string, Unicode/reservados/tilde, duplicatas/arrays, key longa e const input | Específico provider1, continua regressão no rollout |
| ObjC/Swift export | Compilação e **link** de seletores/modelos/constantes, headers/Swift names e init herdado | Gate de compatibilidade em todas as fases |
| Logs/observer | Payloads sintéticos com marcadores de segredo/PII nunca capturados | Reutilizável independente do protocolo |

Usar fake transport, defaults de suite única e browser double; URLProtocol em session injetada para integração HTTP. Clock/nonce controlados; não swizzlar singletons como solução estrutural. UI apenas onde necessário. Nenhum teste requer backend/credencial real. Testar propriedades do contrato, não nomes de classes privadas. Aumentar cobertura antes de cada extração, executar próximos à mudança e suite ampla iOS após gates.

## Única próxima implementação recomendada

**Concluir R02 da fase 0: testes de caracterização iOS do contrato público de sessão**, sem extrair provider. Uma PR coesa com fixture Swift/Objective-C que compile/linke `USPAuthService`, defaults isolados e testes de setters/getters, restauração, cache parcial, isLoggedIn/currentUser/currentWSUserId, logout local e preservação/limpeza de push. Registrar como baseline os comportamentos divergentes, incluindo a promessa incorreta de logout remoto, para corrigir conscientemente depois.

Usar toolchain que suporte iOS14 e execução iOS15+ disponível; não aumentar deployment target para acomodar este host. Essa tarefa atende o maior vazio de evidência: os seis testes Auth atuais validam parser/modelos/config, mas não instanciam o serviço. Não implementada nesta auditoria.

## Progresso de R02 — 2026-10-01

**R02 concluído para o contrato público de sessão solicitado.** Foram adicionados
18 XCTest iOS: inicialização/restauração, round-trip/persistência, isolamento,
matriz de oito estados, cache incompleto/inválido/NSNull, comportamento em memória
versus defaults e logout local. Fixtures Swift/Objective-C compilaram, linkaram e
executaram contra o product SPM real no harness iOS; snapshot dos cinco headers e
checker leve protegem declarações. Nenhuma produção/API/endpoints foi alterada.

Evidência: **24 testes Auth no Simulator iOS27 passaram, zero falhas/skips**
(18 novos + 6 existentes). Host: 66 passaram e 1 skip explícito da suíte UIKit.
Build/test iOS exigiu override15 apenas na invocação devido ao SDK27; mínimo
**declarado permanece14**, cuja validação em toolchain/runtime apropriado ainda
é limitação. Detalhes, matriz e limites: [validation](validation.md#r02--testes-do-contrato-público-de-sessão)
e [walkthrough R02](../iterations/04-auth-session-baseline/walkthrough.md).

A recomendação R02 na seção anterior é o registro da auditoria original e agora
foi executada neste escopo. Isso **não conclui o gate inteiro da Fase0**: R01 e
apps externos continuam pendentes, assim como testes de login/lifecycle que não
fazem parte desta entrega. Única próxima tarefa recomendada: **R01, inventário do
uso real do contrato nos consumidores**, antes de iniciar extrações da Fase1.

## Progresso de R01 — Cardápio USP — 2026-10-01

**R01 parcialmente concluído.** Primeiro consumidor real auditado em modo somente
leitura: [inventário do Cardápio USP](consumer-api-inventory.md#cardápio-usp).
O registro original de ausência de consumidores refere-se ao baseline anterior;
esta etapa analisou o checkout irmão, sem mudar código, testes ou dependências.

Cardápio usa SPM remoto USPAuthKit desde 1.4.5, resolvido localmente em 1.4.5;
callers Swift/Objective-C usam singleton/config, ensure, currentUser/userData,
logout e updateNotificationToken. Não controla WK de login nem manipula o par
OAuth no código de execução. Entretanto lê `userData`/`isRegistered` por key e
implementa registro mobile próprio. Classificação **D (storage), B na superfície
funcional**: preservar API pública não basta para garantir compatibilidade de
R05/R10. `wsuserid` vai a saldo, Pix, boletos, foto, avisos e registro, além de
caches/diagnóstico. R03 deve confirmar credencial mobile/perfil e esses destinos;
não tratar wsuserid como access token OAuth2.

R02 permanece concluído no escopo registrado acima, sem mudanças nesta etapa.
O gate da Fase 0 permanece aberto: falta lista autoritativa de consumidores e
inventário dos demais relevantes; um app não representa todos. Projetos irmãos
existem, mas sua dependência Auth não foi confirmada. Cardápio é piloto viável
para isolamento interno ainda OAuth1, condicionado a preservar storage/backend;
piloto OAuth2 aguarda contrato servidor e rollout/rollback.

**Única próxima tarefa recomendada: continuar R01, confirmar com as equipes a
lista de consumidores e auditar o próximo consumidor confirmado**, priorizando
usos de tokens, login WK ou keys internas. Não iniciar R04–R08 nesta etapa.
[Validação documental](validation.md#r01--auditoria-do-consumidor-cardápio-usp) ·
[Walkthrough](../iterations/05-consumer-audit/walkthrough.md).

## Composição interna e hardening — 2026-10-01

**Premissa revisada pelo responsável:** controle dos aplicativos permite migração
coordenada. Compatibilidade continua desejável; vazamentos de storage/WK/par OAuth
não são requisitos permanentes. A instrução anterior de aguardar fechamento de
R01 para R04–R08 foi supersedida por autorização explícita desta implementação.
R01 segue parcial e não se extrapolou a evidência do Cardápio.

Estado efetivo: [arquitetura implementada](../authentication/architecture.md),
[guia de consumidores](../authentication/consumer-migration.md),
[walkthrough](../iterations/06-auth-composition/walkthrough.md) e
[validação](validation.md#composição-interna-e-hardening--2026-10-01).

| Item | Progresso comprovado / gate restante |
|---|---|
| R02 | Mantido intacto; 24 testes Auth do baseline executados antes/depois |
| R04 | Implementado: transporte privado arbitrário + URLSession adapter e cancel handle, aplicado tokens/perfil/mobile; fake/URLProtocol sem internet |
| R05 | Implementado: contrato privado de sessão e adapter defaults legado; isolamento/corrupt/partial/clear testados. Sem alteração schema/Keychain |
| R06 | Implementado: UI pertence à operação/instância; browser privado, callback consumido uma vez, cancel/finish/KVO cleanup. Homologação UI real/piloto ainda necessária |
| R07 | Implementado: clock/nonce injetáveis e vetores request/access/profile/base string/HMAC/encoding/header; formato/política legada preservados |
| R08 | Implementado: provider1/coordinator/fachada, adapters públicos, composição privada com provider alternativo sintético sem OAuth1 |
| R09 | Implementado: identidade + credencial mobile opaca e cliente registro/consulta/invalidação/push sem secret; endpoints/payloads preservados |
| R11 | Proteções S02/S03 implementadas e testadas: destino/correlação, completion única, generations, logout/cancel/late/mobile. **Parcial no gate de homologação:** confirmar callback real/piloto, swipe e apresentação real |
| R12 | Concluído no escopo S04: quatro casos reproduzidos, buffers próprios/const, digests iguais, testes C com ASan/UBSan e concorrência; vetores OAuth iOS passam |
| R10 | Não executado: credenciais continuam em defaults; migração Keychain própria, transacional e versionada |
| R13–R15 | Não concluídos: status/payload/registro, logs/PII e políticas nonce/time/redirect; não corrigidos incidentalmente |
| R16 | Fronteira neutra demonstrada com double; envelope/config/capabilities/coexistência ainda dependem R03. Não concluído |
| R21/OAuth2 | Não implementado |

Gates locais das extrações Fases1/2: build iOS, suite com fakes, baseline R02,
fixtures ObjC/Swift e checker passam. Isso não prova autenticação com servidor
real nem compatibilidade iOS14/runtime antigo. Gate operacional/piloto permanece
aberto; Fase0 completa e Fase3 inteira **não** foram marcadas concluídas.
Headers públicos intactos; sem breaking change de assinatura ou de persistência.
Comportamentos de segurança mudaram deliberadamente: callback antes tolerado é
rejeitado; cancel/logout concluem operações em voo uma vez e impedem writes
posteriores. Adapters não têm depreciações compiláveis novas.

**Única próxima tarefa: R03 — especificar com backend o contrato de identidade e
credencial mobile para OAuth2**, incluindo obtenção/relação de wsuserid, perfil,
registro/push, endpoints/redirect suportado, capacidades de renovação/revogação e
coexistência/rollback. Usar o Cardápio e os contratos executáveis como evidência;
não assumir que bearer substitui wsuserid. Essa especificação deverá definir o
escopo de R16 e os pré-requisitos de R21. Nenhuma implementação OAuth2 nesta etapa.

## Revisão do domínio — 2026-10-02

Informação confirmada pelo responsável: **wsuserid é identificador operacional USP
integrante do perfil padrão entregue aos apps**, não credencial de um provider.
A descrição anterior de MobileCredential era uma hipótese arquitetural e foi
substituída. USPMobileCredential apenas envolvia esse campo e foi removido.
Backend conserva metadata de app/push e flag local; usa USPAuthUser.wsuserid.

Configuração interna da aplicação agora é distinta da configuração específica
OAuth1; USPAuthConfig combinado permanece adapter público. Identidade tipada
USPAuthUser/USPAuthVinculo pode ser produzida sem JSON de protocolo. Fake independente
prova autenticação nova + perfil completo + registro com duas configs de app.
R02 continua intacto; ver [arquitetura](../authentication/architecture.md) e
[walkthrough](../iterations/07-auth-domain-review/walkthrough.md).
Não foi especificado/modelado outro protocolo; R03 não foi executado.


## Regressão de integração OAuth1 — 2026-10-02

Trace real Cardápio/iPhone confirmou callback localhost e correlação válidos;
erro de navegação102 depois do handoff cancelava access exchange. Patch mínimo no
browser distingue callback consumido de apresentação concluída, sem relaxar
validação e sem ignorar102 antes do callback. Reprodução XCTest falhou antes;
62Auth iOS passam depois, incluindo baseline/fake/fixtures e controles de cancel.
**R11/gate de homologação ainda aberto:** falta nova tentativa real pós-patch com
perfil/wsuserid/registro/completion e navegação Cardápio. Não iniciar outra etapa
com base apenas na suite. [Causa/evidência](../iterations/08-oauth1-integration-regression/walkthrough.md).


## Homologação OAuth1 e investigação de perfil — 2026-10-02

Responsável homologou fluxo real Cardápio/iPhone após patch browser: tokens,
perfil, registro, completion e uso de wsuserid em recursos bem-sucedidos.
Gate desse fluxo real de R11 atendido; controles gerais de apresentação/swipe/
ambientes não foram universalmente homologados. Registros anteriores de
homologação pendente são históricos. Problema separado: Perfil sem vínculos;
[diagnóstico09](../iterations/09-profile-relationships/walkthrough.md) instrumenta
estrutura sem PII e protege metadata/restauração. 66Auth iOS passaram. Não marcar
paridade completa de perfil até observar contagens reais. Sem OAuth2 ou nova fase.
