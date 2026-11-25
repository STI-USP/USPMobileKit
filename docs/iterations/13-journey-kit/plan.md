# USPJourneyKit — plano (STI-212)

## Objetivo e escopo

Adicionar um único produto Swift `USPJourneyKit`, com contrato v1 tipado,
coordenação de tentativas e reporter para Firebase Analytics/Crashlytics no mesmo módulo. Preservar APIs de USPAuthKit/USPObservabilityKit, Swift tools 6.1 e iOS 14.
Não instrumentar apps, publicar tags nem aprovar regras do Cardápio nesta tarefa.

Base da implementação: commit `cbd7a0d` do USPMobileKit; contrato STI-13 e decisão
de arquitetura de 28/10/2026. Implementação inicialmente em cópia Git isolada,
posteriormente integrada ao repositório original e organizada em commits por tema.

## Abordagem

1. Domínio: cinco eventos, identificador UUID por tentativa, versão de contrato,
   catálogo de etapas e parâmetros de enumeração permitidos; sem valores livres.
2. Coordenação isolada no MainActor: tentativas concorrentes, transições explícitas,
   terminais únicos, remoção de contexto sem evento de abandono; reporter injetável.
3. Integração: reporter no target, SDK, configuração e coleta pertencem ao app;
   duas permissões dinâmicas independentes e desativadas por padrão. Falha de
   reporter não modifica transição funcional. Diagnóstico técnico opcional,
   sanitizado por ocorrência, sem custom keys globais do Crashlytics.
4. Testes determinísticos: contrato, validação, concorrência/transições,
   falha do reporter, políticas de coleta e diagnóstico. Fixtures JSON portáveis
   para Android e exemplo de consumidor compilado pelos testes.
5. Documentação: arquitetura atual, integração, compatibilidade e walkthrough.

## Dependência e risco de adoção

A faixa Firebase 11 do desenho inicial conflita com Firebase 12.12.1 do
Cardápio+. Retirar a dependência do manifesto e receber as operações do SDK do
app, mantendo o reporter no produto único e o deployment target iOS 14.

## Validação e conclusão

Executar build/testes SwiftPM, baseline de API Auth, teste de crypto com sanitizers,
build iOS do pacote e validação da composição contra o SDK real do app
conforme capacidades do ambiente. Registrar impedimentos de rede/simulador.
Testes em memória não comprovam ingestão Firebase; aceite remoto é STI-15.
Concluir com diff revisável, documentação de limites e patch aplicável ao baseline.
