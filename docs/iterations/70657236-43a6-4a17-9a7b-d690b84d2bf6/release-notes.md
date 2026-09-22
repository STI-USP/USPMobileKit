# Release notes — Iteração 1

## Mudanças

- O package SPM agora se chama `USPMobileKit`.
- O novo product `USPObservabilityKit` adiciona os headers de contexto `USP-*`.
- O product e as APIs públicas de `USPAuthKit` permanecem inalterados.

## Compatibilidade

O `USPMobileKit` exige iOS 14 ou superior. Consumidores que ainda possuem
deployment target iOS 12 ou iOS 13 precisam elevá-lo para consumir esta versão.
Essa é a única breaking change da Iteração 1; não houve breaking change na API
pública de `USPAuthKit`.

## Distribution URL

O repositório canônico é
`https://github.com/STI-USP/USPMobileKit.git`; `origin` aponta para ele. O
GitLab legado permanece configurado somente como remote `legacy`, para
rastreabilidade. Novas integrações não devem depender de redirects.

## Installation ID

`USP-Installation-Id` é um UUID pseudônimo de instalação em `UserDefaults`:
é reutilizado em novas execuções e atualizações, removido na desinstalação e
gerado novamente na reinstalação. Um restore de backup pode restaurar o mesmo
valor em outro dispositivo temporariamente. Ele não identifica permanentemente
o usuário ou dispositivo e não deve ser migrado para Keychain apenas para
persistir após reinstalação.
