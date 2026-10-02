# Composição interna de autenticação: implementação

## Objetivo e estado anterior

A fachada concentrava OAuth1/perfil/registro/push/cache, transporte concreto e
UI que voltava ao singleton. Auditoria e R02 documentaram comportamento público;
o Cardápio usa wsuserid e acessa keys internas. O responsável autorizou migrar
clientes posteriormente: compatibilidade não perpetua vazamentos arquiteturais.

## Estado resultante

USPAuthService delega a coordinator; provider OAuth1 controla handshake/credencial
+ perfil; browser WK é adapter da operação; mobile client recebe credencial opaca;
transporte e store são contratos privados substituíveis. Composição default
continua OAuth1. Composição interna aceita provider sintético sem OAuth1 nos
mesmos coordinator/fachada. Nenhum código OAuth2/Keychain/consumer foi criado.

Fonte arquitetural atual: [architecture](../../authentication/architecture.md).
Migração de apps: [consumer-migration](../../authentication/consumer-migration.md).

## Blocos revisáveis

1. **R04:** USPHTTPTransport/USPURLSessionTransport e HTTPClient; token/perfil/mobile
   usam execução arbitrária, status/bytes/error/handle. URLSession e wire legados.
2. **R05:** USPAuthSessionStoring, session/identity/mobile credential e adapter
   USPAuthSessionStore; keys UserDefaults antigas intactas, não Keychain.
3. **R06/R07:** browser, UI injetada sem sharedService, clock/nonce e signer
   determinísticos privados; sem alterar normalização/encoding/HMAC da rede.
4. **R08/R09:** USPOAuth1AuthenticationProvider, USPAuthenticationCoordinator,
   USPMobileBackendClient e fachada/USPAuthServiceInternal para composição.
5. **R12/S04 isolável:** hmac.c/.h, sha1.c/.h, const input no signer,
   Tests/Security/HMACInputTests.c e scripts/check-auth-crypto.sh.
6. **R11/S02/S03:** callback correlacionado, geração/cancelamento e completion única;
   mudanças comportamentais declaradas, sem revogação remota no logout.
7. **Testes/docs:** suíte ObjC privada adicional no harness iOS, plano, arquitetura,
   guia e atualização incremental do roadmap/validação. R02 não foi editado.

Os arquivos listados permitem revisão separada da correção C e das novas políticas
comportamentais; nenhuma troca de algoritmo/endpoints/deployment target/dependência.
Não foram feitos commits nesta tarefa.

## Decisões e compatibilidade

- Provider interno representa autenticar para identidade, reconhecer cache,
  cancelar/limpar memória. Refresh/expiration obrigatórios não correspondem ao backend.
- wsuserid é credencial mobile, distinta da credencial privada de autenticação.
- Store atual traduz provider1 para schema antigo; envelope de outro provider
  pertence a R16, implementando o mesmo protocolo de storage.
- Headers públicos intactos e fixtures Swift/ObjC executadas. Propriedades OAuth,
  config consumer secret e etapa WK continuam adapters baratos de provider1.
- Status HTTP ignorado em tokens/perfil, cache depois de registro falho e
  usuário sem par OAuth continuam testes de comportamento legado conhecido.
- Mudanças intencionais: callback inválido é rejeitado; cancel/logout descartam
  writes/resultados tardios e concluem operações em voo uma vez com cancelamento.
  Sem API deprecated nova ou remoção; incompatibilidade comportamental documentada.

## Validação

Antes: 24 testes Auth iOS passaram. Depois: **55 testes Auth iOS passaram**,
zero falhas/skips: baseline24 +31 arquitetura. Swift/ObjC compilaram/linkaram/
executaram. Host66passed+1skip; cross-build iOS15 passou; checker5 intactos.
C: quatro casos auditados reproduzidos antes (mutação em três), depois mesmos
HMAC digests com inputs intactos; dois vetores conhecidos, execução concorrente,
ASan/UBSan aprovados. Detalhes/comandos/limites em
[validation](../../modernization/validation.md#composição-interna-e-hardening--2026-10-01).

Uma fixture adicional inicialmente falhou por não aguardar dispatch assíncrono
de tokens. A fixture foi corrigida; não se alterou produção para mascarar falha.
Falhas iniciais de compilação/caches foram corrigidas e a validação final passou.

## Limitações e próximo passo

Sem login real, app piloto, backend homologado, device/iOS14 antigo. Validar
callback e UI modal/swipe reais antes de release. S01 e hardening status/payload,
logs/PII/nonce/schema permanecem; R01 não representa todos os consumidores.
Fases0/3/4 não encerradas por interfaces/testes locais. Única próxima tarefa:
**R03, especificar contrato backend OAuth2/identidade/wsuserid/coexistência**,
sem implementação antecipada.
