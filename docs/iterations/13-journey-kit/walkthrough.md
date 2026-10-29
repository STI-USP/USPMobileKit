# USPJourneyKit — resultado e validação

## Entrega

Adicionado produto único `USPJourneyKit` ao USPMobileKit, com domínio, coordenação
e integração Firebase no próprio módulo. Os produtos USPAuthKit e
USPObservabilityKit mantêm fontes e APIs; o teste de consumidor agora importa
os três produtos. Base inicial Git `cbd7a0d`, branch inicial `feature/uspjourneykit`.
A implementação foi preparada em cópia Git isolada e posteriormente integrada
ao repositório original, com commits separados para implementação/testes e
documentação. Não houve tag, push, publicação de release nem adoção nos apps.

## Comportamento

- Cinco eventos tipados, UUID por tentativa, `versao_contrato=1`, parâmetros
  específicos em vocabulários finitos, correlação técnica opcional.
- Coordenação MainActor com múltiplas tentativas, grafo opcional, conclusão
  permitida apenas em etapas declaradas e remoção antes do envio terminal.
- Chamadas tardias/duplicadas/estrangeiras não emitem eventos; retry recebe novo ID.
- Nenhum timer, cancelamento automático, abandono emitido, retry de negócio,
  conclusão por HTTP ou interpretação específica de Pix/cardápio no kit.
- Reporter injetável/em memória. Falha do reporter isolada do fluxo; política
  Firebase de Analytics/diagnóstico desativada por padrão, dinâmica e independente.
- Crashlytics recebe somente classificação técnica explícita sanitizada e contexto
  por ocorrência; nenhum Error livre, token, JSON ou custom key global.
- Manifest próprio, guia de consumidor e fixture JSON portátil para Android.

## Validação executada

Toolchain local: Apple Swift 6.4, Xcode/SDK 27. Swift tools 6.1 e iOS 14 continuam
declarados; não foi certificado um runtime/toolchain antigo.

| Verificação | Resultado |
| --- | --- |
| USPJourneyKit XCTest no host | 26 testes, zero falhas; inclui 50 Tasks disputando terminal e callback reentrante |
| Suíte completa host | 94 testes: 93 aprovados, um skip por UIKit ausente no macOS, zero falhas |
| Breakdown host | Observability 59; consumidor conjunto 2; Journey 26; Auth 7, dos quais um skip |
| Build cross iOS Simulator, deployment 15, SDK real | Todos os targets/test bundles compilaram e linkaram, incluindo Firebase 11.15.0 e USPJourneyKit |
| API pública Auth | Cinco headers sem alteração de declarações |
| Crypto Auth ASan/UBSan | Quatro casos, dois vetores conhecidos, integridade e quatro threads aprovados |
| Manifest e documentação | plutil, links locais e git diff --check aprovados |

Comandos (na cópia de trabalho; caches/scratch fora do repo):

```sh
CLANG_MODULE_CACHE_PATH=/tmp/uspjourney-modulecache SWIFTPM_MODULECACHE_OVERRIDE=/tmp/uspjourney-modulecache swift test --disable-sandbox --cache-path /tmp/uspjourney-cache --scratch-path /tmp/uspjourney-build
CLANG_MODULE_CACHE_PATH=/tmp/uspjourney-ios-modulecache SWIFTPM_MODULECACHE_OVERRIDE=/tmp/uspjourney-ios-modulecache swift build --disable-sandbox --cache-path /tmp/uspjourney-cache --scratch-path /tmp/uspjourney-ios --build-tests --triple arm64-apple-ios15.0-simulator --sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)"
python3 scripts/check-auth-public-api.py
sh scripts/check-auth-crypto.sh
plutil -lint Sources/USPJourneyKit/PrivacyInfo.xcprivacy
git diff --check
```

Logs locais: `/tmp/uspjourney-final-tests.log`,
`/tmp/uspjourney-ios15-build.log`. A primeira execução dirigida, antes de adicionar
o caso reentrante, passou 25 testes; a suíte final contém 26 do novo módulo.

## Impedimentos e limites

Na preparação dos commits em 29/10/2026, a suíte host foi executada novamente no
repositório original: 94 testes, um skip por UIKit ausente e zero falhas.
Baseline de API Auth, crypto ASan/UBSan, manifest e `git diff --check` também
passaram. Log dessa execução: `/tmp/uspjourney-commit-tests.log`.
O build iOS abaixo permanece evidência da validação anterior; não foi reexecutado
durante a preparação dos commits.

- Compilação direcionada a iOS 14 foi recusada pelo Xcode instalado: deployment
  suportado pelo SDK começa em 15. O mínimo declarado não foi elevado para
  contornar essa limitação. Build/runtime iOS 14 permanece não certificado.
- CoreSimulatorService indisponível à sessão; não houve execução dos bundles
  iOS. O build cross compila/linka e não comprova runtime Auth/UIKit/Firebase.
- Avisos de linker XCTest construído para iOS 17 ao linkar bundles de teste com
  destino 15 são do SDK. Nenhum erro do módulo foi ignorado.
- Primeiro resolve falhou no download `dl.google.com` por DNS. Os artefatos reais
  já presentes no cache SwiftPM foram copiados para cache temporário e usados
  pelo SwiftPM. Não se criaram stubs, SDK falso ou mirrors persistentes.
- Políticas desativadas por padrão; ingestão Analytics e não fatal real do
  Crashlytics não testados. Mudanças de política podem produzir fluxo parcial.
- Allowlists/regex bloqueiam valores livres usuais, mas exigem revisão semântica
  humana para não cadastrar categorias pessoais como valores aparentemente válidos.
- Nenhuma política de cache/próxima refeição, janela de abandono ou semântica
  específica das jornadas Cardápio foi aprovada pelo código desta biblioteca.

## Compatibilidade e publicação

Firebase 11.15..<12 preserva iOS 14; Analytics usa produto sem suporte a Ad ID.
O pacote passa a resolver grafo Firebase mesmo quando o consumidor seleciona só
Auth/Observability, embora esses targets não vinculem Firebase. Lockfile desta
validação não substitui o do consumidor.

**Bloqueio conhecido de adoção:** Cardápio exige Firebase >=12.12.1 e não resolve
com esta faixa. Decidir explicitamente plataforma/linha Firebase da distribuição
antes de adotar a nova release; não há downgrade ou mudança de app nesta entrega.
A API é aditiva, mas o impacto no grafo exige revisão de release pelos mantenedores.

Antes da adoção: resolver esse conflito, validar consumidores
e ambiente mínimo suportado, aprovar semântica do contrato/matrizes, publicar
versão do pacote e instrumentar piloto em tarefas próprias. Recebimento real
Firebase permanece no aceite STI-15. Ver [arquitetura](../../architecture/journey-kit.md)
e [integração](../../journeys/integration.md).
