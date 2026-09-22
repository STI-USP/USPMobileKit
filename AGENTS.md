AGENTS.md

Este arquivo define as orientações gerais para agentes de IA que trabalham neste repositório.

O objetivo é garantir que alterações sejam realizadas de forma incremental, rastreável e compatível com a arquitetura e os padrões existentes do projeto.

⸻

1. Princípios gerais

Antes de modificar o código:

1. Explore o repositório e compreenda sua estrutura.
2. Identifique arquitetura, tecnologias, dependências e convenções existentes.
3. Leia a documentação disponível.
4. Verifique testes, scripts de build, lint, CI/CD e outras formas de validação.
5. Evite assumir comportamentos que possam ser verificados diretamente no código.

Prefira sempre:

* alterações pequenas e incrementais;
* compatibilidade com código existente;
* reutilização de padrões já adotados;
* soluções simples antes de introduzir novas abstrações;
* mudanças que possam ser validadas automaticamente;
* documentação das decisões relevantes.

Não realize refatorações não relacionadas à tarefa atual sem justificativa clara.

⸻

2. Antes de implementar

Para cada tarefa relevante, determine:

* qual problema está sendo resolvido;
* quais componentes são afetados;
* quais comportamentos existentes devem ser preservados;
* quais riscos de regressão existem;
* como a alteração será validada.

Antes de criar novos componentes, procure implementações ou abstrações equivalentes no projeto.

Quando houver mais de uma abordagem possível, prefira aquela que:

1. mantém compatibilidade;
2. reduz acoplamento;
3. favorece testabilidade;
4. segue os padrões existentes;
5. introduz a menor complexidade necessária.

⸻

3. Planejamento

Mudanças pequenas e localizadas podem ser implementadas diretamente.

Para alterações estruturais, arquiteturais ou que envolvam múltiplos componentes, crie ou atualize:

docs/iterations/<iteration>/plan.md

O plano deve registrar, quando aplicável:

* objetivo;
* contexto;
* escopo;
* componentes afetados;
* abordagem proposta;
* etapas de implementação;
* estratégia de testes;
* riscos;
* critérios de conclusão.

O plano deve ser atualizado quando decisões relevantes mudarem durante a implementação.

⸻

4. Implementação

Durante a implementação:

* preserve APIs públicas sempre que possível;
* evite breaking changes não solicitados;
* mantenha responsabilidades claramente separadas;
* evite duplicação desnecessária;
* não introduza dependências externas sem necessidade;
* não altere configurações globais sem justificativa;
* mantenha compatibilidade com os ambientes suportados pelo projeto.

Não remova código aparentemente não utilizado sem verificar referências, compatibilidade ou uso indireto.

Não altere comportamento existente apenas para facilitar a implementação de uma nova funcionalidade.

⸻

5. Testes

Toda alteração deve considerar impacto nos testes.

Quando aplicável:

* adicione testes para novos comportamentos;
* atualize testes afetados;
* preserve testes de regressão;
* execute primeiro os testes mais próximos da alteração;
* execute uma validação mais ampla antes de considerar a tarefa concluída.

Priorize testes determinísticos e independentes de serviços externos.

Não remova ou desabilite testes apenas para obter sucesso na execução.

Se algum teste não puder ser executado, registre explicitamente essa limitação.

⸻

6. Build e validação

Antes de concluir uma tarefa, execute as validações disponíveis no projeto, como:

* build;
* testes automatizados;
* lint;
* análise estática;
* verificação de formatação;
* scripts de validação;
* pipelines locais, quando disponíveis.

Uma tarefa não deve ser considerada concluída apenas porque o código foi escrito.

Quando alguma validação falhar:

1. investigue a causa;
2. determine se a falha foi introduzida pela alteração;
3. corrija quando estiver dentro do escopo;
4. documente quando não puder ser resolvida.

⸻

7. Documentação da implementação

Para alterações relevantes, crie ou atualize:

docs/iterations/<iteration>/walkthrough.md

O walkthrough deve representar o estado final efetivamente implementado, e não apenas o plano original.

Inclua, quando aplicável:

Objetivo

O que foi implementado e qual problema foi resolvido.

Estado anterior

Como o sistema funcionava antes da alteração.

Estado resultante

Como o sistema funciona após a implementação.

Quando útil, utilize diagramas Mermaid para representar arquitetura, dependências ou fluxos.

Alterações realizadas

Principais arquivos, módulos, componentes ou configurações modificados.

Decisões técnicas

Decisões relevantes tomadas durante a implementação e suas justificativas.

Testes e validações

Quais testes, builds ou verificações foram executados e seus resultados.

Compatibilidade

Registre impactos em:

* APIs públicas;
* versões suportadas;
* persistência;
* integrações;
* configuração;
* dependências.

Indique explicitamente eventuais breaking changes.

Limitações

Pendências, riscos conhecidos ou aspectos não cobertos pela implementação.

Próximos passos

Evoluções naturais identificadas durante o trabalho, sem implementá-las automaticamente caso estejam fora do escopo atual.

⸻

8. Estrutura recomendada

Quando ainda não existir estrutura de documentação para iterações, utilize:

docs/
└── iterations/
    └── <iteration>/
        ├── plan.md
        └── walkthrough.md

Use nomes curtos e descritivos para a iteração, por exemplo:

docs/iterations/
├── 01-foundation/
├── 02-observability/
└── 03-ci-integration/

Não crie diretórios ou documentos vazios antecipadamente.

⸻

9. Decisões arquiteturais

Decisões arquiteturais importantes e duradouras não devem existir apenas no histórico de uma conversa com o agente.

Quando uma decisão tiver impacto permanente na arquitetura, considere registrá-la em:

docs/architecture/

Walkthroughs documentam o que aconteceu em uma iteração.

Documentação arquitetural registra como o sistema deve funcionar atualmente.

Evite usar walkthroughs antigos como única fonte de verdade sobre a arquitetura atual.

⸻

10. Dependências

Antes de adicionar uma nova dependência:

1. verifique se o problema pode ser resolvido com recursos já disponíveis;
2. avalie manutenção e compatibilidade;
3. evite dependências para funcionalidades triviais;
4. registre dependências arquiteturalmente relevantes.

Não atualize dependências não relacionadas à tarefa sem necessidade.

⸻

11. Segurança e dados sensíveis

Nunca adicione ao repositório:

* tokens;
* senhas;
* chaves privadas;
* credenciais;
* arquivos .env com segredos;
* dados pessoais ou sensíveis utilizados apenas para testes.

Utilize mecanismos apropriados de configuração e gerenciamento de secrets.

Não registre dados sensíveis em logs, fixtures ou exemplos de documentação.

⸻

12. Commits

Quando solicitado a preparar ou sugerir commits:

* mantenha cada commit conceitualmente coeso;
* descreva a alteração realizada;
* evite misturar refatorações não relacionadas;
* não inclua arquivos temporários ou artefatos locais.

Mensagens devem explicar principalmente o que mudou e, quando relevante, por quê.

⸻

13. Escopo do agente

O agente pode identificar melhorias fora do escopo da tarefa, mas não deve implementá-las automaticamente.

Nesses casos:

1. registre a observação;
2. explique o impacto;
3. sugira como próximo passo.

Priorize concluir corretamente o escopo solicitado antes de expandi-lo.

⸻

14. Critério de conclusão

Uma tarefa é considerada concluída quando:

* o comportamento solicitado foi implementado;
* o código está consistente com a arquitetura existente;
* os testes relevantes foram criados ou atualizados;
* as validações aplicáveis foram executadas;
* regressões conhecidas não foram introduzidas;
* a documentação relevante foi atualizada;
* limitações ou pendências foram explicitadas.

O resultado final deve permitir que outro desenvolvedor — humano ou agente — compreenda o que mudou, por que mudou e como validar a implementação.