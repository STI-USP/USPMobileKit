# R02 — Contrato público de sessão: walkthrough

## Objetivo e resultado

Caracterizar sessão do USPAuthKit contra implementação iOS antes das extrações.
**R02 concluído no escopo solicitado**: 18 testes novos executados, fixtures Swift
e ObjC compiladas/linkadas/executadas. Não foram corrigidos comportamentos de
produção. Baseline: sete documentos de modernização / produção `11d9582`.

## Estado anterior e resultante

Antes: seis testes de Auth cobriam modelos/config/parser; serviço UIKit não era
exercitado no host. Agora: 24 testes Auth passam no harness iOS (18 novos + 6
existentes). A suíte nova é explicitamente skipped no macOS, não emula o serviço.

## Arquivos e decisões

- USPAuthServiceSessionTests.swift: suite UUID por teste, limpeza antes/depois,
  matriz data-driven com expectativas explícitas, perfis inválidos e logout.
- SwiftSessionConsumerFixture.swift: import público e nomes reais Swift, chamada
  pelo XCTest; sem nova API Swift.
- USPAuthKitObjCFixture.m/header: consumidor público, helper isolado de defaults
  e spy das duas operações públicas de invalidação. Somente código de testes.
- Package.swift: target auxiliar ObjC só dependido pelos testes iOS, sem product
  extra/dependências nos products de produção.
- iOSSessionHarness: um target XCTest/scheme com package local, mesmos arquivos
  de testes e bridging header; sem dependências externas ou cópia de Auth.
- APIBaseline/USPAuthKit: cópia dos cinco headers; script Python compara
  declarações/tipos/nullability ignorando comentários/whitespace. Fixture Swift
  protege nomes importados.
- validation.md e roadmap: resultados e progresso R02; roadmap original mantido.

userData readonly foi semeado pelas keys/NSData JSON legadas em suite descartável;
nenhum store interno é importado. Para init/shared/configurar sem defaults reais,
helper substitui standardUserDefaults somente no bloco síncrono e restaura IMP
em @finally. Não há swizzle do SDK, DI nova ou alteração de produção. Desabilitada
execução paralela dos testes no mesmo processo. KVC só observa/restaura config
público nil, que contradiz sua annotation nonnull legada.

## Comportamentos conhecidos

Matriz de oito estados registrada em [validation.md](../../modernization/validation.md#matriz-executada).
currentUser/WS podem existir sem OAuth completo; isLoggedIn só presença local e
não considera isRegistered ou validade remota. Perfil incompleto não vazio com
par OAuth conta como sessão mesmo sem wsuserid. Null/missing wsuserid retornam
nil no serviço versus string vazia no modelo; string vazia é mantida pelo getter.
Dados inválidos não são apagados. Tokens em memória divergem de defaults removidos.
Push vazio difere entre memória/persistência. Config/appKey/header não persistem.

Logout limpa tokens/perfil/push/plataforma/flag, conserva configuração e keys
alheias, retorna estado limpo imediatamente e não chama métodos públicos de
invalidação. O spy não observa todo transporte: essa limitação é explícita.
Testes LegacyBaseline não declaram esses comportamentos desejáveis.

## Validação

Build host OK; host 66 pass/1 skip/0 fail. Cross-build SwiftPM iOS15 com todos os
tests compile/link OK. Harness Xcode via XcodeBuildMCP: iPhone18Pro iOS27.0 arm64,
24 pass/0 skip/0 fail; xcresult confirma, nm confirma serviço e fixtures definidos.
Primeiro build rejeitou deployment14; execução usou override15 **só em CLI**.
Outra tentativa revelou captura Swift no teste, corrigida com [self].
Nenhuma correção de produção. Dois warnings SDK preexistentes mantidos.
Checker API: cinco headers iguais; cópias temporárias com selector/tipo/nullability
alterados corretamente rejeitadas. Pbxproj lint e diff check OK.

Comandos/resultados completos em [validation.md](../../modernization/validation.md#r02--testes-do-contrato-público-de-sessão).
Nenhuma fixture fez login ou usou credencial/backend real.

## Compatibilidade e limitações

Zero breaking changes implementados. Sources, headers públicos, selectors,
nullability, crypto, rede, persistência, products e iOS14 declarado preservados.
Não validado runtime iOS14 nem linkage das constantes C de versão sem definição.
Sem testes de UI/login/requests/callbacks tardios, apps externos ou hardening.
Sucesso R02 não fecha o gate inteiro da Fase0. Artefatos xcresult/logs são efêmeros
em /tmp; evidência resumida durável na documentação.

## Única próxima tarefa

R01: inventariar uso de APIs/keys/runtime/configuração nos apps Swift/ObjC/híbridos
antes de iniciar extrações internas. Não implementada nesta entrega.
