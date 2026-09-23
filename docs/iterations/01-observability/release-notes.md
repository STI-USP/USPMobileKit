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

O checkout local já se chama `USPMobileKit`, mas o `origin` auditado ainda é
`git@gitlab.uspdigital.usp.br:divisao-de-sistemas/mobile/authkit.git`.
Não criar tag/release enquanto o repositório remoto não for renomeado ou
publicado com uma URL canônica `USPMobileKit` e o `origin` não for atualizado.
Não depender de redirect permanente do GitLab.

## Installation ID

`USP-Installation-Id` é um UUID pseudônimo de instalação em `UserDefaults`:
é reutilizado em novas execuções e atualizações, removido na desinstalação e
gerado novamente na reinstalação. Um restore de backup pode restaurar o mesmo
valor em outro dispositivo temporariamente. Ele não identifica permanentemente
o usuário ou dispositivo e não deve ser migrado para Keychain apenas para
persistir após reinstalação.
