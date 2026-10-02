# Composição interna de autenticação — R04–R09 / R11–R12

## Premissa e objetivo

O responsável controla SDK e consumidores: compatibilidade temporária é útil, mas keys/JSON/par OAuth/WK não definem o domínio futuro. R01 parcial não bloqueia esta implementação autorizada. Cardápio permanece somente referência documental. OAuth2 e Keychain não serão implementados.

Baseline: oito documentos de modernização lidos; a0e523e, tree limpo. Em 2026-10-01 foram reexecutados 24 testes Auth iOS27 (zero falhas/skips), fixtures Swift/ObjC inclusas; checker cinco headers inalterados. Bundle /tmp/uspauth-modern-baseline.xcresult. SDK27 exige override15 de build, package permanece iOS14.

## Blocos revisáveis

1. Transporte arbitrário cancelável, HTTPClient consumidor e fake sem internet.
2. Modelo interno identity/mobile credential/session e store contratual com adapter defaults legado.
3. Browser WK por operação/instância, clock/nonce controlados e provider1 responsável por handshake/perfil/par persistível.
4. Coordinator neutro e cliente mobile independente; fachada/adapters preservam API e baseline R02.
5. Hardening isolado S04 (digest/input/sanitizers), depois S02/S03 (callback correlacionado, cancelamento, completion única, geração/resultado tardio).
6. Contratos internos e de fluxo com fake provider/browser/transporte; harness iOS real + host/cross-build/checker.
7. Arquitetura implementada, guia dos consumidores, progresso/gates e limitações.

## Gates e riscos

R02 não será editado. Endpoints, encoding, nonce default/timestamp, payload e headers válidos continuam equivalentes. Cache parcial, perfil anterior ao registro, erro de registro sem limpar sessão e logout local permanecem. Segurança muda conscientemente callback inválido/duplicado e resultados após cancel/logout. Testes neutros devem aceitar provider sem par OAuth; wire vectors protegem convenções legadas. Callback real do backend ainda precisa homologação; não afirmar login remoto por fake. iOS14/toolchain e R03 continuam limites. Não criar protocolo público, novos products, framework ou DI obrigatório.

## Encerramento da implementação

Blocos1–7 implementados e descritos no walkthrough. R02 intacto; validação final
55 testes Auth iOS passaram (24baseline+31arquitetura), host66passed+1skip,
fixtures Swift/ObjC executadas, API checker5, cross-build e ASan/UBSan aprovados.
R04–R09 têm implementação/evidência local; callback/UI/servidor piloto ainda
precisam homologação. R10/R13–R16 e OAuth2 não concluídos por esta extração.
Sem alteração Cardápio/Package/headers públicos/deployment target; nenhuma commit.
