# Validação da auditoria

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
