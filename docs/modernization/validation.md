# Validação da auditoria

> Estado consolidado em 2026-10-02: diagnóstico temporário removido,64Auth iOS
> executados com sucesso; host65pass/1skip; cinco headers inalterados; C sanitizado
> aprovado. Homologação real Cardápio/perfil/vínculos confirmada pelo responsável.
> Registros de ausência de login/trace/homologação abaixo são históricos.
> Detalhes atuais: [consolidação10](../iterations/10-auth-consolidation/walkthrough.md).


Executada em 2026-10-01 sobre `11d9582`, macOS arm64, Xcode 27.0 build 27A266a, Apple Swift 6.4. Package continua tools 6.1 / iOS14. Nenhum source, teste, manifest ou configuração foi modificado. Fixtures/harnesses e caches diagnósticos foram criados em `/tmp`, fora do repositório.

## Resultados

| Comando / verificação | Resultado | Limite |
|---|---|---|
| `git status --short` inicial | Limpo | Baseline sem mudanças do usuário |
| `swift build` | Primeira tentativa falhou: module cache padrão sem permissão | Falha ambiental de cache, não manifest inválido por sintaxe |
| `swift package dump-package` | Primeira tentativa falhou pela mesma permissão | Reexecutado abaixo |
| `swift package --disable-sandbox dump-package` com caches em /tmp | Sucesso, JSON válido: dois products, cinco targets, sem dependencies, iOS14 | Manifest validado; não valida distribuição dos consumers |
| `swift build --disable-sandbox` com caches em /tmp | Sucesso, Build complete (4,73 s) | Host macOS exclui implementações UIKit |
| `swift test --disable-sandbox` com caches em /tmp | **66 XCTest, zero falhas**: 6 Auth + 59 Observability + 1 compatibility | Execução host; Swift Testing informa zero testes próprios, além dos XCTest; sem porcentagem de cobertura |
| `xcodebuild -version` | Xcode 27.0 / 27A266a | Versão instalada |
| `xcodebuild -list -json -clonedSourcePackagesDirPath /tmp/uspauth-sourcepackages` | Falhou: directory does not contain project/workspace/package | CLI instalado não reconheceu package direto; não há xcodeproj/xcworkspace versionado |
| `xcodebuild -scheme USPAuthKit -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/uspauth-derived-data -clonedSourcePackagesDirPath /tmp/uspauth-sourcepackages CODE_SIGNING_ALLOWED=NO build` | Mesma falha de reconhecimento | Não afirmar build Xcode concluído |
| `xcrun simctl list devices available` | Falhou: CoreSimulatorService connection invalid/refused, logs sem permissão | Execução de testes/UI em Simulator não disponível nesta sessão |
| Cross-build SwiftPM target arm64-apple-ios14.0-simulator | Falhou: SDK instalado suporta deployment 15–27 | Não aumentar mínimo declarado; validar iOS14 com toolchain compatível |
| Cross-build SwiftPM target arm64-apple-ios15.0-simulator | **Sucesso**, Build complete (4,84 s); inclui implementação ObjC/UIKit | Compila sources, não executa testes nem linka app consumidor |
| Smoke compile ObjC via generated module map, target iOS14 | Sucesso, syntax-only/ARC/modules, sem warnings | Seletores principais importam; não é teste runtime ou linkage de constantes |
| Smoke Swift typecheck target iOS15 | Primeiro revelou README inválido `configure(withEnvironment:)`; com `configure(with:)` passou | Valida shared/ensure/login(in:)/initializer/defaults/User/logout, não todos os símbolos |
| `plutil -lint` nos dois PrivacyInfo.xcprivacy | Ambos OK | Valida plist, não certifica privacidade/App Store/aggregation |
| Harness C HMAC/SHA1 com Python ctypes | Quatro digests coincidem com hashlib; mutação em entrada longa confirmada | Diagnóstico externo, não suíte completa; [evidência](security-audit.md) |
| CI/lint/scripts/testes ObjC | Não encontrados versionados | Não houve pipeline/linter ou testes ObjC existentes para executar |
| Verificação documental final | Links relativos locais resolvem, símbolos públicos explicitamente inventariados, diff sem whitespace errors | Mermaid revisto por inspeção, sem renderer configurado |

## Comandos reproduzíveis de SwiftPM

Caches externos padrão são read-only neste ambiente. `--disable-sandbox` desabilita somente sandbox de avaliação do manifest SwiftPM; não solicita escalonamento nem altera permissões do ambiente.

```sh
mkdir -p /tmp/uspauth-audit-cache
CLANG_MODULE_CACHE_PATH=/tmp/uspauth-audit-cache SWIFTPM_MODULECACHE_OVERRIDE=/tmp/uspauth-audit-cache swift package --disable-sandbox dump-package
CLANG_MODULE_CACHE_PATH=/tmp/uspauth-audit-cache SWIFTPM_MODULECACHE_OVERRIDE=/tmp/uspauth-audit-cache swift build --disable-sandbox
CLANG_MODULE_CACHE_PATH=/tmp/uspauth-audit-cache SWIFTPM_MODULECACHE_OVERRIDE=/tmp/uspauth-audit-cache swift test --disable-sandbox
CLANG_MODULE_CACHE_PATH=/tmp/uspauth-audit-cache SWIFTPM_MODULECACHE_OVERRIDE=/tmp/uspauth-audit-cache swift build --disable-sandbox --scratch-path /tmp/uspauth-ios-build --triple arm64-apple-ios14.0-simulator --sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk
CLANG_MODULE_CACHE_PATH=/tmp/uspauth-audit-cache SWIFTPM_MODULECACHE_OVERRIDE=/tmp/uspauth-audit-cache swift build --disable-sandbox --scratch-path /tmp/uspauth-ios15-build --triple arm64-apple-ios15.0-simulator --sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk
plutil -lint Sources/USPAuthKit/PrivacyInfo.xcprivacy Sources/USPObservabilityKit/PrivacyInfo.xcprivacy
```

Smoke fixtures temporárias `/tmp/uspauth-objc-consumer.m` e `/tmp/uspauth-swift-consumer.swift` usam somente dados sintéticos `example.invalid`/fixture. ObjC usa `@import USPAuthKit`; uma tentativa inicial com path de module map incorreto e outra com import estilo framework foram corrigidas somente no harness. Swift usa `configure(with:...)`, `shared()`, `ensureLoggedIn(from:)`, `login(in:)`, `USPAuthService(userDefaults:)`, `currentWSUserId()`, `USPAuthUser(dictionary:)`, `logout()`.

```sh
xcrun clang -fsyntax-only -fobjc-arc -fmodules -fmodules-cache-path=/tmp/uspauth-audit-cache -target arm64-apple-ios14.0-simulator -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk -ISources/USPAuthKit/include -fmodule-map-file=/tmp/uspauth-ios15-build/out/Intermediates.noindex/GeneratedModuleMaps-iphonesimulator/USPAuthKit.modulemap /tmp/uspauth-objc-consumer.m
xcrun swiftc -typecheck -target arm64-apple-ios15.0-simulator -sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk -module-cache-path /tmp/uspauth-audit-cache -I Sources/USPAuthKit/include -Xcc -fmodule-map-file=/tmp/uspauth-ios15-build/out/Intermediates.noindex/GeneratedModuleMaps-iphonesimulator/USPAuthKit.modulemap /tmp/uspauth-swift-consumer.swift
```

## Warnings e limitações

- SwiftPM: configuração/security/cache user-level inacessíveis e tentativa de gravação de manifest em database read-only; não impedem retry com module caches em /tmp.
- iOS15: `LoginWebViewController.m:26`, `disposeWebView` declarado e não implementado; `USPAuthService.m:198`, `UI_USER_INTERFACE_IDIOM` deprecated desde iOS13. Não corrigidos nesta auditoria.
- Xcode: assertions de FileTypes plist e serviço de Simulator inacessível. Sem evidência de falha funcional introduzida, pois código intacto.
- Sucesso host não testa Service/UI; sucesso cross-build não testa runtime/cancelamento/network/Keychain. Não há testes de um consumidor externo, iOS14 runtime, archive/Privacy Report ou backend real.
- `USPAuthKitVersionNumber/String` não têm definição encontrada; syntax-only e build sem referência não provam linkage desses símbolos.
- Não foi criado teste permanente para mudança documental. Testes futuros/gates estão no [roadmap](modernization-roadmap.md).

Logs completos desta sessão em `/tmp/uspauth-swift-build.log`, `uspauth-swift-build-retry.log`, `uspauth-swift-test.log`, `uspauth-package-error.log`, `uspauth-xcode-list.log`, `uspauth-xcode-build.log`, `uspauth-ios-build.log` e `uspauth-ios15-build.log`; são efêmeros, não necessários para interpretar os resultados registrados aqui.

## R02 — Testes do contrato público de sessão

Implementação em 2026-10-01, sobre a mesma produção `11d9582` e os sete documentos
de auditoria. **R02 concluído para o escopo de sessão solicitado:** 18 novos
XCTest executaram contra UIKit/USPAuthService real, com fixtures Swift e ObjC
compiladas, linkadas e executadas. Não houve alteração em `Sources`, APIs,
endpoints, persistência, crypto ou deployment declarado. A limitação iOS14 abaixo
permanece; isso não significa conclusão de toda a Fase0/R01 nem de testes de login.

### Artefatos e execução

- `Tests/USPAuthKitTests/USPAuthServiceSessionTests.swift`: 18 métodos XCTest iOS;
  no host há apenas um skip explícito, sem emular serviço de produção.
- `Tests/USPAuthKitTests/Fixtures/SwiftSessionConsumerFixture.swift`: consumidor
  Swift público, invocado pelo teste de init/configuração/consumidores.
- `Tests/USPAuthKitObjCFixture`: consumidor ObjC e helper/spy somente de testes.
  Package adiciona target auxiliar e dependência **apenas iOS do testTarget**, sem
  novo product ou dependência dos produtos existentes.
- `Tests/iOSSessionHarness`: projeto/scheme compartilhado mínimo, referência ao
  package local, mesmos testes Swift e fixture ObjC via bridging header; sem
  cópia/substituição da implementação de Auth.
- `Tests/APIBaseline/USPAuthKit/*.h` + `scripts/check-auth-public-api.py`: snapshot
  leve de cinco headers, incluindo selectors, tipos, propriedades e nullability.

| Validação | Compilou | Linkou | Executou / resultado |
|---|---|---|---|
| SwiftPM host `swift build --disable-sandbox` | Sim | Bibliotecas | Sucesso; implementação UIKit continua excluída |
| SwiftPM host `swift test --disable-sandbox` | Sim | Bundles host | 67 XCTest encontrados: **66 passaram, 1 skip explícito de sessão**, zero falhas |
| SwiftPM cross-build iOS15 com `--build-tests` | Sim, todos os targets/testes | Sim, produtos de testes | Build complete (11,42 s); não executa Simulator |
| Harness Xcode iOS, primeira tentativa com mínimo14 | Não concluiu | Não | SDK27 rejeita deployment14; erro ambiental conhecido |
| Harness Xcode iOS, override15 apenas na invocação | **Sim** | **Sim** | **24 passaram, zero falhas/skips**, iPhone18Pro iOS27.0 arm64 |
| Fixture Swift `configure(with:)`, `configure(with: config)`, shared/init/getters/setters/state/logout | Sim | Sim, no XCTest iOS | Executada e assertions passaram |
| Fixture ObjC sharedService/initWithUserDefaults/config/properties/state/logout | Sim | Sim, no XCTest iOS | Executada: seis resultados booleanos verificados; spy de invalidação passou |
| Baseline headers | Script Python | Não aplicável | 5 headers iguais; cópias temporárias com mudança de nullability/selector/tipo foram rejeitadas; comentário aceito |
| `plutil -lint project.pbxproj`, `git diff --check` | Não aplicável | Não aplicável | Sem erros |

O cross-build inicial dos novos testes encontrou captura Swift que precisava de
`[self]` no bloco de fixture. Foi corrigida apenas no teste; retry passou. Nenhuma
mudança de produção foi necessária. Os warnings preexistentes de
`disposeWebView` não implementado e `UI_USER_INTERFACE_IDIOM` deprecated continuam.
Cross-build tests15 também avisa que XCTest/libXCTestSwiftSupport do SDK27 têm
mínimo17: não interpretar linkage de testes como suporte runtime iOS15. A execução
comprovada foi em iOS27. Caches SwiftPM continuam emitindo warnings ambientais.

### Comandos e infraestrutura

```sh
CLANG_MODULE_CACHE_PATH=/tmp/uspauth-r02-cache SWIFTPM_MODULECACHE_OVERRIDE=/tmp/uspauth-r02-cache swift build --disable-sandbox
CLANG_MODULE_CACHE_PATH=/tmp/uspauth-r02-cache SWIFTPM_MODULECACHE_OVERRIDE=/tmp/uspauth-r02-cache swift test --disable-sandbox
CLANG_MODULE_CACHE_PATH=/tmp/uspauth-r02-cache SWIFTPM_MODULECACHE_OVERRIDE=/tmp/uspauth-r02-cache swift build --disable-sandbox --build-tests --scratch-path /tmp/uspauth-r02-ios-build --triple arm64-apple-ios15.0-simulator --sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk
python3 scripts/check-auth-public-api.py
plutil -lint Tests/iOSSessionHarness/USPAuthSessionHarness.xcodeproj/project.pbxproj
```

O shell ainda não acessa CoreSimulator (`simctl list` falhou). **XcodeBuildMCP
conseguiu listar os runtimes e executar os testes**, superando a limitação da
auditoria anterior. Tools: list_sims, session_show_defaults, session_set_defaults,
test_sim; projeto `Tests/iOSSessionHarness/USPAuthSessionHarness.xcodeproj`, scheme
`USPAuthSessionHarness`, configuration Debug, derivedData `/tmp/uspauth-r02-derived`.
A execução equivalente foi:

```sh
xcodebuild -project Tests/iOSSessionHarness/USPAuthSessionHarness.xcodeproj \
  -scheme USPAuthSessionHarness -configuration Debug \
  -destination 'platform=iOS Simulator,id=17D3A700-4CA8-42F5-A1D3-FB5DC58753F0' \
  -derivedDataPath /tmp/uspauth-r02-derived IPHONEOS_DEPLOYMENT_TARGET=15.0 \
  -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 \
  -resultBundlePath /tmp/uspauth-r02-ios-tests-15.xcresult test
xcrun xcresulttool get test-results summary --path /tmp/uspauth-r02-ios-tests-15.xcresult
```

O summary do xcresult confirmou 24 passed / 0 failed / 0 skipped, runtime iOS27.0
build24A434. Tempo total MCP 84,9 s, execução XCTest 10,034 s. `nm` do binário
XCTest confirmou `_OBJC_CLASS_$_USPAuthService`, funções ObjC da fixture e função
Swift exerciseSwiftSessionConsumer definidas. O teste que chama as duas fixtures
passou, fornecendo evidência de execução além de linkage.

### Matriz executada

`userData válido` aqui significa dicionário não vazio com `wsuserid` sintético;
nenhuma validade no backend foi consultada.

| Token | Secret | userData | isLoggedIn | currentUser | currentWSUserId |
|---|---|---|---|---|---|
| nil | nil | ausente | false | nil | nil |
| valor | nil | ausente | false | nil | nil |
| nil | valor | ausente | false | nil | nil |
| valor | valor | ausente | false | nil | nil |
| nil | nil | válido | false | presente | credencial mobile |
| valor | nil | válido | false | presente | credencial mobile |
| nil | valor | válido | false | presente | credencial mobile |
| valor | valor | válido | true | presente | credencial mobile |

Casos adicionais executados: perfil não vazio só com campo desconhecido + par
OAuth conta como loggedIn, mas sem wsuserid; ausência/NSNull/número no wsuserid
retorna nil no serviço e string vazia no modelo; wsuserid string vazia é devolvido
como vazio. JSON inválido/vazio/null/array/dictionary vazio ou armazenamento não
NSData não produz usuário/sessão, mas não é apagado automaticamente. userData é
relido, currentUser remapeado e nova instância restaura o schema legado.

### Comportamentos legados protegidos e limites

- Tokens sem perfil não bastam; perfil sozinho produz currentUser/credencial
  mobile sem sessão OAuth completa. isRegistered não muda isLoggedIn.
- appKey/header/config são somente memória; atribuir config na instância não
  sincroniza appKey. Config inicial é nil apesar de nonnull no header.
- Push vazio permanece vazio em memória, mas não persistido; getters OAuth
  recarregam defaults e retornam nil após setters vazios.
- Remover tokens diretamente dos defaults não apaga tokens já em memória:
  getters e isLoggedIn podem divergir. Não corrigido.
- Logout remove par OAuth, perfil, push, plataforma persistida e isRegistered;
  plataforma em memória/nova instância fica F. Preserva config/appKey/header e
  key não relacionada. É síncrono/idempotente; spy comprova **zero chamadas aos
  dois métodos públicos de invalidação**, não ausência universal de requests.

Cada teste usa suite UUID descartável, limpa antes/depois; a matriz também limpa
entre linhas. Nenhum teste lê/escreve valores dos defaults reais. Só o teste
síncrono de init/shared/configuração substitui temporariamente o método de classe
standardUserDefaults; restaura IMP em @finally e limpa singleton/suite ao final.
Scheme/execução não paralelizam testes no mesmo processo. Sem mock estrutural de
transporte/store/provider e sem swizzle de métodos do SDK.

Não cobertos nesta tarefa: autenticação interativa/cache de ensure, lifecycle,
rede/HTTP real, callback tardio, servidor/expiração, browsers/cookies, Keychain,
consumidores externos e **runtime/build com SDK compatível com iOS14**. Constantes
C de versão continuam sem definição conhecida e fora da amostra linkada. Não
corrigidos S01–S15; esta é caracterização do escopo R02, não hardening.

Evidência completa efêmera: `/tmp/uspauth-r02-ios-tests-15.xcresult`, logs host e
cross-build `/tmp/uspauth-r02-*.log` e build log MCP
`~/Library/Developer/XcodeBuildMCP/workspaces/USPMobileKit-fce94c906d9b/logs/test_sim_2026-10-01T20-00-49-707Z_pid55850_f032420e.log`.

## R01 — Auditoria do consumidor Cardápio USP

2026-10-01. Auditoria **estática/documental**, consumidor em `../Cardapio USP`,
Git HEAD `84e55bc65a7453951ad4f27b2829e9e5c3245bb6`. Sem código/tests/configuração
alterados. Baseline dos sete documentos lido; R02 mantido intacto.

Validações executadas:

- `git -C '../Cardapio USP' status --short` e `rev-parse HEAD`: tree limpo e revisão
  identificada; status repetido ao final.
- `rg --files`, `git ls-files`, buscas de APIs, keys, runtime, OAuth e leitura
  contextual de callers/wrappers: evidências com arquivo/linha no
  [inventário](consumer-api-inventory.md). A busca inicial encontrou artefatos
  locais de TestResults; foram excluídos do inventário de callers e a busca foi
  refeita sobre arquivos rastreados. Credenciais de configuração foram omitidas
  da saída e da documentação.
- `plutil -convert json -o - <project.pbxproj>` (leitura por Python): product
  Frameworks do app e targets identificados sem resolver dependências.
- Leitura JSON do lock local e plist: pin USPAuthKit 1.4.5/revisão identificado;
  lock não rastreado, nenhuma atualização. Settings/valores sensíveis não copiados.
- Comparação SHA256 do conjunto de arquivos rastreados + untracked não ignorados
  de ambos os projetos, excluindo somente docs do USPMobileKit: idêntico antes e
  depois da escrita documental. Protege Sources, Tests (inclusive R02), Package,
  scripts, README e arquivos rastreados/não ignorados do consumidor.
- Verificação de referências arquivo/linha do inventário, links documentais locais
  e `git diff --check`: sucesso. Novos documentos também verificados quanto a
  whitespace, pois arquivos não rastreados não entram em diff --check.

**Compilação/linkage/execução nesta etapa: não realizados.** Não se executou
swift build/test, xcodebuild, testes iOS/ObjC/Swift do Cardápio, autenticação,
requests remotos ou resolução SPM: a tarefa é somente auditoria de consumidor.
Os resultados executáveis de R02 na seção anterior continuam sendo o baseline
do SDK, não prova da integração de execução do Cardápio 1.4.5 com o SDK atual.

Limites: não confirma backend/validade de wsuserid/fallbacks, versão publicada do
app, outras máquinas/consumidores, UI e callbacks tardios. R01 parcial; Fase 0 não
fechada. Nenhuma mudança de produção ou correção de segurança.

## Composição interna e hardening — 2026-10-01

Base da implementação: `a0e523e`, branch `feature/auth-architecture-modernization`.
Documentos obrigatórios lidos antes de código; R02 e fixture baseline preservados.
Sessão iniciada em 2026-10-01 local; artifacts MCP podem ter timestamp 2026-10-02 UTC.

### Evidência antes e depois

| Validação | Compilou / linkou | Executou / resultado |
|---|---|---|
| Baseline antes de refatorar, iOS harness via XcodeBuildMCP | Sim / sim, SDK27, override15 | **24 Auth passaram**, 0fail/0skip; `/tmp/uspauth-modern-baseline.xcresult` |
| Final iOS harness + implementação real product SPM | Sim / sim | **55 Auth passaram**, 0fail/0skip, 45,7s; `/tmp/uspauth-modern-complete.xcresult` |
| R02 e 6 testes Auth prévios | Sim / sim | Os mesmos24 passaram; fontes/fixtures não alteradas |
| 31 XCTest ObjC de arquitetura | Sim / sim | Passaram; provider/browser/transport fakes e URLProtocol, sem internet/credenciais reais |
| Fixture Swift | Sim / sim | Executada dentro do teste R02 de consumers; nomes importados mantidos |
| Fixture Objective-C | Sim / sim | Executada dentro do mesmo teste; selectors e linkage reais |
| SwiftPM host build/test | Sim / sim para targets host | **66 passaram +1skip explícito UIKit**, zero falhas; não cobre coordinator/provider/UI iOS |
| SwiftPM `--build-tests` cross iOS15 Simulator | Sim / sim, produtos de testes | Build complete; não executa. XCTest SDK exige versão mais recente, linker warnings descritos abaixo |
| Checker de API | Não aplicável | 5headers públicos idênticos ao snapshot |
| Manifest `dump-package` | Manifest válido | Sucesso; Package.swift não alterado |
| Testes C ASan/UBSan | Sim / sim | 4casos auditados +2vetores conhecidos, integridade de entrada e 4threads aprovados; nenhum diagnóstico de sanitizer |
| `git diff --check` | Não aplicável | Sucesso |

A suíte31 inclui transporte HTTP/error/cancel/empty body, store parcial/corrupto/
isolamento/clear, payload mobile/register/check/invalidate, OAuth1 tokens→browser→
perfil/erros/cancelamento, callback destino/correlação/duplicatas, clock/nonce/
base string/encoding/HMAC/header e coordinator cache/registro/push/concorrência/
logout/late. Inclui facade com provider neutro de teste e fluxo completo por
**instância** OAuth1 sem singleton. WK de testes usa RecordingWebView; não navega
na internet. Nenhum backend real foi necessário.

Testes novos em `Tests/USPAuthKitArchitectureTests/USPAuthArchitectureTests.m`
são compilados pelo harness **iOS**, via private headerSearchPaths no target de
testes. Não são descobertos por swift test no host ou por cross-build SwiftPM;
o comando obrigatório para executá-los é o harness, não só swift test.

### Comandos efetivamente executados

```sh
CLANG_MODULE_CACHE_PATH=/tmp/uspauth-modern-cache SWIFTPM_MODULECACHE_OVERRIDE=/tmp/uspauth-modern-cache swift package --disable-sandbox dump-package
CLANG_MODULE_CACHE_PATH=/tmp/uspauth-modern-cache SWIFTPM_MODULECACHE_OVERRIDE=/tmp/uspauth-modern-cache swift build --disable-sandbox --scratch-path /tmp/uspauth-modern-host
CLANG_MODULE_CACHE_PATH=/tmp/uspauth-modern-cache SWIFTPM_MODULECACHE_OVERRIDE=/tmp/uspauth-modern-cache swift test --disable-sandbox --scratch-path /tmp/uspauth-modern-host
CLANG_MODULE_CACHE_PATH=/tmp/uspauth-modern-cache SWIFTPM_MODULECACHE_OVERRIDE=/tmp/uspauth-modern-cache swift build --disable-sandbox --build-tests --scratch-path /tmp/uspauth-modern-ios --triple arm64-apple-ios15.0-simulator --sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk
python3 scripts/check-auth-public-api.py
scripts/check-auth-crypto.sh
git diff --check
```

Execução iOS: ferramenta `XcodeBuildMCP.test_sim`, defaults do harness
`Tests/iOSSessionHarness/USPAuthSessionHarness.xcodeproj`, scheme
`USPAuthSessionHarness`, Debug, iPhone18Pro iOS27,
`derivedDataPath=/tmp/uspauth-r02-derived`; extraArgs finais:
`IPHONEOS_DEPLOYMENT_TARGET=15.0`, `-parallel-testing-enabled NO`,
`-resultBundlePath /tmp/uspauth-modern-complete.xcresult`.
Essa ferramenta executa xcodebuild/test no Simulator, não apenas typecheck.
Pode ser reproduzida com o harness e esses parâmetros em ambiente Xcode apto.
Logs host/cross em `/tmp/uspauth-modern-host-{build,test}.log` e
`/tmp/uspauth-modern-cross.log` são efêmeros; resultado documentado não depende deles.

### Reprodução/correção S04 e falhas intermediárias

Antes de alterar C, compilação dylib temporária + ctypes reproduziu HMAC mensagem/
chave3/3 (sem mutação),160/3 (mensagem alterada),3/80 (chave alterada),160/80
(ambas alteradas); todos os digests correspondiam ao vetor independente.
Depois, a regressão C permanente exige **digest igual e ambos inputs intactos**.
Há vetor HMAC conhecido, SHA1 FIPS com input const/unaligned e quatro threads.
Assinaturas request/access e perfil no iOS continuam aprovadas após a correção.
ASan e UBSan host foram executados; não houve ThreadSanitizer nem sanitizer iOS.

Builds iniciais encontraram fechamento de bloco/import UIKit dentro de região
nullability e warnings de propriedades de test double; corrigidos antes do gate.
Um teste novo WK-only inicialmente não aguardava callback dispatch main e falhou
(53pass/1fail); corrigido no teste, seguido por54pass e final55pass. Não foi alterado
R02 nem relaxada uma asserção para esconder comportamento divergente.
Tentativa host sem caches/tmp falhou por sandbox; repetida com as variáveis acima.

### Warnings e limitações

Host: caches SwiftPM de usuário indisponíveis/read-only sob sandbox; module caches
foram redirecionados a tmp. Warning novo de método WK ausente no host foi corrigido
com guard UIKit no header interno. Final harness reportou zero warnings/errors.
Cross iOS15: linker avisa XCTest/libXCTestSwiftSupport do SDK construídos para17;
não alteramos o package para resolver a toolchain. Mínimo declarado **14 intacto**;
SDK27 requer override15 para estes builds. Runtime iOS14/15 e device não validados.

Não houve login OAuth1 real, homologação do callback, swipe iPad/UI manual, app
piloto, build do Cardápio ou cobertura percentual. Seu checkout permanece limpo.
Gate local prova wire/estado/erros com fakes e API/fixtures, não servidor real.
Novo controle de callback/cancel/logout é incompatibilidade comportamental
**intencional** e documentada, não remoção de API. Storage/endpoints/algoritmo HMAC
preservados; buffers C deixam de ser mutados. Não há depreciação compilável,
Keychain, OAuth2, observabilidade nova ou frameworks externos.

## Revisão do domínio — 2026-10-02

Revisão sobre a composição já implementada, conforme domínio confirmado.
USPMobileCredential removido; fonte de wsuserid é USPAuthUser. Configuração interna
neutra por app separada da configuração OAuth1 legada. Modelos públicos/R02 intactos.

| Verificação | Evidência |
|---|---|
| iOS harness real, Simulator iPhone18Pro/iOS27 | **57pass, 0fail, 0skip**, 78,4s; `/tmp/uspauth-domain-final.xcresult`, compilou/linkou/executou |
| Baseline R02 / Swift e Objective-C fixtures | Mesmos24baseline passaram; fixtures compilaram/linkaram/executaram |
| Nova prova independente | Autenticação a partir de vazio → perfil básico completo + vínculo + wsuserid → registro mobile, duas configs de app; sem sequer instanciar fixture OAuth1 |
| Round-trip tipado | Todos os campos/vínculo restaurados pelo store legado, sem tokens e sem identificador paralelo |
| Build host + swift test | Sucesso;66pass+1skip explícito UIKit, zero falhas. Host não executa os testes de arquitetura iOS |
| Cross-build iOS15 com --build-tests | Sucesso; compilação/linkage sem execução; não descobre suíte ObjC exclusiva do harness |
| API checker |5headers inalterados, selectors/nullability/nomes Swift protegidos pelas fixtures |
| C ASan/UBSan + diff whitespace | Scripts/checker e git diff --check aprovados |

Comandos host/cross iguais à seção anterior, usando cache `/tmp/uspauth-domain-cache`,
scratch `/tmp/uspauth-domain-host` e `/tmp/uspauth-domain-ios`. Logs efêmeros
`/tmp/uspauth-domain-host-{build,test}.log` e `/tmp/uspauth-domain-cross.log`.
XcodeBuildMCP.test_sim: harness/scheme USPAuthSessionHarness, Debug,
derivedData `/tmp/uspauth-domain-derived`, override `IPHONEOS_DEPLOYMENT_TARGET=15.0`,
`-parallel-testing-enabled NO`, resultBundle final acima. Nenhuma configuração MCP
persistida no repositório. Package mínimo14 permanece intacto.

Uma execução intermediária confirmou57pass com warning de atomicidade do getter
lazy da fixture provider. Ajustado para nonatomic e reexecutado: final sem warnings
ou errors no harness. Host tem warnings sandbox/cache SwiftPM; cross avisa XCTest
SDK construído para17 ao linkar target15, como antes. Não houve teste device/iOS14,
login real/backend/UI manual ou alteração de cliente. Sem OAuth2/Keychain/schema/
endpoint/protocolo novo. Mudança somente interna de domínio; sem incompatibilidade
pública ou mudança funcional deliberada nesta revisão.

## Investigação de integração real — 2026-10-02

Responsável reportou regressão OAuth1 no Cardápio com dependência local, iPhone
físico. Comparação baseline e trace DEBUG temporário implementados. **Causa raiz
não confirmada; gate real pendente.** Nenhum callback relaxado/endpoints/consumer
alterados. Ver [investigação](../iterations/08-oauth1-integration-regression/walkthrough.md).

Primeira execução instrumentada:57testes Auth iOS passaram, zero falhas/skips,
83,9s, bundle `/tmp/uspauth-debug-instrumented.xcresult`; log comprova emissão de
[AuthDebug]. Fixtures Swift/ObjC/R02/fake executadas. API checker5 inalterados.
Essa evidência testa instrumentação/fluxo fake, não reproduz login real do iPhone.
Responsável solicitado a recompilar Debug e fornecer somente trace sanitizado.

Instrumentação validada: **59 Auth iOS passaram**, zero falhas/skips/warnings,
126,1s, `/tmp/uspauth-debug-safe.xcresult` (57existentes +2proteções do diagnóstico).
Teste de sanitização não contém marcador privado de URL/path/query/header/body/
NSError. Erro browser sem callback URL preserva completion de erro. Não são ainda
testes de regressão da causa real: a sequência do iPhone não foi recebida.

Host build/test aprovados:66pass+1skip UIKit. Cross iOS15 --build-tests aprovado
(68,08s); avisos XCTest SDK17 esperados. Release cross-build aprovado (54,73s),
zero objetos contendo prefixo AuthDebug dentre38: macro elimina trace/avaliação de
seus argumentos em Release. Guards DEBUG adicionais não alteram código executado
na suíte Debug. API checker5, C ASan/UBSan e diff-check aprovados.
Logs efêmeros `/tmp/uspauth-regression-{host-build,host-test,cross,release}.log`.
**Homologação Cardápio/iPhone, primeira transição falha e equivalência real ao
baseline permanecem pendentes; nenhuma correção funcional foi anunciada.**

## Correção causal da regressão WK102 — 2026-10-02

Trace real fornecido pelo responsável comprovou callback `http://localhost/`,
query names oauth_callback/oauth_token/oauth_verifier, token correlacionado e
verifier não vazio. Access exchange iniciou; erro posterior de navegação102
cancelou provider/task (-999), antes de perfil/registro. Completion real foi
entregue com user nil/error102. A hipótese de validação incorreta não se confirmou.

Reprodução válida antes do patch:1test falhou com task cancelado e completion
precoce/error102, `/tmp/uspauth-wk102-reproduced.xcresult`. A primeira tentativa
only-testing usou target incorreto e não executou; corrigida antes da reprodução.
Patch somente browser: callbackConsumed marcado antes do decisionHandler Cancel;
erros WK depois do handoff não interferem no exchange. Erro pré-callback e cancel
explícito continuam funcionando; validação/generation/wire/endpoints intactos.

Após patch: **62 Auth iOS passaram**, zero falhas/skips/warnings,108,1s,
`/tmp/uspauth-wk102-fixed.xcresult` (59existentes+3regressão/controles). Fixture da
sequência real com valores sintéticos cobre ambos delegate didFail, erro reentrante,
cancel explícito e erro102 antes do callback. Fluxo fake chega a perfil/wsuserid,
registro e completion uma vez; R02/fake/Swift/ObjC executados e preservados.

Host build/test:66pass+1skip UIKit, zero falhas. Cross iOS15 --build-tests compilou/
linkou com warnings XCTest SDK17 já conhecidos. API checker5, ASan/UBSan e
whitespace passaram. Logs efêmeros `/tmp/uspauth-wk102-{host-build,host-test,cross}.log`.
**Reprodução manual pós-patch solicitada ao responsável, ainda não recebida.**
Gate real permanece aberto: não declarar equivalência operacional ao baseline
antes de retorno usuário/wsuserid e navegação Cardápio no iPhone.

### Controles completos do handoff — 2026-10-02

Adicionado controle com browser WK/provider reais e transporte fake para callback
com token não correlacionado, verifier vazio e destino estranho. Todos retornam
erro101 exatamente uma vez, sem iniciar access exchange ou persistir tokens,
mesmo após erro102 tardio. Validação de callback não foi enfraquecida pelo handoff.

Suíte completa novamente: **63 Auth iOS passaram**,0falhas/skips/warnings,67,0s,
`/tmp/uspauth-wk102-controls.xcresult`. R02/fake/fixtures/assinatura/cancel/generation
incluídos. O teste da sequência real já falhou antes do patch e passou depois,
conforme seção anterior. API checker5 e C ASan/UBSan novamente aprovados.
AuthDebug permanece temporariamente; homologação pós-patch no iPhone ainda pendente.

Após o controle adicional, `swift test` host novamente aprovado (66pass+1skip
UIKit) e cross-build --build-tests aprovado (incremental0,83s). Logs
`/tmp/uspauth-wk102-controls-{host,cross}.log`. Homologação solicitada novamente;
cache hit isolado não substitui login completo após logout explícito no app.


## Homologação real pós-patch — 2026-10-02

Responsável confirmou execução bem-sucedida no Cardápio/iPhone: request token200,
callback validado/token correlacionado, access200, profile200/application-json,
dictionary válido, USPAuthUser/wsuserid presentes, registro200, completion user
presente e wsuserid funcional nas demais requisições. Gate do fluxo OAuth1/browser
homologado neste cenário. Não prova todos ambientes/versões/cancelamentos.
Problema de exibição dos vínculos tratado separadamente na [iteração09](../iterations/09-profile-relationships/walkthrough.md).

## Diagnóstico de vínculos — 2026-10-02

Instrumentação DEBUG sem PII e três testes de preservação/shape/sanitização.
66Auth iOS passaram,0falhas/skips/warnings,69,9s; compiled/linked/executed com
R02/fake e fixtures Swift/ObjC. /tmp/uspauth-relationships-fixed-fixture.xcresult.
Primeira execução65pass/1fail por configuração incompleta da fixture; corrigida
sem mudança funcional no SDK. Checker5headers aprovado. Toolchain/runtime iOS27,
override15 só na invocação; mínimo14 preservado e limitação de validação14 mantida.
Não identificado shape/contagem real do perfil; aguarda três eventos do iPhone.

Validação adicional: swift test host terminou sem falhas (59 testes gerais +7
Auth, dos quais1skip explícito UIKit;65pass/1skip). Cross-build iOS15 --build-tests
compilou/linkou; warnings XCTest/SDK já conhecidos. Logs efêmeros
/tmp/uspauth-relationships-{host,cross}.log. Host não executa serviço iOS.


## Consolidação pós-homologação — 2026-10-02

Responsável confirmou vínculos PROD e restauração; DEV respondia vinculo vazio.
O SDK preservou JSON/modelo/metadata/userData; nenhuma correção de parsing. Foi
removido USPAuthDiagnostics.h, calls/imports/DEBUG traces e dois testes exclusivos
de impressão. Regressores úteis intactos, R02 intacto. Sem OAuth2/API/deprecated/
Keychain/endpoint/cliente/commit nesta tarefa.

Comandos CLI (cache/modulecache e scratch externos ao repo):

```bash
CLANG_MODULE_CACHE_PATH=/tmp/uspauth-regression-cache SWIFTPM_MODULECACHE_OVERRIDE=/tmp/uspauth-regression-cache swift build --disable-sandbox --scratch-path /tmp/uspauth-regression-host
CLANG_MODULE_CACHE_PATH=/tmp/uspauth-regression-cache SWIFTPM_MODULECACHE_OVERRIDE=/tmp/uspauth-regression-cache swift test --disable-sandbox --scratch-path /tmp/uspauth-regression-host
CLANG_MODULE_CACHE_PATH=/tmp/uspauth-regression-cache SWIFTPM_MODULECACHE_OVERRIDE=/tmp/uspauth-regression-cache swift build --disable-sandbox --build-tests --scratch-path /tmp/uspauth-regression-ios --triple arm64-apple-ios15.0-simulator --sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk
python3 scripts/check-auth-public-api.py
scripts/check-auth-crypto.sh
git diff --check
```

Harness via XcodeBuildMCP test_sim, project Tests/iOSSessionHarness/
USPAuthSessionHarness.xcodeproj, scheme USPAuthSessionHarness, Debug/iPhone18Pro
Simulator iOS27, extraArgs IPHONEOS_DEPLOYMENT_TARGET=15.0,
-parallel-testing-enabled NO, -resultBundlePath /tmp/uspauth-consolidation.xcresult.
**Compilou/linkou/executou64Auth testes,0fail/skip**,88,9s,0warnings/errors do harness.
Inclui24baseline e40arquitetura: fake neutro, vetores OAuth1, regressão real WK102,
pré-callback/invalid/cancel/logout/late e vínculos/persistência/restauração. Fixtures
Swift/ObjC executadas contra product real no teste R02, não só importação.

Host build1,75s; host tests65pass+1skipUIKit,0fail. Cross2,47s compile/link aprovados;
XCTestSDK17versus target15 é warning conhecido. CLI também avisa user caches
inacessíveis/readonly pelo sandbox, sem impedir fallback. Checker5/Csanitizers/
whitespace aprovados. Busca Sources/Tests zeroAuthDebug/USPAuthDiagnostic.

Não alterado mínimo14; runtime14 não testado. Homologação física veio do responsável
antes da limpeza; não executar backend real pelo agente nem alegar nova execução
física pós-limpeza. Cardápio validado no escopo documentado, não todos consumidores.


## Organização física — 2026-10-02

[Mapa47moves](../iterations/11-auth-layout/file-map.md) e
[walkthrough11](../iterations/11-auth-layout/walkthrough.md). Quarenta testes internos
organizados por responsabilidade, R02/fixtures movidos byte-idênticos. Mesmo product
SPM no harness: **64Auth testes compilaram/linkaram/executaram**,0fail/skip/warnings,
81,3s,/tmp/uspauth-layout-final.xcresult. Inclui24baseline e40arquitetura (fake neutro,
provider1, regressão WK102, signing, perfil/vínculos/store/cancel/logout/late/mobile).
Primeira compilação precisou import browser explícito em Support após retirar
import transitivo OAuth1; corrigido sem mudar produção/comportamento.

Comandos CLI da consolidação repetidos com mesmos flags/scratch, usando manifest/
scriptC/referências iOS atualizados: host build3,34s e cross iOS15 --build-tests3,80s
aprovados; host65pass/1skipUIKit,0fail. API checker5 aprovado; bytes dos cinco headers
comparados com HEAD, idênticos. C ASan/UBSan4casos+2vetores/integridade/4threads aprovado.
git diff --check e links locais aprovados. Bundle iOS via test_sim/harness Debug,
extraArgs override15,-parallel-testing-enabled NO,-resultBundlePath acima.
Logs /tmp/uspauth-layout-final-{build,cross,host-test}.log; warnings caches sandbox
CLI e XCTestSDK17versus target15 conhecidos, nenhum warning novo no harness.

Não alterado iOS14 declarado, product/import/API/endpoints/payload/schema/logout.
Runtime14 e novo fluxo físico pós-moves não executados; Cardápio previamente
homologado pelo responsável, não alterado nem recompilado pelo agente nesta tarefa.
