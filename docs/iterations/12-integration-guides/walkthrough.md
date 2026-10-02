# Guias vigentes de integração e migração

## Objetivo e resultado

Consolidada a orientação dos consumidores em
[docs/integration/new-integration.md](../../integration/new-integration.md) e
[docs/integration/legacy-migration.md](../../integration/legacy-migration.md).
README é a porta de entrada; a [arquitetura](../../authentication/architecture.md)
continua referência interna. Nenhum código, teste, header, manifest ou cliente foi
alterado; nenhum commit foi feito.

## Baseline e decisões

Lidos README, Package.swift, cinco headers exportados, quatro implementações
públicas, arquitetura, guias anteriores, validação, walkthroughs de composição,
domínio, browser, perfil, consolidação e organização física, e inventário Cardápio.
Consulta estática read-only no consumidor confirmou snapshot raw, parsing de
vínculos e flag/registro próprio. Não foram copiados valores sensíveis.

O posicionamento público é autenticação + sessão + perfil USP. OAuth1 é provider
atual; nenhum mecanismo futuro foi especificado. Recomendados facade, perfil
canônico e vínculos tipados. wsuserid conserva semântica de identificador
operacional USP para recursos que usam esse contrato, sem equiparação a OAuth
access token/número USP ou promessa de validade remota.

Configuração pública combinada permanece necessária ao provider atual; consumer
key/secret por aplicativo não são requisitos universais do domínio. Secret
embarcado não é segredo seguro. APIs complementares mobile/push têm finalidade
própria e não são passos universais de login.

A matriz não inventa substitutos: campos como codpes/número USP específico/foto,
aliases de vínculos e estado remoto de registro não possuem getters equivalentes
no SDK. Compatibilidade necessária deve ficar isolada/documentada até alternativa
pública. currentUser e isLoggedIn mantêm suas semânticas locais distintas.
Logout é local, apesar do comentário histórico divergente no header preservado.

## Organização documental

- README: Quick Start autocontido, requisitos e navegação; material de
  observabilidade preservado, removidos exemplos Auth redundantes/incompletos.
- Dois guias canônicos: configuração/login/perfil/sessão/logout/push/erros e
  migração incremental, matriz, estudo de caso, smoke e rollback.
- Guias anteriores em docs/authentication: apontadores curtos, preservando links
  antigos sem manter duas orientações concorrentes.
- Architecture/roadmap: somente navegação para os destinos atuais.
- Walkthroughs históricos: preservados; seus links antigos continuam resolvendo
  para os apontadores. Esta iteração tem plano e registro próprios.

## Validação

Verificador temporário em `/tmp/uspauth-doc-check.py`: percorreu todos os Markdown
versionados e novos, excluindo blocos de código da extração de links; verificou
existência de destinos locais e âncoras de headings. Nenhum destino/âncora local
inválido. Links externos preexistentes não receberam teste HTTP nesta tarefa.
Comparação byte a byte dos cinco headers com HEAD aprovada. O checker existente
`python3 scripts/check-auth-public-api.py` também aprovou cinco headers.

Compile-check temporário em `/tmp/uspauth-snippet-check.py`: extraiu todos os
snippets Swift/Objective-C Auth do README e dos novos guias e gerou modulemap do
umbrella header real. **9 snippets Swift e 1 Objective-C aprovados, sem warnings
na execução final.** Swift usou `xcrun swiftc -typecheck -swift-version 6`, clang
usou `-fsyntax-only -fobjc-arc -fmodules`; SDK iPhoneSimulator27, target
arm64-apple-ios15.0-simulator, caches/snippets fora do repo.

A primeira checagem detectou warnings Sendable/MainActor nos exemplos Swift.
Corrigidos somente nos exemplos: handler do app MainActor/Sendable e dispatch
explícito para UI. Não usados async/await, APIs públicas inventadas ou alterações
em annotations dos headers. Compile-check confirma nomes importados e tipos;
**não é linkage nem execução de autenticação**. Não houve novo login/smoke físico
ou reexecução das suítes por uma mudança exclusivamente documental.

`git diff --check` aprovado. Lista final de alterações contém somente `.md`;
Sources, Tests, Package.swift e Cardápio não foram modificados. Scripts temporários
não são entregues como infraestrutura do package.

## Compatibilidade e limites

Sem breaking changes, deprecações, alteração OAuth1, endpoints, Keychain ou código
produtivo. Runtime iOS14 sem validação registrada permanece lacuna; homologação
anterior no Cardápio não foi extrapolada a outros apps/versões/fluxos. Tag de release
arquitetural não identificada pelo checkout: não foi inventada nos guias.

Próximo uso desta documentação: migrar um conjunto pequeno de acessos de perfil
já cobertos por USPAuthUser no consumidor escolhido, com seus próprios testes e
smoke físico. Dados não modelados continuam explicitamente pendentes; nenhuma
migração do Cardápio foi executada nesta iteração.
