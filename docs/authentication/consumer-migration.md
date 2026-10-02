# Atualizar aplicativos consumidores

A modernização preserva os cinco headers públicos, selectors, tipos/nullability,
nomes Swift e schema legado. Não há remoção de API, nova annotation `deprecated`
ou migração automática para Keychain. OAuth1 continua default.

Comece atualizando a dependência e compilando o app sem adaptações. Migre usos
acidentais em mudanças separadas, depois de validar comportamento. O responsável
controla os consumidores; compatibilidade temporária não torna storage/protocolo
parte permanente do domínio. [Arquitetura atual](architecture.md) e
[integração nova](new-integration.md) são as referências atuais.

## Níveis de integração

Os níveis classificam dependências, não aplicativos mutuamente exclusivos. Um app
pode estar em vários níveis; `isRegistered` por key é dependência funcional B e
acesso interno D. Esta taxonomia operacional não substitui a classificação A/B/C/D
histórica da auditoria, que usa critérios próprios.

### Nível A — integração recomendada

Configure o aplicativo, use `shared()`/`sharedService`, `ensureLoggedIn`,
`currentUser`, `USPAuthUser`/`USPAuthVinculo`, `user.wsuserid`,
`updateNotificationToken` e `logout`. `isLoggedIn` significa estado local.

Pouca ou nenhuma alteração é esperada para adotar a composição interna OAuth1.
Trate erro e cancelamento, passe um presenter adequado e valide requests próprias
com wsuserid. Configuração consumerKey/consumerSecret continua necessária para o
provider atual; isso não exige que o aplicativo conheça o handshake.

### Nível B — dependência de compatibilidade

`userData`, flag `isRegistered`, leituras de config/baseURL e registro mobile
próprio devem ser inventariados. Prioridade: substituir parsing de dicionário por
`currentUser()` e `user.vinculos`. Use `user.wsuserid` para o identificador.

Se um campo necessário não existe no modelo, documente a necessidade e mantenha
o uso legado isolado até existir alternativa pública. Não invente getter ou
normalização silenciosa. `config.baseURL` continua disponível, mas endpoints do
app devem ter configuração explícita; não inferir toda API USP da URL Auth.

Antes de eliminar registro próprio/flag, compare endpoint/payload, resultado e
momento do registro. O SDK já registra ao completar autenticação e ao atualizar
push em sessão local. Não trocar `isRegistered` por `isLoggedIn`: nenhum dos dois
comprova estado remoto. Não há novo getter público de registro nesta entrega.

### Nível C — dependência OAuth1

Leituras/escritas de `oauthToken`/`oauthTokenSecret`, `loginInWebView`, uso de
consumerKey/consumerSecret fora da configuração e assinatura/handshake próprios
continuam compatíveis com o provider OAuth1, mas devem sair do código novo.

Migre login manual para `ensureLoggedIn` com presenter e usuário tipado. A API
`loginInWebView`/Swift `login(in:completion:)` conclui apenas obtenção de tokens:
não equivale a perfil + registro. Separe testes legados de credencial dos testes
de comportamento do app. Outro mecanismo não precisa imitar tokenSecret ou WK.

### Nível D — dependência interna indevida

Acesso direto a keys de UserDefaults, headers/classes privados, KVC/runtime ou
storage interno deve migrar antes de outro provider/store. Não importar headers
Core nem limpar/gravar defaults para simular logout/login em produção.

Keys atuais `oauthToken`, `oauthTokenSecret`, `userData`, `isRegistered`,
`notificationToken`, `notificationPlatform` permanecem por compatibilidade;
schema/representação não são contrato recomendado de integração. Testes de apps
que semeiam keys precisarão de adaptação controlada quando o storage evoluir.

## Classificação das APIs existentes

| API/dependência | Status para consumidores | Migração/semântica |
|---|---|---|
| sharedService / shared() | Recomendada | Composição default; UI segue a instância/operação |
| configure / USPAuthConfig | Recomendada para OAuth1 atual | Cada app fornece sua configuração; formato público combinado é adapter |
| consumerKey/consumerSecret | Configuração específica OAuth1 | Use somente no bootstrap; não identidade de usuário nem requisitos universais |
| ensureLoggedIn / currentUser / USPAuthUser / USPAuthVinculo | Recomendada | Perfil tipado; lista de vínculos pode ser vazia conforme ambiente |
| isLoggedIn | Recomendada com limite local | Não prova validade/expiração/autorização remota |
| USPAuthUser.wsuserid | Recomendada para recursos USP atuais | Identificador/credencial operacional do perfil, não OAuth access token |
| currentWSUserId | Compatibilidade conveniente | Mesmo identificador; nullable legado difere de string vazia do modelo |
| logout | Recomendada, local | Limpa sessão/push/registro e cancela operações; sem revogação/SSO |
| updateNotificationToken | Recomendada | Atualiza/persiste e registra quando há sessão local |
| notificationToken / notificationPlatform | Compatíveis | Setting direto não equivale a update; default histórico F |
| registerToken / checkToken / invalidateToken | Compatíveis, operações mobile | Prefira variantes com completion; consulta não refresh, invalidate não logout |
| userData | Compatibilidade; evitar novo código | Migrar para modelos tipados; remoção só em major após alternativa/migração |
| oauthToken / oauthTokenSecret | Compatibilidade OAuth1; evitar novo código | Estado do provider exposto pelo adapter; eliminar acesso do consumidor |
| loginInWebView / login(in:) | Compatibilidade OAuth1; evitar novo código | Migrar para ensure; não exigir WK do domínio |
| initWithUserDefaults | Adapter público compatível | Suite útil em testes; não assumir permanência do formato de storage |
| isRegistered e keys internas | Dependência a eliminar | Sem API pública nova inventada; migrar necessidade funcional antes do store |

Cancelamento e rejeição de callback inválido mudaram conscientemente em relação
ao baseline permissivo. Completion única e descarte de resultados tardios protegem
logout. Perfil/cache e logout local continuam caracterizados por R02.

## Checklist de atualização

1. Atualizar dependência para revisão/release conhecida; guardar referência para rollback.
2. Compilar sem modificar código e conferir warnings/imports Swift/Objective-C.
3. Executar login real com sessão vazia.
4. Validar `currentUser`, nome/login e campos usados pelo app.
5. Validar `wsuserid` sem registrá-lo em logs.
6. Validar vínculos; comparar ambiente e dados do backend antes de atribuir regressão.
7. Validar saldo/foto/avisos/pagamentos e demais recursos que usam wsuserid.
8. Validar push e efeitos de registro.
9. Fechar/reabrir e validar restauração de perfil e vínculos.
10. Validar logout local e limpeza de estado próprio do app.
11. Validar novo login após logout.
12. Validar cancelamento e logout com operação em voo.
13. Procurar usos de `userData` e substituí-los quando o modelo já possui os campos.
14. Procurar keys internas e flag `isRegistered`.
15. Procurar manipulação de `oauthToken`/`oauthTokenSecret`.
16. Procurar `loginInWebView`/`login(in:)` e detalhes do protocolo.
17. Migrar usos possíveis para API tipada em pequenas alterações verificáveis.

Na raiz do consumidor, estes comandos imprimem apenas arquivos correspondentes,
evitando expor literals de configuração, tokens ou PII em uma busca ampla:

```bash
rg -l 'USPAuthService|USPAuthUser|USPAuthVinculo|ensureLoggedIn|currentUser' --glob '*.{swift,m,h}'
rg -l 'userData|isRegistered|UserDefaults|NSUserDefaults' --glob '*.{swift,m,h}'
rg -l 'oauthToken|oauthTokenSecret|loginInWebView|login\(in:' --glob '*.{swift,m,h}'
rg -l 'consumerKey|consumerSecret|oauth_verifier|oauth_nonce|HMAC|Authorization' --glob '*.{swift,m,h}'
rg -l 'NSClassFromString|NSSelectorFromString|performSelector|valueForKey|setValue:|Core/' --glob '*.{swift,m,h}'
```

Inspecione contexto localmente, sem copiar credenciais para relatório. Ausência
textual não elimina wrappers, runtime ou targets excluídos do build.

## Cardápio: evidência e migrações posteriores

Primeiro consumidor real homologado com pacote local no iPhone: tokens/callback,
perfil/wsuserid, registro/completion, uso do identificador nos recursos, vínculos
PROD e persistência/restauração. DEV retornava `vinculo: []`; não foi perda no SDK.
[Inventário e escopo da homologação](../modernization/consumer-api-inventory.md#cardápio-usp).

O wrapper do app pode continuar usando a fachada; não controla WK de login.
Ainda deve migrar parsing `userData` para `USPAuthUser`/`USPAuthVinculo`, acesso a
keys/`isRegistered` e registro próprio, após conferir contrato. Preservar wsuserid
em saldo/Pix/boletos/foto/avisos/registro/caches; não substituí-lo por token OAuth.
Revisar logs/cache/logout próprios em tarefas posteriores. Não alterado aqui.

Homologação deste app não comprova todos consumidores, push/cancelamento em todos
ambientes ou runtime iOS14. Rollback é retornar à release/configuração conhecida;
não converter credenciais entre mecanismos. Nenhum outro provider foi implementado.


## Reorganização interna de arquivos

A árvore mudou, não a integração: import USPAuthKit, products/targets produtivos,
headers include, selectors e nomes Swift permanecem. Cardápio não precisa conhecer
pastas internas. Headers Core/UI/Adapters não eram exportados; consumidores nívelD
que importam paths privados precisam remover essa dependência, não tratar nova
árvore como API. Fixtures de consumidores públicos continuam executadas no iOS.
Veja [organização real](architecture.md#organização-do-código) e mapa da iteração11.
