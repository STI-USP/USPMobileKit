# USPAuthKit

`USPAuthKit` é um package SPM (Objective-C) para autenticação interna via OAuth 1.0a + pós-processamento de usuário USP.

## O que este kit faz

Este projeto **implementa OAuth USP**. O fluxo completo é:

1. Executa OAuth 1.0a (`request_token` -> `authorize` -> `access_token`).
2. Obtém dados de usuário `wsusuario`. 
3. Monta e cacheia `USPAuthUser`.
4. Registra token no backend.

Nos apps clientes, o identificador para chamadas internas deve ser o `wsuserid` (token funcional de autorização interna).

## Requisitos

- iOS 12+
- Xcode com suporte a Swift Package Manager

## Instalação

Adicione o repositório em `File > Add Packages...` no Xcode e selecione o target do app.

## Integração rápida (Swift)

```swift
import USPAuthKit

USPAuthService.configure(
    withEnvironment: .dev,
    consumerKey: "SEU_CONSUMER_KEY",
    consumerSecret: "SEU_CONSUMER_SECRET",
    appKey: "SUA_APP_KEY"
)
// Opcional: sobrescreva se seu backend exigir outro valor de header.
// USPAuthService.sharedService().backendHeaderValue = "SEU-HEADER-INTERNO"

USPAuthService.sharedService().updateNotificationToken("TOKEN_PUSH")

USPAuthService.sharedService().ensureLoggedIn(from: viewController) { user, error in
    if let error {
        print("Falha de login: \(error.localizedDescription)")
        return
    }

    guard
        let wsuserid = USPAuthService.sharedService().currentWSUserId(),
        let user
    else { return }

    print("Usuário autenticado: \(user.nomeUsuario)")
    print("Token para APIs internas (wsuserid): \(wsuserid)")
}
```

## API pública principal

- `USPAuthService.sharedService()`
- `+ configureWithEnvironment:consumerKey:consumerSecret:appKey:`
- `+ configureWithConfig:`
- `- ensureLoggedInFromViewController:completion:`
- `- currentUser`
- `- currentWSUserId`
- `- updateNotificationToken:`
- `- registerTokenWithCompletion:`
- `- invalidateTokenWithCompletion:`
- `- checkTokenWithCompletion:`
- `- logout`

## Estrutura interna

- `USPAuthService`: fachada/orquestração do fluxo.
- `USPAuthSessionStore`: persistência da sessão (`NSUserDefaults`).
- `OAuth1Controller`: assinatura e execução das etapas OAuth.
- `HTTPClient`: POST JSON para serviços internos.
- `USPAuthUser` e `USPAuthVinculo`: modelos de domínio retornados do backend.

## Estratégia de testes em apps clientes

Checklist mínimo:

1. Login com sucesso retorna `USPAuthUser` e `currentWSUserId` não vazio.
2. Reabertura do app reutiliza sessão (`isLoggedIn == true`) sem novo login.
3. `updateNotificationToken` após login dispara registro de token sem erro.
4. Chamadas internas do app usando `wsuserid` retornam autorização válida.
5. `logout` remove sessão e exige novo login.

## Testes do package

```bash
swift test
```
