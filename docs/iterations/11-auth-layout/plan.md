# Organização física do USPAuthKit

2026-10-02. Auditado antes das movimentações: Core mistura profile/session/provider/
transport/store; Adapters tem fachada e helper interno histórico; UI é browser.
include contém exatamente cinco headers públicos protegidos. Suite interna ObjC
monolítica reúne40testes; Swift tem R02 intacto e6testes pequenos anteriores.

Objetivo: árvore real expressa arquitetura sem novo mecanismo/API/endpoint/schema.
Manter include byte-idêntico e nomes de tipos; não forçar Public como export path.
Separar somente declaração/implementação USPIdentity do arquivo USPAuthSession,
sem mudar corpos. Coordinator fica neutro; defaults OAuth adapter vai Legacy.
Config geral tem diretório Configuration, dois arquivos reais. Não criar signer
novo: OAuth1Controller já possui handshake/signing, o nome fica por baixo risco.

## Mapa auditado antes de mover

| Arquivo atual | Responsabilidade | Destino proposto | Motivo |
|---|---|---|---|
| `Sources/USPAuthKit/Adapters/USPAuthService.m` | Public | `Sources/USPAuthKit/Public/USPAuthService.m` | Implementação de tipo público; headers exportados ficam em include |
| `Sources/USPAuthKit/Core/USPAuthUser.m` | Public | `Sources/USPAuthKit/Public/USPAuthUser.m` | Implementação de tipo público; headers exportados ficam em include |
| `Sources/USPAuthKit/Core/USPAuthVinculo.m` | Public | `Sources/USPAuthKit/Public/USPAuthVinculo.m` | Implementação de tipo público; headers exportados ficam em include |
| `Sources/USPAuthKit/Core/USPAuthConfig.m` | Public | `Sources/USPAuthKit/Public/USPAuthConfig.m` | Implementação de tipo público; headers exportados ficam em include |
| `Sources/USPAuthKit/Core/USPAuthServiceInternal.h` | Authentication/Composition | `Sources/USPAuthKit/Authentication/Composition/USPAuthServiceInternal.h` | Responsabilidade real; somente localização, sem novo tipo/contrato |
| `Sources/USPAuthKit/Core/USPApplicationConfiguration.h` | Configuration | `Sources/USPAuthKit/Configuration/USPApplicationConfiguration.h` | Responsabilidade real; somente localização, sem novo tipo/contrato |
| `Sources/USPAuthKit/Core/USPApplicationConfiguration.m` | Configuration | `Sources/USPAuthKit/Configuration/USPApplicationConfiguration.m` | Responsabilidade real; somente localização, sem novo tipo/contrato |
| `Sources/USPAuthKit/Core/USPAuthenticationCoordinator.h` | Authentication | `Sources/USPAuthKit/Authentication/USPAuthenticationCoordinator.h` | Responsabilidade real; somente localização, sem novo tipo/contrato |
| `Sources/USPAuthKit/Core/USPAuthenticationCoordinator.m` | Authentication | `Sources/USPAuthKit/Authentication/USPAuthenticationCoordinator.m` | Responsabilidade real; somente localização, sem novo tipo/contrato |
| `Sources/USPAuthKit/Core/USPAuthenticationProvider.h` | Authentication/Provider | `Sources/USPAuthKit/Authentication/Provider/USPAuthenticationProvider.h` | Responsabilidade real; somente localização, sem novo tipo/contrato |
| `Sources/USPAuthKit/Core/USPOAuth1AuthenticationProvider.h` | Authentication/Provider/OAuth1 | `Sources/USPAuthKit/Authentication/Provider/OAuth1/USPOAuth1AuthenticationProvider.h` | Responsabilidade real; somente localização, sem novo tipo/contrato |
| `Sources/USPAuthKit/Core/USPOAuth1AuthenticationProvider.m` | Authentication/Provider/OAuth1 | `Sources/USPAuthKit/Authentication/Provider/OAuth1/USPOAuth1AuthenticationProvider.m` | Responsabilidade real; somente localização, sem novo tipo/contrato |
| `Sources/USPAuthKit/Core/OAuth1Controller.h` | Authentication/Provider/OAuth1 | `Sources/USPAuthKit/Authentication/Provider/OAuth1/OAuth1Controller.h` | Responsabilidade real; somente localização, sem novo tipo/contrato |
| `Sources/USPAuthKit/Core/OAuth1Controller.m` | Authentication/Provider/OAuth1 | `Sources/USPAuthKit/Authentication/Provider/OAuth1/OAuth1Controller.m` | Responsabilidade real; somente localização, sem novo tipo/contrato |
| `Sources/USPAuthKit/Core/NSString+URLEncoding.h` | Authentication/Provider/OAuth1 | `Sources/USPAuthKit/Authentication/Provider/OAuth1/NSString+URLEncoding.h` | Responsabilidade real; somente localização, sem novo tipo/contrato |
| `Sources/USPAuthKit/Core/NSString+URLEncoding.m` | Authentication/Provider/OAuth1 | `Sources/USPAuthKit/Authentication/Provider/OAuth1/NSString+URLEncoding.m` | Responsabilidade real; somente localização, sem novo tipo/contrato |
| `Sources/USPAuthKit/Core/Base64Transcoder.h` | Authentication/Provider/OAuth1/Crypto | `Sources/USPAuthKit/Authentication/Provider/OAuth1/Crypto/Base64Transcoder.h` | Usado pelo signer OAuth1 atual, sem alteração criptográfica |
| `Sources/USPAuthKit/Core/Base64Transcoder.c` | Authentication/Provider/OAuth1/Crypto | `Sources/USPAuthKit/Authentication/Provider/OAuth1/Crypto/Base64Transcoder.c` | Usado pelo signer OAuth1 atual, sem alteração criptográfica |
| `Sources/USPAuthKit/Core/hmac.h` | Authentication/Provider/OAuth1/Crypto | `Sources/USPAuthKit/Authentication/Provider/OAuth1/Crypto/hmac.h` | Usado pelo signer OAuth1 atual, sem alteração criptográfica |
| `Sources/USPAuthKit/Core/hmac.c` | Authentication/Provider/OAuth1/Crypto | `Sources/USPAuthKit/Authentication/Provider/OAuth1/Crypto/hmac.c` | Usado pelo signer OAuth1 atual, sem alteração criptográfica |
| `Sources/USPAuthKit/Core/sha1.h` | Authentication/Provider/OAuth1/Crypto | `Sources/USPAuthKit/Authentication/Provider/OAuth1/Crypto/sha1.h` | Usado pelo signer OAuth1 atual, sem alteração criptográfica |
| `Sources/USPAuthKit/Core/sha1.c` | Authentication/Provider/OAuth1/Crypto | `Sources/USPAuthKit/Authentication/Provider/OAuth1/Crypto/sha1.c` | Usado pelo signer OAuth1 atual, sem alteração criptográfica |
| `Sources/USPAuthKit/Core/USPAuthSession.h` | Session | `Sources/USPAuthKit/Session/USPAuthSession.h` | Responsabilidade real; somente localização, sem novo tipo/contrato |
| `Sources/USPAuthKit/Core/USPAuthSession.m` | Session | `Sources/USPAuthKit/Session/USPAuthSession.m` | Responsabilidade real; somente localização, sem novo tipo/contrato |
| `Sources/USPAuthKit/Core/USPAuthSessionStore.h` | Legacy/Persistence | `Sources/USPAuthKit/Legacy/Persistence/USPAuthSessionStore.h` | Adapter/contrato histórico, não domínio neutro |
| `Sources/USPAuthKit/Core/USPAuthSessionStore.m` | Legacy/Persistence | `Sources/USPAuthKit/Legacy/Persistence/USPAuthSessionStore.m` | Adapter/contrato histórico, não domínio neutro |
| `Sources/USPAuthKit/Core/USPMobileBackendClient.h` | MobileBackend | `Sources/USPAuthKit/MobileBackend/USPMobileBackendClient.h` | Responsabilidade real; somente localização, sem novo tipo/contrato |
| `Sources/USPAuthKit/Core/USPMobileBackendClient.m` | MobileBackend | `Sources/USPAuthKit/MobileBackend/USPMobileBackendClient.m` | Responsabilidade real; somente localização, sem novo tipo/contrato |
| `Sources/USPAuthKit/Core/USPHTTPTransport.h` | Infrastructure/Networking | `Sources/USPAuthKit/Infrastructure/Networking/USPHTTPTransport.h` | Responsabilidade real; somente localização, sem novo tipo/contrato |
| `Sources/USPAuthKit/Core/USPHTTPTransport.m` | Infrastructure/Networking | `Sources/USPAuthKit/Infrastructure/Networking/USPHTTPTransport.m` | Responsabilidade real; somente localização, sem novo tipo/contrato |
| `Sources/USPAuthKit/Core/HTTPClient.h` | Infrastructure/Networking | `Sources/USPAuthKit/Infrastructure/Networking/HTTPClient.h` | Responsabilidade real; somente localização, sem novo tipo/contrato |
| `Sources/USPAuthKit/Core/HTTPClient.m` | Infrastructure/Networking | `Sources/USPAuthKit/Infrastructure/Networking/HTTPClient.m` | Responsabilidade real; somente localização, sem novo tipo/contrato |
| `Sources/USPAuthKit/Core/USPAuthBrowser.h` | Infrastructure/Browser | `Sources/USPAuthKit/Infrastructure/Browser/USPAuthBrowser.h` | Responsabilidade real; somente localização, sem novo tipo/contrato |
| `Sources/USPAuthKit/Core/USPAuthBrowser.m` | Infrastructure/Browser | `Sources/USPAuthKit/Infrastructure/Browser/USPAuthBrowser.m` | Responsabilidade real; somente localização, sem novo tipo/contrato |
| `Sources/USPAuthKit/UI/LoginWebViewController.h` | Infrastructure/Browser | `Sources/USPAuthKit/Infrastructure/Browser/LoginWebViewController.h` | Responsabilidade real; somente localização, sem novo tipo/contrato |
| `Sources/USPAuthKit/UI/LoginWebViewController.m` | Infrastructure/Browser | `Sources/USPAuthKit/Infrastructure/Browser/LoginWebViewController.m` | Responsabilidade real; somente localização, sem novo tipo/contrato |
| `Sources/USPAuthKit/Core/KeychainItemWrapper.h` | Infrastructure/Security | `Sources/USPAuthKit/Infrastructure/Security/KeychainItemWrapper.h` | Responsabilidade real; somente localização, sem novo tipo/contrato |
| `Sources/USPAuthKit/Core/KeychainItemWrapper.m` | Infrastructure/Security | `Sources/USPAuthKit/Infrastructure/Security/KeychainItemWrapper.m` | Responsabilidade real; somente localização, sem novo tipo/contrato |
| `Sources/USPAuthKit/Adapters/USPAuthKitMutableURLRequest.h` | Legacy/Requests | `Sources/USPAuthKit/Legacy/Requests/USPAuthKitMutableURLRequest.h` | Adapter/contrato histórico, não domínio neutro |
| `Sources/USPAuthKit/Adapters/USPAuthKitMutableURLRequest.m` | Legacy/Requests | `Sources/USPAuthKit/Legacy/Requests/USPAuthKitMutableURLRequest.m` | Adapter/contrato histórico, não domínio neutro |
| `Sources/USPAuthKit/Core/OAuthConfig.h` | Legacy/Configuration | `Sources/USPAuthKit/Legacy/Configuration/OAuthConfig.h` | Adapter/contrato histórico, não domínio neutro |
| `Tests/USPAuthKitTests/USPAuthServiceSessionTests.swift` | Public | `Tests/USPAuthKitTests/Public/USPAuthServiceSessionTests.swift` | Implementação de tipo público; headers exportados ficam em include |
| `Tests/USPAuthKitTests/USPAuthKitTests.swift` | Profile | `Tests/USPAuthKitTests/Profile/USPAuthKitTests.swift` | Responsabilidade real; somente localização, sem novo tipo/contrato |
| `Tests/USPAuthKitTests/Fixtures/SwiftSessionConsumerFixture.swift` | Compatibility/Swift | `Tests/USPAuthKitTests/Compatibility/Swift/SwiftSessionConsumerFixture.swift` | Responsabilidade real; somente localização, sem novo tipo/contrato |
| `Tests/USPAuthKitObjCFixture/USPAuthKitObjCFixture.m` | Compatibility/ObjectiveC | `Tests/USPAuthKitTests/Compatibility/ObjectiveC/USPAuthKitObjCFixture.m` | Responsabilidade real; somente localização, sem novo tipo/contrato |
| `Tests/USPAuthKitObjCFixture/include/USPAuthKitObjCFixture.h` | Compatibility/ObjectiveC/include | `Tests/USPAuthKitTests/Compatibility/ObjectiveC/include/USPAuthKitObjCFixture.h` | Responsabilidade real; somente localização, sem novo tipo/contrato |
| `Tests/Security/HMACInputTests.c` | Authentication/OAuth1/Crypto | `Tests/USPAuthKitTests/Authentication/OAuth1/Crypto/HMACInputTests.c` | Usado pelo signer OAuth1 atual, sem alteração criptográfica |

Além dos moves: USPIdentity.h/m serão extraídos para Profile a partir de
USPAuthSession.h/m, com corpos preservados. Cinco include headers e resource raiz
não se movem. Compatibility adapters na fachada permanecem marcados, sem extrair
categorias produtivas que alterariam encapsulamento/lifecycle.

## Testes e build

Organizar40testes ObjC existentes em categorias da mesma classe XCTest por área,
com Support compartilhado. Preservar selectors/corpos/contagem/fake lazy; não criar
classes públicas/test framework. Áreas: Authentication (coordinator e OAuth1),
Profile, Session, MobileBackend, Infrastructure/Networking e Browser, Compatibility.
R02 Swift move byte-idêntico; fixture ObjC mantém target separado com novo path.
SPM exclui dirs ObjC do testTarget Swift; harness compila os mesmos arquivos reais.
Ajustar headerSearchPaths internos, scriptC e referências Xcode, sem listsources
no product. Protocols existentes somente; nenhuma pasta especulativa/vazia.

Validar host/cross/iOS64/R02/fake/Swift/ObjC/API5/ASanUBSan/diffcheck. Auditar termos
OAuth fora do provider e perfil dentro dele, reportar compatibilidade residual.
Moves por rename filesystem preservam conteúdo; git reconhece quando staged,
sem fazer commit ou escrever index. Revisar diffsummary/status. Documentar árvore
real e limitações (runtime14/Keychain/consumidores/contrato futuro pendentes).


## Ajuste após auditoria residual

OAuthConfig.h não é exportado nem adapter necessário da API pública; é configuração
OAuth1 histórica. Destino final ajustado para Authentication/Provider/OAuth1.
USPAuthKitMutableURLRequest só constrói request com headers estáticos; não representa
adapter de autenticação pública. Mantido em Infrastructure/Networking, não depósito
Legacy. Único adapter com responsabilidade comprovada em Legacy é o store de
schema histórico. Comentário OAuth do VC browser privado foi neutralizado; callback
policy segue provider. Nenhum código órfão removido sem auditoria própria R19.
