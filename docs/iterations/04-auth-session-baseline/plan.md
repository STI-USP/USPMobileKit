# R02 — Caracterização do contrato público de sessão

## Objetivo e baseline

Implementar exclusivamente R02/Fase0 a partir dos sete documentos de `docs/modernization`, lidos antes de qualquer alteração. Produção, OAuth, endpoints, persistência, API e mínimo iOS14 permanecem intactos.

## Abordagem

- XCTest Swift iOS com suite UserDefaults única por teste, limpeza antes/depois e matriz explícita de oito estados; payloads inválidos/incompletos, restauração, propriedades e logout.
- Fixture Objective-C exclusivamente de testes para compilação/linkage, observação das chamadas públicas de invalidação e substituição síncrona/temporária de standardUserDefaults ao testar init/shared/configuração. Sem alteração de produção; não executar esse bloco concorrentemente no mesmo processo.
- Fixture Swift integrada à suíte para proteger nomes importados, getters/setters e configuração.
- Baseline leve dos headers exportados, incluindo tipos/nullability; verificação determinística sem dependências externas.
- Harness Xcode mínimo para compilar/linkar/executar os mesmos testes contra UIKit; target auxiliar SPM apenas para testes, sem novo product.

## Validação e riscos

Executar build/test host (com skip explícito do serviço), build/test iOS e fixtures no Simulator via XcodeBuildMCP. CLI sandbox não acessa CoreSimulator, porém MCP listou runtimes disponíveis. Se execução iOS não ocorrer, registrar R02 parcial. Toolchain27 não suporta deployment14 em SwiftBuild: não mudar mínimo do package; qualquer override de validação será registrado.

## Critérios

Matriz e comportamento legado protegidos por assertions, fixtures realmente linkadas e testes iOS executados; zero diffs em Sources. Roadmap atualizado somente com progresso R02 e validation com distinção compilou/linkou/executou. Ausências (login/rede/lifecycle/constantes de versão) explicitadas, sem expansão a R04–R22.
