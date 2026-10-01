# Inventário do contrato público

Baseline `11d9582`, 2026-10-01. [Roadmap](modernization-roadmap.md).

## O que é público e o que é comprovadamente usado

SPM exporta `include` pelo umbrella `USPAuthKit.h`: quatro classes NSObject, um NS_ENUM e duas declarações C de versão. Não há protocols públicos, structs públicos, enums de erro públicos, typedefs de completion, notificações ou delegates próprios. Todos os blocos são callbacks nas assinaturas abaixo. Nullability e propriedades readonly/readwrite também fazem parte do contrato.

O README recomenda configure/shared/ensure/currentWSUserId e modelos. Testes locais usam factories, initWithDictionary e propriedades de User/Vinculo; parser interno é acessado por runtime. O teste de compatibilidade só importa dois modules. **Uso efetivo nos apps externos não é verificável neste repositório.** Antes de deprecar, inventariar versões e chamadas nos apps Swift/ObjC/híbridos, uso de KVC/runtime, subclasses, headers internos e leitura direta das keys de defaults. Ausência de referência local não autoriza remoção.

Legenda: **M** manter; **T** manter temporariamente como contrato legado; **D** deprecar futuramente, após alternativa e evidência de migração; **B** remoção/mudança candidata somente a futura major. D/B são propostas futuras, sem annotation ou mudança nesta auditoria. Encapsular a implementação é compatível; tornar um símbolo público privado não é.

## USPAuthService — `include/USPAuthService.h`

| Elemento (seletor Objective-C autoritativo) | Tipo/semântica atual | Decisão e migração |
|---|---|---|
| classe USPAuthService : NSObject | Fachada importável em Swift/ObjC | M; composição interna preserva classe |
| +sharedService | singleton, Swift `shared()` no README | M; default composition, sem exigir DI dos apps |
| +configureWithEnvironment:consumerKey:consumerSecret:appKey: | void; Swift confirmado `configure(with:consumerKey:consumerSecret:appKey:)`; Custom assert/return | T → D; adapter para config OAuth1; B apenas após alternativa |
| +configureWithConfig: | void; configura singleton e appKey | M; preservar tipo atual e oferecer configuração neutra aditiva futuramente |
| -init | defaults standard, HTTP singletons | M; delegar composição interna |
| -initWithUserDefaults: | initializer designated, defaults injetado | M; preservar suite e semântica de isolamento, corrigindo UI singleton após testes |
| oauthToken | NSString nullable copy readwrite | T → D/B; getter/setter via adapter OAuth1, sem fingir equivalência OAuth2 |
| oauthTokenSecret | NSString nullable copy readwrite | T → D/B; mesmo tratamento, acesso limitado ao provider legado |
| appKey | NSString nonnull copy readwrite | M; effectiveAppKey prioriza config.appKey não vazio |
| backendHeaderValue | NSString nonnull copy readwrite | T; configuração de backend explícita futura, confirmar função do valor fixo |
| config | USPAuthConfig nonnull strong readwrite | M; pode estar nil antes de configurar apesar do header; mudança de nullability requer auditoria de importação |
| notificationToken | NSString nullable copy readwrite | M; setter persiste, não registra sozinho |
| notificationPlatform | NSString nonnull copy readwrite | M; default F, normaliza vazio |
| userData | NSDictionary<NSString*,id> nonnull readonly | T → D/B após modelo tipado equivalente; JSON bruto não pode desaparecer agora |
| -updateNotificationToken: | void; token nullable; registra se mudou e isLoggedIn | M; preservar diferença em relação ao setter |
| -ensureLoggedInFromViewController:completion: | UIViewController + block(USPAuthUser nullable, NSError nullable) | M; fachada neutra possível; cache/erro de registro/completion thread precisam characterization |
| -isLoggedIn | BOOL | M; baseline de presença local, não prometer validade remota/expiração |
| -currentUser | USPAuthUser nullable | M; cache independente dos tokens, novo objeto por chamada |
| -currentWSUserId | NSString nullable | M; credencial interna do backend, não renomear automaticamente a access token |
| -loginInWebView:completion: | WKWebView + block(BOOL, NSError nullable) | T → D/B; manter caminho OAuth1, operação só obtém tokens |
| -logout | void | M; hoje local, sem completion/remoto; nova operação remota deve ser aditiva |
| -registerToken | void; erro em NSLog | M; wrapper legado pode coexistir com completion |
| -registerTokenWithCompletion: | block(NSError nullable) | M; 2xx marca registered, sem validar body |
| -invalidateToken | void; erro em NSLog | M; não confundir com logout |
| -invalidateTokenWithCompletion: | block(NSError nullable) | M; invalidação mobile independente de revogação OAuth |
| -checkToken | void; ignora payload e loga erro | M |
| -checkTokenWithCompletion: | block(NSDictionary<NSString*,id> nullable, NSError nullable) | M; manter payload; alternativa tipada aditiva após contrato servidor |

Há oito propriedades de instância declaradas no serviço (sete readwrite e userData readonly). Métodos privados de perfil, payload, main dispatch, URL e postBody não são contratos públicos. Códigos/domínios de NSError não estão exportados, mas são observáveis: registrar e preservar os códigos antigos no adapter até avaliar consumidores.

## USPAuthConfig — `include/USPAuthConfig.h`

| Elemento | Contrato | Decisão |
|---|---|---|
| USPAuthEnvironment | NS_ENUM(NSInteger) | M; manter valores Dev=0, Prod=1, Custom=2 |
| USPAuthConfig : NSObject | objeto de configuração | M como config legada; nova config de autenticação pode coexistir |
| environment | USPAuthEnvironment assign readonly | M |
| baseURL | NSString copy readonly | M; separar hosts de identidade/mobile internamente sem mudar valor legado |
| consumerKey | NSString copy readonly | T → D/B; config de provider OAuth1 |
| consumerSecret | NSString copy readonly | T → D/B; preservado como legado, não requisito de provider futuro |
| appKey | NSString copy readonly | M; identificador mobile, sensibilidade depende de backend |
| +devWithConsumerKey:consumerSecret:appKey: | instancetype nonnull | T → D/B após alternativa aditiva |
| +prodWithConsumerKey:consumerSecret:appKey: | instancetype nonnull | T → D/B após alternativa aditiva |
| +customWithBaseURL:consumerKey:consumerSecret:appKey: | instancetype nonnull | T → D/B após alternativa aditiva |

`initWithEnv:baseURL:consumerKey:consumerSecret:appKey:` existe somente na implementação: encapsular internamente (já não exportado). `init`/`new` de NSObject são herdados e não foram proibidos; podem produzir config sem campos apesar do nonnull. Não declará-los unavailable em release compatível sem mapear uso e testes.

## USPAuthUser — `include/USPAuthUser.h`

| Elemento | Contrato | Decisão |
|---|---|---|
| USPAuthUser : NSObject | modelo público ObjC/Swift | M |
| loginUsuario | NSString copy readonly nonnull | M |
| nomeUsuario | NSString copy readonly nonnull | M |
| emailPrincipalUsuario | NSString copy readonly nonnull | M |
| emailAlternativoUsuario | NSString copy readonly nonnull | M |
| emailUspUsuario | NSString copy readonly nonnull | M |
| numeroTelefoneFormatado | NSString copy readonly nonnull | M |
| tipoUsuario | NSString copy readonly nonnull | M |
| wsuserid | NSString copy readonly nonnull | M; contrato de API USP, não específico de OAuth1 comprovado |
| vinculos | NSArray<USPAuthVinculo*> copy readonly nonnull | M |
| -initWithDictionary: | NSDictionary<NSString*,id>, instancetype | M; parsing do JSON USP, não de parâmetros OAuth |

O override de `description`, embora não redeclarado no header, é comportamento público herdado e contém nome/wsuserid; sanitização futura deve ter teste próprio. `init`/`new` herdados também estão disponíveis; readonly não garante inicialização por dictionary.

## USPAuthVinculo — `include/USPAuthVinculo.h`

| Elemento | Contrato | Decisão |
|---|---|---|
| USPAuthVinculo : NSObject | modelo público ObjC/Swift | M |
| codigoSetor | NSInteger assign readonly | M |
| codigoUnidade | NSInteger assign readonly | M |
| nomeUnidade | NSString copy readonly nonnull | M |
| nomeVinculo | NSString copy readonly nonnull | M |
| siglaUnidade | NSString copy readonly nonnull | M |
| tipoVinculo | NSString copy readonly nonnull | M |
| -initWithDictionary: | NSDictionary<NSString*,id>, instancetype | M; hardening de números sem alterar valores válidos |

`description`, init/new herdados: preservar disponibilidade; corrigir parsing inválido com política documentada.

## Umbrella e símbolos internos

`USPAuthKit.h` exporta `USPAuthKitVersionNumber` (double) e `USPAuthKitVersionString` (const unsigned char[]). Classificar T: declarações públicas **sem definição encontrada** por rg. Build de biblioteca sem referência não valida linkage desses símbolos. Verificar consumidor que os referencia antes de definir/remover; remoção seria B, não limpeza cosmética.

| Elemento não exportado | Papel / compatibilidade indireta | Decisão |
|---|---|---|
| OAuth1Controller, CHQueryStringPair, WebViewHandler | fluxo/delegate/parser/signer; teste usa runtime | Encapsular internamente; continuar runtime até trocar testes conscientemente |
| HTTPClient, USPAuthSessionStore | infra interna concreta | Encapsular/injetar sem expor novos protocols públicos |
| LoginWebViewController/loginCompletion/disposeWebView | UI interna; dispose sem implementação | Encapsular, caracterizar lifecycle, não tratar como API de apps via SPM |
| USPAuthKitMutableURLRequest +requestWithURL: | helper interno sem caller; header fora include | Compatibilidade legada desconhecida; investigar distribuição anterior antes de remover |
| KeychainItemWrapper | wrapper sem caller do fluxo | Infra legada; avaliar riscos antes de reaproveitar, não presumir proteção atual |
| NSString(URLEncoding) utf8AndURLEncode/getNonce | categoria runtime NSString | Header interno, métodos runtime globalmente visíveis; verificar colisões/uso indireto |
| HMAC/SHA1/Base64 e tabelas C | símbolos de objeto sem headers exportados | Infra; não confundir símbolos linkáveis com contrato SPM declarado |

## Estratégia compatível

Preservar selectors, tipos, nullability, Swift import, factories e products. Introduzir composição/protocols ObjC **internos** no mesmo target primeiro; Swift não deve ser adicionado ao target Clang misto. Uma fachada Swift opcional só terá target separado se houver benefício concreto.

Adapter legado traduz propriedades/config OAuth1 e mantém caminho WKWebView. APIs neutras aditivas devem anteceder depreciação e migração por app. Não converter tokenSecret em refreshToken, não devolver token fictício, não alterar currentWSUserId para bearer sem comprovar contrato mobile. Apps que só usam ensure/currentUser podem reduzir impacto; apps que manipulam tokens ou WebView precisam migração explícita antes de escolher outro provider. [Coexistência](target-architecture.md).
