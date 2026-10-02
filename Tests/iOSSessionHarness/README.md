# USPAuthKit — harness de sessão iOS (R02)

Um único target XCTest iOS, sem app de produção, consome o product **USPAuthKit**
por referência SPM local (`../..`). Compila os mesmos testes em
`Tests/USPAuthKitTests`, a fixture Swift e a fixture Objective-C pelo bridging
header. Não recompila uma implementação substituta do serviço.

```sh
python3 scripts/check-auth-public-api.py
swift build
swift test
xcodebuild -project Tests/iOSSessionHarness/USPAuthSessionHarness.xcodeproj \
  -scheme USPAuthSessionHarness -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -derivedDataPath /tmp/uspauth-r02-derived -parallel-testing-enabled NO \
  -resultBundlePath /tmp/uspauth-r02-tests.xcresult test
```

Selecione um Simulator disponível na sua máquina; nome/UDID não é parte do
contrato. Com SDK27, acrescente `IPHONEOS_DEPLOYMENT_TARGET=15.0` **somente à
invocação** para validar num runtime suportado: o SDK instalado rejeita 14.0.
Package e projeto continuam declarando iOS14. Isso não comprova compatibilidade
runtime iOS14; use uma toolchain/SDK adequada para essa validação.

No ambiente restrito, SwiftPM requer `--disable-sandbox` e module caches em /tmp;
comandos completos e evidência de execução estão em
[validation.md](../../docs/modernization/validation.md#r02--testes-do-contrato-público-de-sessão).

## Isolamento e limites

Cada XCTest cria uma suite UUID e remove seu domínio antes/depois. A matriz limpa
o domínio entre casos. Não usa defaults reais, credenciais reais, backend ou
login. `userData` readonly é semeado como NSData JSON nas keys legadas, sem
importar store ou usar KVC em estado privado.

`init/shared/configure` exigem um único bloco síncrono que substitui
`NSUserDefaults.standardUserDefaults` por uma suite isolada via runtime ObjC.
O helper restaura a implementação em `@finally`; nenhum método do SDK é
swizzled. Não executar esse bloco concorrentemente com consumidores de defaults
no mesmo processo. O scheme e o comando desabilitam testes paralelos; processos
separados não compartilham o singleton. O singleton é criado primeiro nesse bloco,
limpo ao final e permanece vinculado somente à suite de teste, já descartada.
KVC é usado exclusivamente para observar/restaurar `config`, **propriedade
pública declarada nonnull cujo valor inicial real é nil**.

O spy de logout é uma subclasse somente de testes que observa os dois entry
points públicos de invalidação. Prova que esses entry points não são chamados e
que a limpeza é síncrona; não é um observador de todas as requests do processo.
Não invoca servidor, não injeta transporte e não caracteriza callbacks tardios.

Nomes `LegacyBaseline` registram comportamentos existentes, não recomendações.
Uma futura correção intencional deve atualizar o teste e explicar a mudança.

## Baseline da API

`Tests/APIBaseline/USPAuthKit/*.h` contém os cinco headers exportados nesta revisão.
`check-auth-public-api.py` compara declarações e diretivas ignorando comentários
e whitespace. Detecta remoção/adição de header e alterações de selector, tipo,
atributos e nullability. A fixture Swift verifica os nomes importados ao compilar.

As constantes `USPAuthKitVersionNumber/String` continuam declaradas, mas não
possuem definição encontrada; não são referenciadas pelas fixtures para evitar
transformar R02 numa correção de produção. O linkage validado cobre classes,
funções da fixture e a amostra de métodos exercitada, não esses símbolos C.

A suíte de sessão é explicitamente skipped no host macOS sem UIKit. Não confundir
esse skip com execução da implementação iOS. No Simulator foram executados
18 testes de sessão e os 6 testes Auth existentes, sem skips.


## Organização após modernização

R02 em USPAuthKitTests/Public; modelos baseline em Profile; fixtures Swift e ObjC
em Compatibility. Quarenta métodos internos foram distribuídos em categorias da
mesma classe XCTest sob Authentication/OAuth1, Profile, Session, MobileBackend,
Infrastructure e Compatibility, com Support compartilhado. O harness compila todos,
com as implementações produtivas do product SPM;64Auth testes iOS ao todo.
SPM não mistura Swift/ObjC: exclui áreas ObjC do testTarget Swift e conserva target
separado para fixture ObjC. Crypto C sanitizado executa pelo script no host.
Nenhum método R02 foi editado pela movimentação. Não confundir host skip com iOS.
