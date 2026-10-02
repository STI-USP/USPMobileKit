# Diagnóstico de vínculos — estado parcial

> Registro histórico da investigação. Encerrada por homologação do responsável
> em 2026-10-02: OAuth1 real completou; DEV tinha vínculos vazios, PROD vínculos
> esperados, perfil/metadata/restauração preservados. Diagnóstico temporário foi
> removido na [consolidação10](../10-auth-consolidation/walkthrough.md).
> Pendências mencionadas abaixo descrevem a execução anterior, não o estado atual.


2026-10-02. O responsável confirmou homologação OAuth1 real no iPhone depois do
patch do browser: request/access/profile/registro 200, perfil tipado/wsuserid e
completion presentes, wsuserid funcional nas demais requisições. O problema
atual é isolado à exibição de vínculos. Nenhuma mudança OAuth/browser/HTTP/cliente.

## Comparação comprovada

Baseline a0e523e: fetchUserData parseia NSDictionary e o grava diretamente em
sessionStore.userData. Atual: provider parseia NSDictionary →
USPIdentity.initWithMetadata copia o dicionário sem normalização → coordinator
updateIdentity → store serializa identity.metadata em NSData JSON → facade lê
loadSession.identity.metadata. Não há reconstrução pelo modelo neste caminho.
initWithUser serializa modelo para compatibilidade, mas pertence ao caminho
alternativo de identidade tipada; OAuth1 não o chama.

USPAuthUser.m e USPAuthVinculo.m não diferem de a0e523e. O parser tipado aceita
somente array singular vinculo, ignora itens não-dictionary. Não interpreta
plural vinculos/dictionary singular. O dicionário cru preserva essas variantes.
Isso é comportamento legado, não causa comprovada da ausência visual atual.

Cardápio AuthenticationService.swift encaminha service.userData no snapshot.
ProfileViewModel.resolveVinculos usa vinculo ?? vinculos; aceita array ou dictionary,
mas compactMap descarta item sem role e unit. Role usa nomeVinculo/tipoVinculo/
tipoUsuario/perfil e fallback topo; unit usa nomeUnidade/siglaUnidade/unidade e
fallback topo. Singular presente (inclusive vazio/null) precede plural. Dedup
pode reduzir quantidade. Assim, contagem no raw não garante contagem exibida.
Não alterado nem executado consumidor pelo agente.

## Instrumentação

Somente DEBUG, estrutura/contagens: profile relationships (raw, user_count,
identity_count e identity_metadata), persisted profile relationships (identity e
legacy_userdata), legacy userData relationships (snapshot lido, restored_user_count).
Campos vinculo/vinculos: presença, tipo allowlisted e contagens; selected_count
respeita precedência singular/plural do consumidor. Dictionary conta como um
candidato, array conta elementos brutos, null/ausência/scalar como zero. Nenhum
conteúdo, nome, código, unidade, wsuserid ou classe dinâmica é emitido.

## Evidência automatizada

Três testes novos: fluxo OAuth1 fake inteiro conserva dois vínculos singulares,
plural concomitante, aliases e campos não modelados no JSON/identity/userData/
restauração; plural/dictionary/null preservados no raw apesar do parser tipado
legado ignorá-los; diagnóstico sem marcador privado. Suite isolada de defaults,
sem rede. Fixture **sintética baseada no baseline**, não representa ainda o shape
real do iPhone. Teste exato da regressão aguarda diagnóstico real.

Primeira execução:65pass/1fail causado por fixture sem configuração de facade;
syncMobileConfiguration substituiu baseURL pelo default vazio. Corrigida apenas
fixture com service.config = provider.config. Segunda:66Auth iOS passaram,
0fail/skip/warnings,69,9s; R02 e fixtures Swift/ObjC executadas intactas.
Bundle /tmp/uspauth-relationships-fixed-fixture.xcresult. API5headers inalterados.

## Limite e próximo dado

Quantidades reais JSON/modelo/identidade/userData ainda desconhecidas. Não há
primeira transformação de perda comprovada nem correção funcional autorizada
pela evidência. Solicitado login novo e abertura de Perfil com três eventos
sanitizados. Não pedir JSON/PII. Se raw já vier vazio ou metadata permanecer
intacto, distinguir contrato do endpoint de filtragem do consumidor antes de
propor mudança. Não normalizar/chamar plural de causa sem trace.

Compatibilidade: produção alterada somente para diagnóstico DEBUG, sem API,
endpoints, payload/schema/persistência ou comportamento de parsing novos.

Validação adicional: swift test host terminou sem falhas (59 testes gerais +7
Auth, dos quais1skip explícito UIKit;65pass/1skip). Cross-build iOS15 --build-tests
compilou/linkou; warnings XCTest/SDK já conhecidos. Logs efêmeros
/tmp/uspauth-relationships-{host,cross}.log. Host não executa serviço iOS.
