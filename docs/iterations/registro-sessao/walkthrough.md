# Registro da sessão mobile

O coordinator registra a identidade antes de concluir `ensureLoggedIn`, inclusive ao reutilizar credenciais. Cada chamada com sessão em cache registra novamente, evitando confiar no flag legado, que não identifica usuário, app ou ambiente. Falhas retornam erro e mantêm a identidade para uma nova tentativa. `isLoggedIn` continua indicando reconhecimento local da sessão; consumidores que precisam de registro confirmado devem aguardar `ensureLoggedIn`.

O token de notificação não bloqueia o registro inicial: atualizações recebidas durante o login são encaminhadas depois de sua conclusão. Falhas de atualização podem ser novamente tentadas ao receber o mesmo token; após reinício, o registro executado por `ensureLoggedIn` usa o token persistido. Logout cancela operações e descarta callbacks antigos. Não há novo mecanismo de retry automático em background.

O sucesso do endpoint continua definido pelo contrato existente: resposta HTTP 2xx. Não foi inferido contrato de erro de negócio no corpo. APIs públicas e formato de persistência permanecem inalterados. O registro extra em cada `ensureLoggedIn` com cache exige rede e pode aumentar chamadas ao backend; uma falha agora impede intencionalmente o retorno de sucesso nesse caminho.

Validação: comparação da API pública aprovada e harness iOS com 72 testes aprovados, sem falhas, no Simulator iOS 27. O SDK exigiu, somente na invocação, `ARCHS=arm64` e `IPHONEOS_DEPLOYMENT_TARGET=15.0`; isso não valida execução no iOS 14. A primeira compilação tentou combinar arquiteturas incompatíveis; a primeira suíte executada revelou um teste que assumia o retorno imediato com cache, atualizado para o novo contrato.
