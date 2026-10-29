# USPJourneyKit — plano (STI-212)

## Objetivo e escopo

Adicionar um único produto Swift `USPJourneyKit`, com contrato v1 tipado,
coordenação de tentativas e integração Firebase Analytics/Crashlytics no mesmo
módulo. Preservar APIs de USPAuthKit/USPObservabilityKit, Swift tools 6.1 e iOS 14.
Não instrumentar apps, publicar tags nem aprovar regras do Cardápio nesta tarefa.

Base da implementação: commit `cbd7a0d` do USPMobileKit; contrato STI-13 e decisão
de arquitetura de 28/10/2026. Implementação inicialmente em cópia Git isolada,
posteriormente integrada ao repositório original e organizada em commits por tema.

## Abordagem

1. Domínio: cinco eventos, identificador UUID por tentativa, versão de contrato,
   catálogo de etapas e parâmetros de enumeração permitidos; sem valores livres.
2. Coordenação isolada no MainActor: tentativas concorrentes, transições explícitas,
   terminais únicos, remoção de contexto sem evento de abandono; reporter injetável.
3. Integração: Firebase no próprio target, configuração e coleta pertencem ao app;
   duas permissões dinâmicas independentes e desativadas por padrão. Falha de
   reporter não modifica transição funcional. Diagnóstico técnico opcional,
   sanitizado por ocorrência, sem custom keys globais do Crashlytics.
4. Testes determinísticos: contrato, validação, concorrência/transições,
   falha do reporter, políticas de coleta e diagnóstico. Fixtures JSON portáveis
   para Android e exemplo de consumidor compilado pelos testes.
5. Documentação: arquitetura atual, integração, compatibilidade e walkthrough.

## Dependência e risco de adoção

Firebase 12/13 exige iOS 15; Firebase 11 é compatível com iOS 14. Usar a faixa
11.15..<12 sem elevar a plataforma mínima. O Cardápio atual exige Firebase >=12.12.1;
essa faixa não resolve junto com esta entrega. A adoção no piloto exige decisão
explícita de versões/plataforma em tarefa própria, sem downgrade automático.
O e-Card/Jornal/Patrimônio têm checkouts locais Firebase 11.15.0 disponíveis.

## Validação e conclusão

Executar build/testes SwiftPM, baseline de API Auth, teste de crypto com sanitizers,
build iOS do novo produto contra SDK real e compatibilidade dos produtos existentes
conforme capacidades do ambiente. Registrar impedimentos de rede/simulador.
Testes em memória não comprovam ingestão Firebase; aceite remoto é STI-15.
Concluir com diff revisável, documentação de limites e patch aplicável ao baseline.
