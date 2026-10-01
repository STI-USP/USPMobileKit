# R01 — consumidor Cardápio USP

## Resultado

Criado [inventário](../../modernization/consumer-api-inventory.md) do checkout
Cardápio, revisão 84e55bc, com resolução SPM 1.4.5, callers Swift/ObjC, adapter
próprio, fluxo de navegação, configuração, APIs, perfil, destinos de wsuserid,
storage, push, logout, runtime, riscos/piloto e lacunas. Roadmap recebe somente
registro incremental de progresso; validation recebe evidências documentais.

Antes não havia consumidor real auditado. Agora há evidência de que Cardápio
pode delegar mecanismo de login inteiramente ao SDK, mas depende de credencial
mobile/perfil, keys `userData`/`isRegistered` e registro implementado pelo app.
Classificação D com superfície funcional B. Logout observado é local + limpeza
de UI/Pix/foto; não há invalidate/revogação/SSO. Não corrigimos comportamentos,
logs com prefixo, fallbacks de identidade ou mocks de testes.

## Compatibilidade e validação

Só documentação alterada. Nenhum código, teste R02, API, package, dependência,
endpoint, storage, configuração ou deployment target modificado. Sem breaking
change e sem commit. Git/status, buscas, parsing PBX/plist/lock, referências e
comparação de conteúdo verificam o escopo; detalhes em
[validation](../../modernization/validation.md#r01--auditoria-do-consumidor-cardápio-usp).
Nenhum build/link/test executado nesta etapa estática. R02 já executado no iOS
continua protegendo o contrato local do SDK; não prova requests/servidor do app.

## Limitações e próximo passo

R01 parcialmente concluído: Cardápio auditado, demais consumidores não definidos
por lista autoritativa. Projetos irmãos não foram classificados como consumidores
pela mera existência. Transparência OAuth2 depende do contrato servidor R03 e
compatibilidade com readers/writers externos. Próxima tarefa única: continuar R01,
confirmando lista com as equipes e auditando o próximo consumidor confirmado.
Não implementado piloto, provider ou R04–R08.
