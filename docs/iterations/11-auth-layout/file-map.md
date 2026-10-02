# Mapa final de arquivos

47moves filesystem (conteúdo e permissões conservados). Nenhum tipo público renomeado.
Novos arquivos de produção são somente a separação USPIdentity.h/m, sem novo tipo.

| Origem | Destino real | Conteúdo |
|---|---|---|
| `Sources/USPAuthKit/Adapters/USPAuthService.m` | `Sources/USPAuthKit/Public/USPAuthService.m` | Byte-idêntico |
| `Sources/USPAuthKit/Core/USPAuthUser.m` | `Sources/USPAuthKit/Public/USPAuthUser.m` | Byte-idêntico |
| `Sources/USPAuthKit/Core/USPAuthVinculo.m` | `Sources/USPAuthKit/Public/USPAuthVinculo.m` | Byte-idêntico |
| `Sources/USPAuthKit/Core/USPAuthConfig.m` | `Sources/USPAuthKit/Public/USPAuthConfig.m` | Byte-idêntico |
| `Sources/USPAuthKit/Core/USPAuthServiceInternal.h` | `Sources/USPAuthKit/Authentication/Composition/USPAuthServiceInternal.h` | Byte-idêntico |
| `Sources/USPAuthKit/Core/USPApplicationConfiguration.h` | `Sources/USPAuthKit/Configuration/USPApplicationConfiguration.h` | Byte-idêntico |
| `Sources/USPAuthKit/Core/USPApplicationConfiguration.m` | `Sources/USPAuthKit/Configuration/USPApplicationConfiguration.m` | Byte-idêntico |
| `Sources/USPAuthKit/Core/USPAuthenticationCoordinator.h` | `Sources/USPAuthKit/Authentication/USPAuthenticationCoordinator.h` | Byte-idêntico |
| `Sources/USPAuthKit/Core/USPAuthenticationCoordinator.m` | `Sources/USPAuthKit/Authentication/USPAuthenticationCoordinator.m` | Byte-idêntico |
| `Sources/USPAuthKit/Core/USPAuthenticationProvider.h` | `Sources/USPAuthKit/Authentication/Provider/USPAuthenticationProvider.h` | Byte-idêntico |
| `Sources/USPAuthKit/Core/USPOAuth1AuthenticationProvider.h` | `Sources/USPAuthKit/Authentication/Provider/OAuth1/USPOAuth1AuthenticationProvider.h` | Byte-idêntico |
| `Sources/USPAuthKit/Core/USPOAuth1AuthenticationProvider.m` | `Sources/USPAuthKit/Authentication/Provider/OAuth1/USPOAuth1AuthenticationProvider.m` | Byte-idêntico |
| `Sources/USPAuthKit/Core/OAuth1Controller.h` | `Sources/USPAuthKit/Authentication/Provider/OAuth1/OAuth1Controller.h` | Byte-idêntico |
| `Sources/USPAuthKit/Core/OAuth1Controller.m` | `Sources/USPAuthKit/Authentication/Provider/OAuth1/OAuth1Controller.m` | Byte-idêntico |
| `Sources/USPAuthKit/Core/NSString+URLEncoding.h` | `Sources/USPAuthKit/Authentication/Provider/OAuth1/NSString+URLEncoding.h` | Byte-idêntico |
| `Sources/USPAuthKit/Core/NSString+URLEncoding.m` | `Sources/USPAuthKit/Authentication/Provider/OAuth1/NSString+URLEncoding.m` | Byte-idêntico |
| `Sources/USPAuthKit/Core/Base64Transcoder.h` | `Sources/USPAuthKit/Authentication/Provider/OAuth1/Crypto/Base64Transcoder.h` | Byte-idêntico |
| `Sources/USPAuthKit/Core/Base64Transcoder.c` | `Sources/USPAuthKit/Authentication/Provider/OAuth1/Crypto/Base64Transcoder.c` | Byte-idêntico |
| `Sources/USPAuthKit/Core/hmac.h` | `Sources/USPAuthKit/Authentication/Provider/OAuth1/Crypto/hmac.h` | Byte-idêntico |
| `Sources/USPAuthKit/Core/hmac.c` | `Sources/USPAuthKit/Authentication/Provider/OAuth1/Crypto/hmac.c` | Byte-idêntico |
| `Sources/USPAuthKit/Core/sha1.h` | `Sources/USPAuthKit/Authentication/Provider/OAuth1/Crypto/sha1.h` | Byte-idêntico |
| `Sources/USPAuthKit/Core/sha1.c` | `Sources/USPAuthKit/Authentication/Provider/OAuth1/Crypto/sha1.c` | Byte-idêntico |
| `Sources/USPAuthKit/Core/USPAuthSession.h` | `Sources/USPAuthKit/Session/USPAuthSession.h` | USPIdentity separado |
| `Sources/USPAuthKit/Core/USPAuthSession.m` | `Sources/USPAuthKit/Session/USPAuthSession.m` | USPIdentity separado |
| `Sources/USPAuthKit/Core/USPAuthSessionStore.h` | `Sources/USPAuthKit/Legacy/Persistence/USPAuthSessionStore.h` | Byte-idêntico |
| `Sources/USPAuthKit/Core/USPAuthSessionStore.m` | `Sources/USPAuthKit/Legacy/Persistence/USPAuthSessionStore.m` | Byte-idêntico |
| `Sources/USPAuthKit/Core/USPMobileBackendClient.h` | `Sources/USPAuthKit/MobileBackend/USPMobileBackendClient.h` | Byte-idêntico |
| `Sources/USPAuthKit/Core/USPMobileBackendClient.m` | `Sources/USPAuthKit/MobileBackend/USPMobileBackendClient.m` | Byte-idêntico |
| `Sources/USPAuthKit/Core/USPHTTPTransport.h` | `Sources/USPAuthKit/Infrastructure/Networking/USPHTTPTransport.h` | Byte-idêntico |
| `Sources/USPAuthKit/Core/USPHTTPTransport.m` | `Sources/USPAuthKit/Infrastructure/Networking/USPHTTPTransport.m` | Byte-idêntico |
| `Sources/USPAuthKit/Core/HTTPClient.h` | `Sources/USPAuthKit/Infrastructure/Networking/HTTPClient.h` | Byte-idêntico |
| `Sources/USPAuthKit/Core/HTTPClient.m` | `Sources/USPAuthKit/Infrastructure/Networking/HTTPClient.m` | Byte-idêntico |
| `Sources/USPAuthKit/Core/USPAuthBrowser.h` | `Sources/USPAuthKit/Infrastructure/Browser/USPAuthBrowser.h` | Byte-idêntico |
| `Sources/USPAuthKit/Core/USPAuthBrowser.m` | `Sources/USPAuthKit/Infrastructure/Browser/USPAuthBrowser.m` | Byte-idêntico |
| `Sources/USPAuthKit/UI/LoginWebViewController.h` | `Sources/USPAuthKit/Infrastructure/Browser/LoginWebViewController.h` | Comentário de browser neutralizado |
| `Sources/USPAuthKit/UI/LoginWebViewController.m` | `Sources/USPAuthKit/Infrastructure/Browser/LoginWebViewController.m` | Byte-idêntico |
| `Sources/USPAuthKit/Core/KeychainItemWrapper.h` | `Sources/USPAuthKit/Infrastructure/Security/KeychainItemWrapper.h` | Byte-idêntico |
| `Sources/USPAuthKit/Core/KeychainItemWrapper.m` | `Sources/USPAuthKit/Infrastructure/Security/KeychainItemWrapper.m` | Byte-idêntico |
| `Sources/USPAuthKit/Adapters/USPAuthKitMutableURLRequest.h` | `Sources/USPAuthKit/Infrastructure/Networking/USPAuthKitMutableURLRequest.h` | Byte-idêntico |
| `Sources/USPAuthKit/Adapters/USPAuthKitMutableURLRequest.m` | `Sources/USPAuthKit/Infrastructure/Networking/USPAuthKitMutableURLRequest.m` | Byte-idêntico |
| `Sources/USPAuthKit/Core/OAuthConfig.h` | `Sources/USPAuthKit/Authentication/Provider/OAuth1/OAuthConfig.h` | Byte-idêntico |
| `Tests/USPAuthKitTests/USPAuthServiceSessionTests.swift` | `Tests/USPAuthKitTests/Public/USPAuthServiceSessionTests.swift` | Byte-idêntico |
| `Tests/USPAuthKitTests/USPAuthKitTests.swift` | `Tests/USPAuthKitTests/Profile/USPAuthKitTests.swift` | Byte-idêntico |
| `Tests/USPAuthKitTests/Fixtures/SwiftSessionConsumerFixture.swift` | `Tests/USPAuthKitTests/Compatibility/Swift/SwiftSessionConsumerFixture.swift` | Byte-idêntico |
| `Tests/USPAuthKitObjCFixture/USPAuthKitObjCFixture.m` | `Tests/USPAuthKitTests/Compatibility/ObjectiveC/USPAuthKitObjCFixture.m` | Byte-idêntico |
| `Tests/USPAuthKitObjCFixture/include/USPAuthKitObjCFixture.h` | `Tests/USPAuthKitTests/Compatibility/ObjectiveC/include/USPAuthKitObjCFixture.h` | Byte-idêntico |
| `Tests/Security/HMACInputTests.c` | `Tests/USPAuthKitTests/Authentication/OAuth1/Crypto/HMACInputTests.c` | Byte-idêntico |

Suite interna antiga Tests/USPAuthKitArchitectureTests/USPAuthArchitectureTests.m
foi repartida em Support/USPAuthArchitectureTestCase.h/m e categorias existentes
sob Tests/USPAuthKitTests. Nenhum método de teste removido/renomeado ou comportamento
alterado. Nenhuma implementação produtiva descartada. Core/UI/Adapters e diretórios
antigos vazios foram removidos; include/resource permaneceram no lugar.

| Destino das categorias | Testes existentes |
|---|---|
| `Tests/USPAuthKitTests/Infrastructure/Networking/USPHTTPTransportTests.m` | 3 |
| `Tests/USPAuthKitTests/Session/USPAuthSessionStoreTests.m` | 3 |
| `Tests/USPAuthKitTests/MobileBackend/USPMobileBackendClientTests.m` | 5 |
| `Tests/USPAuthKitTests/Authentication/OAuth1/USPOAuth1ProviderTests.m` | 15 |
| `Tests/USPAuthKitTests/Infrastructure/Browser/USPAuthBrowserTests.m` | 3 |
| `Tests/USPAuthKitTests/Authentication/USPAuthenticationCoordinatorTests.m` | 5 |
| `Tests/USPAuthKitTests/Compatibility/USPAuthFacadeCompatibilityTests.m` | 3 |
| `Tests/USPAuthKitTests/Authentication/USPNeutralProviderTests.m` | 1 |
| `Tests/USPAuthKitTests/Profile/USPProfilePreservationTests.m` | 2 |
