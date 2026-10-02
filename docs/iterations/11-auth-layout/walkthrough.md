# Organização física do USPAuthKit implementada

2026-10-02, feature/auth-architecture-modernization. Sem commit ou alteração
comportamental/API/protocolo/endpoint/payload/storage keys. Não alterado Cardápio.
Plano e auditoria precederam moves; [mapa final](file-map.md) lista todas origens,
destinos e diferenças. [Arquitetura canônica](../../authentication/architecture.md#organização-do-código)
mostra árvore completa real de produção e testes.

## Árvore anterior resumida

```text
Sources/USPAuthKit/
  Adapters/   fachada + helper histórico de request
  Core/       domínio, sessão, perfil, OAuth1, crypto, store, HTTP e config
  UI/         apresentação WK
  include/    cinco headers públicos
Tests/
  USPAuthKitTests/              Swift6baseline +R02/fixture Swift
  USPAuthKitArchitectureTests/ 40testes internos ObjC num arquivo
  USPAuthKitObjCFixture/        fixture de consumidor
  Security/                    teste C standalone
```

## Resultado

```text
Sources/USPAuthKit/
  Public/                      implementações públicas
  Configuration/               configuração interna do aplicativo
  Authentication/
    USPAuthenticationCoordinator.h/m
    Composition/               entrada privada de composição
    Provider/
      USPAuthenticationProvider.h
      OAuth1/                  provider/controller/encoding/config OAuth1
        Crypto/                HMAC/SHA1/Base64 atuais
  Profile/                     USPIdentity e adapter do perfil
  Session/                     USPAuthSession e contrato de store
  MobileBackend/               USPMobileBackendClient
  Infrastructure/
    Networking/                HTTPClient/HTTPTransport/request helper
    Browser/                   browser +LoginWebViewController
    Security/                  wrapper Keychain histórico
  Legacy/Persistence/          adapter UserDefaults com keys originais
  include/                     mesmos cinco headers exportados
  PrivacyInfo.xcprivacy         mesmo recurso no root
Tests/USPAuthKitTests/
  Public/                      R02
  Authentication/
    USPAuthenticationCoordinatorTests.m
    USPNeutralProviderTests.m
    OAuth1/                    provider/regressão/signing +Crypto C
  Profile/                     baseline models +perfil/raw preservation
  Session/                     store
  MobileBackend/               operações mobile
  Infrastructure/Networking/   transporte
  Infrastructure/Browser/      lifecycle
  Compatibility/               fachada e Swift/ObjectiveC fixtures
  Support/                     doubles/helpers da mesma classe XCTest
```

Nenhum diretório vazio ou especulativo. include ficou onde SPM espera: só os cinco
headers são públicos, não toda extensão .h. Public contém quatro implementações
públicas, sem expor composição/provider. Não renomeados tipos públicos ou internos:
OAuth1Controller já desempenha handshake/signing, sem criar signer novo por estética.

## Movimentações e separações

47arquivos movidos com Path.rename (preserva arquivo/conteúdo/permissão);44byte-
idênticos à versão imediatamente anterior. Os dois arquivos USPAuthSession
mudaram somente para separar declaração/implementação do **mesmo USPIdentity**
em Profile/USPIdentity.h/m; métodos não alterados. LoginWebViewController.h teve
somente comentário privado neutralizado. R02 e fixtures conservam conteúdo exato.

Suite monolítica interna repartida em9categorias da mesma USPAuthArchitectureTests,
com40selectors/corpos preservados. Support contém interfaces e implementações de
doubles/helpers, factory OAuth lazy; import browser agora explícito (antes era
transitivo pelo header OAuth1). Cinco grupos sem uso concreto de OAuth deixaram
de importar controller/provider/encoder. Teste neutro não instancia provider1 ou
config/tokens/signing: entrega perfil/wsuserid/vínculo para dois aplicativos.
Assertions negativas da compatibility API não fornecem credenciais ao fluxo.

Nenhuma implementação produtiva removida; nenhum tipo novo criado. Novos arquivos:
USPIdentity.h/m por separação, Support h/m e9arquivos de categorias. Diretórios
vazios Core/UI/Adapters e árvores antigas de testes retirados após os moves.
Arquivo monolítico deixou de existir, substituído pelos mesmos métodos distribuídos.
Não houve nova extração de transporte/store/provider/coordinator ou comportamento.

OAuthConfig.h histórico não é adapter da API pública: colocado dentro de OAuth1
como configuração específica. Helper USPAuthKitMutableURLRequest só constrói request
com headers, mantido Networking, sem encher Legacy de código antigo. Keychain wrapper
retido como infraestrutura histórica não utilizada pela sessão; não anuncia migração.

## Configuração de build/testes

Package mantém products/targets/names/iOS14/publicHeadersPath include e descoberta
automática dos sources. Ajustou cSettings headerSearchPath das pastas reais.
Target da fixture Objective-C mantém nome e apenas muda path. Swift testTarget
exclui dirs/arquivos ObjC necessários porque SPM não permite target misto; não
exclui testes Swift nem perde execução ObjC, que permanece no harness.

Projeto iOS usa mesmos product e target, referências de fontes/headerSearchPaths/
bridging header atualizadas. Scripts C usam novo local Crypto. Checker API não
precisou mudar porque os headers continuam em include. README/arquitetura/migração/
roadmap/harness documentam árvore e limites atuais; auditorias antigas são históricas.

## Auditoria residual depois dos moves

| Localização | Classificação | Responsabilidade restante / risco |
|---|---|---|
| include/USPAuthService.h e USPAuthConfig.h | API pública legada/configuração | consumerKey/Secret/tokens configuram provider atual; bytes preservados |
| Public/USPAuthConfig.m | Configuração pública legada | Implementa factories/config atual; não universaliza campos para outro provider |
| Public/USPAuthService.m | Compatibilidade/composição default | Instancia provider1, injeta clock/nonce e delega properties/config/login; não lógica do coordinator |
| Authentication/Composition/USPAuthServiceInternal.h | Composição privada de compatibility | Forward/reference opcional ao provider1 para adapters; não exportado |
| Legacy/Persistence/USPAuthSessionStore.h/m | Adapter de compatibilidade | Keys/providerIdentifier/par OAuth1 traduzidos para contrato neutro; schema futuro ainda pendente |
| MobileBackend/USPMobileBackendClient.m | Contrato do backend | Strings paths mobile/oauth registrar/consultar/invalidar; não protocolo/signing |
| Testes OAuth1/compatibility, fixtures, Support | Teste/configuração sintética | Characterization/runtime antigo e factory lazy; não requisito do domínio |

Busca case-insensitive incluiu oauth/token/secret/verifier/nonce/HMAC/SHA1/consumer
fields. Coordinator, Profile, Session e transporte HTTP não interpretam OAuth1.
Browser não conhece profile ou OAuth: matcher/policy vêm do provider; handoff
callbackConsumed permanece para não cancelar exchange quando WK falha após callback.
Não encontrado acoplamento indevido novo a remover com refatoração comportamental.

Caminho inverso: provider1 usa USPIdentity como resultado/pending/finish e transforma
payload de perfil em identidade. É obtenção/resolução legítima, não ownership do
modelo. User/Vinculo são públicos e USPIdentity é Profile; wsuserid continua perfil,
sem USPMobileCredential reintroduzido. Modelos neutros não importam implementação OAuth.

Limites: façade default/config combinada ainda específicas provider1; store legado
só suporta schema OAuth1. Compatibilidade inline da fachada foi mantida, não categoria
produtiva nova. Helpers legacy não auditados para remoção permanecem com finalidade
identificável; não garantir API para imports privados. Nenhum mecanismo futuro modelado.

## Validação e história git

Primeiro teste iOS não compilou Support por falta de import explícito USPAuthBrowser.
Corrigido apenas esse include; suíte64 passou95,3s. Após ajustes finais de headers/
imports, **64Auth iOS passaram**,0fail/skip/warnings/errors,81,3s,
/tmp/uspauth-layout-final.xcresult. Mesmo24baseline +40arquitetura, mesmo nomes de
classe/selectors. Swift/ObjC fixtures compilaram/linkaram/executaram contra product
real; fake/provider/callback WK102/cancel/logout/late/metadata/vínculos/store incluídos.

Host build aprovado3,34s; cross iOS15 --build-tests compile/link aprovado3,80s.
Host tests65pass/1skip UIKit,0fail. Checker5headers aprovado e comparação com HEAD
confirma os cinco **byte-idênticos**. C ASan/UBSan:4casos+2vetores/integridade/4threads
passaram no novo path. git diff --check e links locais aprovados. Logs /tmp/
uspauth-layout-final-{build,cross,host-test}.log. Sem AuthDebug reinserido.

Warnings CLI: caches user-level inacessíveis/readonly no sandbox; cross XCTestSDK17
versus target15 já conhecido. Deployment declarado continua14, override15 só na
invocação. Não executado runtime14, backend/cliente real após os moves; homologação
prévia do responsável permanece distinta da validação automatizada desta organização.

git diff --summary/status revisados. Como as novas pastas ainda estão unstaged,
summary mostra deletes de paths antigos +status novos/untracked; não staging/index
ou commit nesta tarefa. Mapa/hash e rename filesystem preservam rastreabilidade;
Git poderá detectar similaridade quando alterações forem preparadas para revisão.
Modernização prévia já tinha arquivos não commitados; não foi apagada/descartada.

## Compatibilidade e próxima tarefa

Nenhuma API pública, seletor, nome importado Swift, product, endpoint, payload,
key, formato de perfil/restauração ou deployment target alterado. Cardápio usa
API pública e não precisa conhecer nova organização; cliente não foi modificado.
Consumidores com imports privados (nívelD) devem migrar, não considerar esses paths
como contrato público. Garantias/gaps anteriores (Keychain/consumidores/runtime14/
status/payload/logs/contrato futuro) mantidos; organização não conclui esses itens.

Única próxima tarefa: R03, especificar com responsável/backend contrato real de
mecanismo futuro, perfil/wsuserid/config por app e serviços mobile. Não executar
OAuth2 nem criar folders/protocols especulativos nesta reorganização.
