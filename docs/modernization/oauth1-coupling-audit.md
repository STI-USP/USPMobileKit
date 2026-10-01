# Acoplamento OAuth 1

Baseline `11d9582`, 2026-10-01. [Inventário público](public-api-inventory.md) · [Roadmap](modernization-roadmap.md).

Localizações usam caminhos relativos a `Sources/USPAuthKit/` e nomes de método/símbolo, que permanecem pesquisáveis por rg. Dificuldade = esforço técnico para isolar; risco = regressão ao alterar. Preservar público significa manter a disponibilidade atual, não recomendar exposição permanente.

## Matriz de ocorrências conceituais

| ID / localização | Responsabilidade / classificação | Específico OAuth1? | Precisa público? | Dificuldade / risco | Estratégia |
|---|---|---|---|---|---|
| O01 include/USPAuthService.h oauthToken/oauthTokenSecret; Adapters/USPAuthService.m setters/getters | API pública, domínio e persistência; par mutável de credenciais | Sim, em especial secret pareado | Sim por compatibilidade; não para novos apps | Alto / alto | Adapter bidirecional legado, provider1 proprietário das credenciais; não equivaler ao bearer/refresh |
| O02 include/USPAuthConfig.h consumerKey/consumerSecret e três factories | API pública/configuração/segredo | Sim como contrato consumer + assinatura | Sim legado | Médio / alto | Config OAuth1 interna derivada do objeto atual; nova configuração aditiva depois |
| O03 include/USPAuthService.h configureWithEnvironment:consumerKey:consumerSecret:appKey: | API pública/configuração obrigatória para iniciar fluxo | Sim | Sim legado | Médio / alto | Delegar composição OAuth1; factory interna, nenhuma seleção OAuth2 agora |
| O04 include/USPAuthService.h loginInWebView:completion: | API pública/compatibilidade de apresentação, só retorna sucesso OAuth | WebView não é OAuth1 por natureza, mas este método tem semântica específica atual | Sim legado | Alto / alto | Manter provider1+WK; futura API baseada em apresentação, sem exigir WK |
| O05 Core/OAuth1Controller.m REQUEST_TOKEN_URL, AUTHENTICATE_URL, ACCESS_TOKEN_URL; obtainRequestToken/authenticateToken/requestAccessToken | Domínio interno/networking/configuração: três passos/endpoints relativos | Sim request-token/access-token handshake; authorize isolado não é exclusivo | Não | Médio / médio | Concentrar fluxo/endpoints no provider1 sem alterar URLs |
| O06 Core/OAuth1Controller.m OAUTH_CALLBACK; delegateHandler; decidePolicyForNavigationAction | Domínio/UI/networking: localhost, oauth_verifier, oauth_token, sufixo #_=_ | Verifier e correlação com request token sim; callback em geral não | Não | Médio / alto | Browser adapter separado; validar URL e token após characterization/contrato backend |
| O07 Core/OAuth1Controller.m standardOauthParametersWithConsumerKey | Domínio/infra: oauth_consumer_key, oauth_nonce, oauth_timestamp, oauth_signature_method, oauth_version | Nomes/semântica OAuth1 sim; tempo/aleatoriedade são infra genérica | Não | Baixo / médio | Injetar clock/nonce internos no signer, manter formato até testes |
| O08 Core/OAuth1Controller.m baseStringWithMethod, signClearText, authorizationHeaderFromParams, preparedRequestForPath | Networking/infra: oauth_signature, Authorization OAuth, consumerSecret & tokenSecret | Sim | Não (header fora include) | Alto / alto | Signer privado provider1 + request builder; preservar wire format antes de corrigir |
| O09 Core/NSString+URLEncoding.m; CHPercentEscapedQueryStringPairMember; CHQueryString* no OAuth1Controller | Infra/networking: percent encoding, ordenação, arrays/dicts, normalize | Encoding genérico; normalização para assinatura é OAuth1 | Não | Médio / alto | Vetores determinísticos antes de unificar duas rotinas; não generalizar helper sem demanda |
| O10 Core/hmac.*, sha1.*, Base64Transcoder.*; signClearText | Infra/compatibilidade legada: HMAC-SHA1 e Base64 | Algoritmos genéricos, uso nesta lib exclusivo do signer1 | Não | Médio / alto | Isolar dependência do signer; verificar buffers/vetores antes de substituição opcional |
| O11 Core/USPAuthSessionStore.h/.m oauthToken/oauthTokenSecret e keys; hasValidSession | Persistência/domínio interno: sessão depende do par OAuth | Sim | Header não; keys podem ser dependência indireta dos apps | Alto / alto | Store schema legado adapter, credenciais opacas internas e migração versionada/testada |
| O12 Adapters/USPAuthService.m init/getters/isLoggedIn/ensureLoggedIn/loginInWebView | Domínio interno + fachada: controller concreto, tokens como pré-condição | Sim | Operações públicas sim; lógica concreta não | Alto / alto | Coordenador separa sucesso de autenticação, perfil e registro; preservar cache/erros |
| O13 Adapters/USPAuthService.m fetchUserDataWithCompletion/kUserInfoPath | Domínio/networking: assinatura direta OAuth1 no service | Sim assinatura; perfil USP não é intrinsecamente OAuth1 | Não para fetch, sim para resultado User | Médio / alto | Provider1 faz request autenticada de identidade e entrega credencial opaca/perfil; preservar DTO |
| O14 Adapters/USPAuthService.m kRegisterPath/kInvalidatePath/kCheckPath, payload token=wsuserid | Networking/configuração, API pública de backend mobile | Nome /oauth/ não prova semântica OAuth1; token é wsuserid, não oauthToken | Operações e wsuserid sim | Médio / alto | BackendSessionClient separado; confirmar vínculo com protocolo no servidor antes da troca |
| O15 Core/USPAuthUser.m + include/USPAuthUser.h wsuserid; currentWSUserId/userData | API pública/modelo/backend | Não comprovado específico de OAuth1 | Sim, recomendado aos apps pelo README | Alto / alto se mudar significado | Preservar credencial mobile; mapear emissão futura com backend, não chamar bearer prematuramente |
| O16 UI/LoginWebViewController.m singleton.startLoginFlow; UI header OAuth | UI/domínio/compatibilidade legada | Acoplamento à implementação atual, não à UI em si | Não | Médio / alto | Injetar serviço/operação e apresentar browser interno; corrigir instância vs singleton |
| O17 Tests/USPAuthKitTests.swift parser, query fixtures, factories ck/cs | Teste: runtime e parâmetros OAuth/config | Sim | Não | Baixo / médio | Manter testes signer/parser específicos provider1; adicionar contratos neutros reutilizáveis |
| O18 README.md configuração consumer e descrição request→authorize→access | Documentação pública/configuração | Sim | Documentação do legado deve permanecer | Baixo / baixo | Guias por caminho, depreciação apenas após alternativa e piloto |
| O19 Core/OAuthConfig.h | Compatibilidade legada, arquivo vazio de declarações | Nome sim, conteúdo não | Não | Baixo / baixo | Não usar como configuração; remoção só após verificar uso indireto |

## Quanto vazou para a API

Vazamento forte: **duas propriedades mutáveis** de credencial OAuth; **duas propriedades** de configuração; **três factories** que exigem consumer key/secret; **um método de configuração rápida** com esses argumentos. `loginInWebView` expõe modo de apresentação e sucesso de uma etapa que não forma sessão completa. `userData` expõe formato bruto do backend, mas não um dicionário OAuth accessParams. Não há request token/verifier/nonce/signature/HMAC públicos nos headers exportados. O par accessParams só cruza fronteiras internas entre controller e service.

`wsuserid`, appKey, push, vínculos e endpoints mobile são acoplamento ao **backend USP**, não automaticamente OAuth1. Essa distinção é determinante: isolar signer não garante que o servidor OAuth2 continue emitindo a credencial exigida pelos apps. Validar isso é gate P0 para troca de provider.

## Dificuldades de isolamento

A assinatura já está num controller interno, mas o service chama seu método estático para buscar perfil, conhece nomes do dicionário OAuth e persiste tokens por setters públicos. UI também chama singleton em vez de instância. Portanto só renomear OAuth1Controller para Provider não cria fronteira.

Isolamento recomendado: transporte arbitrário injetável → store contratual → composição de instância → operação de autenticação que entrega estado interno de sessão → provider1 responsável pelo handshake/signature/perfil autenticado. Preservar backend mobile e modelos fora do signer. O adapter compatível mantém reads/writes dos tokens legados; não propagar esses campos ao contrato neutro.

## Lacunas de normalização a verificar, sem corrigir nesta execução

Request token não inclui oauth_callback no header assinado e não verifica oauth_callback_confirmed; callback é enviado em authorize como localhost. Pode ser convenção do servidor USP. Callback aceita token diferente do temporário. Ordenação case-insensitive, sets de percent-encoding diferentes, duplicatas descartadas e transporte de parâmetros no preparedRequest exigem vetores. Confrontar com [RFC 5849, seções 2, 3.4 e 3.6](https://www.rfc-editor.org/info/rfc5849/) e com respostas reais sanitizadas/contrato do backend; conformidade teórica não autoriza quebrar integração existente.
