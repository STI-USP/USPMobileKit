# Guias vigentes de integração

## Objetivo e baseline

Consolidar a orientação de novos consumidores e a migração incremental dos legados,
com base nos cinco headers públicos, implementações públicas, Package.swift,
arquitetura, validação, walkthroughs da modernização e inventário do Cardápio.
Somente documentação; sem commit, mudança de API, código, testes ou dependências.

## Abordagem

1. Conferir selectors Objective-C, nomes importados em Swift e semântica real.
2. Tornar README e docs/integration a entrada canônica para consumidores.
3. Substituir os guias duplicados em docs/authentication por apontadores;
   preservar arquitetura e registros históricos.
4. Documentar APIs recomendadas, compatibilidade e limites sem inventar APIs.
5. Validar links, snippets por compile-check, headers e diff documental.

## Riscos e critérios de conclusão

Evitar prometer validade remota, revogação, perfil completo ou versão de release
não demonstrada. Não converter wsuserid em token OAuth ou número USP. Modelo tipado
não cobre todos os aliases/campos legados; nesses casos, manter compatibilidade
isolada e documentada até existir alternativa pública.

Concluir com navegação bidirecional, exemplos conferidos contra a API iOS real,
cinco headers byte-idênticos ao HEAD e somente arquivos Markdown alterados.
Compile-check não substitui execução de login; homologação anterior é evidência
histórica, não uma nova execução desta tarefa.
