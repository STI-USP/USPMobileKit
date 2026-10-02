# Auditoria do USPAuthKit — walkthrough

Data: 2026-10-01. Baseline auditada: `11d9582`.

## Objetivo

Estabelecer estado atual, contrato público, riscos e roadmap incremental para autenticação substituível preservando consumidores Swift/Objective-C. Resultado principal: [modernization-roadmap.md](../../modernization/modernization-roadmap.md).

## Estado anterior

USPAuthKit já tinha fachada ObjC, controller OAuth1, store defaults e cliente POST JSON. Documentação anterior descrevia parcialmente o contrato; testes cobriam modelos/config/parser, sem serviço/UI. Codebase e dependências eram os mesmos desta auditoria.

## Estado resultante

Foram criados seis documentos de auditoria/estratégia e um registro de validação em `docs/modernization`, com inventário de todos os headers públicos, 19 grupos de acoplamento OAuth1, 15 achados de segurança e 22 itens de roadmap rastreados a fases/gates. Diagramas representam fluxo atual, fronteiras propostas e coexistência futura. O gate da fase0 ainda exige testes públicos de sessão em iOS e inventário de apps reais.

## Alterações efetivas

Somente Markdown: sete documentos de modernização, plan/walkthrough desta iteração e README. No README foi incluído link do roadmap, corrigido `configure(withEnvironment:...)` para `configure(with:...)` após typecheck, removido exemplo de impressão de wsuserid e esclarecido isLoggedIn/local logout. Nenhum código, endpoint, assinatura, API, teste, dependency, Package.swift, plataforma, recurso ou configuração mudou. Nenhuma pequena correção de código foi necessária para concluir a auditoria.

## Decisões e justificativas

A fronteira interna de provider é adequada, porém só após characterization e composição testável. Preservar API OAuth1 via adapter; tokenSecret e WK antigos permanecem provider1. Não fabricar equivalência com refresh/bearer futuro. Não adicionar refresh/revogação obrigatórios ausentes nem abstrações públicas genéricas. Backend mobile/wsuserid não são automaticamente OAuth1: sua semântica futura é gate P0.

Propostas não foram registradas como arquitetura já vigente em docs/architecture: arquitetura atual e alvo estão explicitamente separadas. Não se criou core compartilhado nem dependência com observabilidade. Nenhum SDK externo de telemetria foi adicionado.

## Testes e validação

Registro reproduzível em [validation.md](../../modernization/validation.md): manifest, build host e 66 XCTest passaram com caches temporários; cross-build iOS15 passou com dois warnings preexistentes. iOS14 cross-build bloqueado pelo mínimo15 do SDK instalado; xcodebuild não reconheceu package direto; CoreSimulator inacessível. Smoke ObjC syntax-only e Swift typecheck passaram; não são testes de linkage/runtime. Quatro verificações C confirmaram digest de referência e mutação de buffers longos. Sem testes ObjC/CI/lint/scripts existentes.

Referências documentais locais, correspondência dos símbolos públicos e git diff --check foram validados. Markdown/Mermaid revisados por inspeção; não há renderer de diagramas configurado.

## Compatibilidade

Zero breaking changes implementados. Products, selectors/tipos/nullability, persistência, versões mínimas, integração, criptografia e dependências intactos. README passou a refletir nome importado em Swift e semântica local já existente. Compatibilidade com apps externos não pode ser certificada sem esses apps; riscos e futuros gates documentados.

## Limitações e próximos passos

Sem acesso aos consumidores/backend, login real, pentest, execução iOS14/Simulator ou relatório de cobertura/Privacy Report. Achados altos não foram corrigidos nesta tarefa de auditoria. Única próxima implementação recomendada: R02/fase0, characterization iOS do contrato público de sessão com fixture Swift/ObjC, defaults isolados, restauração/cache/setters/getters/logout. Não implementada aqui; fases OAuth2 e rollout continuam futuras.
