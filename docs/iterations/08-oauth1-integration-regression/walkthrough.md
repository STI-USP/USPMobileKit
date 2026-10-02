# Investigação de regressão OAuth1 no Cardápio

> Registro histórico da investigação. Encerrada por homologação do responsável
> em 2026-10-02: OAuth1 real completou; DEV tinha vínculos vazios, PROD vínculos
> esperados, perfil/metadata/restauração preservados. Diagnóstico temporário foi
> removido na [consolidação10](../10-auth-consolidation/walkthrough.md).
> Pendências mencionadas abaixo descrevem a execução anterior, não o estado atual.


2026-10-02. **Causa identificada e patch validado localmente; homologação pós-patch pendente.** O responsável reproduziu
no iPhone físico e fará nova execução Debug. Não foi alterado o Cardápio nem
relaxada a validação. O trace real recebido e a reprodução antes/depois comprovam a falha do browser; conclusão operacional depende da nova tentativa no iPhone.

## Comparação baseline / composição atual

| Transição | a0e523e | Atual / hipótese a verificar |
|---|---|---|
| Tokens/signing | URLSession direta, clock/nonce concretos | Transporte injetado; endpoints/métodos/encoding herdados. Vetores não comprovam request real |
| Authorization | callback configurado literal localhost | Literal permanece; formato real do redirect ainda não capturado |
| Navegação/callback | substring oauth_verifier no webView.URL | navigationAction.request.URL + matcher; destino localhost/fragment/query/token/verifier validados |
| Correlação | Token/verifier presentes; não exige igualdade com request token | Igualdade obrigatória e query sem duplicatas: premissa ainda não homologada; exchange usa request token, enquanto baseline usa token do callback |
| UI | viewDidAppear inicia usando singleton | Instância/ready uma vez, browser proprietário, cleanup de observer/delegate |
| Dismiss → perfil | Service dismiss sempre, depois fetch | Provider espera finish do browser antes de fetch; registrar início e conclusão do dismiss |
| Perfil/registro | Par e perfil persistidos antes do registro; erro não apaga cache | Mesma semântica; provider entrega identidade ao coordinator, registro mobile separado |
| Cancel/logout | Não cancela requests/late writes | Generation, handles e completion única podem descartar callbacks; registrar motivo |
| Consumer | Wrapper transforma resultado em bool/consulta currentUser | Caller atual ignora NSError; não foi modificado para contornar falha |

Confirmação do consumidor: projeto irmão contém referência local ../USPMobileKit;
AuthenticationService.swift chama shared().ensureLoggedIn e recebe user/error.
Valores de configuração/credenciais não foram documentados.

## Diagnóstico temporário

USPAuthDiagnostics.h interno emite somente sob DEBUG. Payload é JSON em uma linha
com prefixo [AuthDebug]. Helpers de estrutura não imprimem raw URL/Authorization/
body/NSError.localizedDescription. Status/code/presença/correlação são números e
booleans; nomes OAuth allowlisted, outros query names apenas contagem. Scheme,
host USP/localhost e paths conhecidos são allowlisted; componente desconhecido é
<other>, evitando PII/credencial eventualmente inserida no path/host.

Trace cobre ensure/cache, request token/request structure/response/parse,
authorization/browser ready/presentation, URL de action versus URL atual WK,
callback candidato/razão/correlação/verifier, access exchange, browser finish/dismiss,
perfil/status/Content-Type/JSON/model/wsuserid presente, provider/coordinator/service
completions, registro/status e descartes/cancelamento. Não registrar valores reais.

O helper callbackRejectionReason reflete a política atual; sua extração não altera
critérios de validação. Instrumentação não constitui correção do backend callback.
Teste sanitização sintético exige ausência de marcador privado em URL, path, query,
header/body e erro; caso browser error sem URL protege a instrumentação contra
modificação do comportamento anterior.

## Próximo dado obrigatório e gate

Responsável deve recompilar Cardápio Debug no iPhone, repetir login e fornecer
somente linhas [AuthDebug]. Só então identificar última transição válida e primeira
falha. Se componente desconhecido necessário, coletar estrutura pública adicional
sem query values/PII. Criar fixture sintética da sequência real e demonstrar falha
antes da correção mínima. Após patch, suite + novo login real com retorno tipado.
Não chamar investigação concluída por sucesso de XCTest.

## Validação da instrumentação

59testes Auth iOS passaram, zero fail/skip/warnings; os24baseline, fake e fixtures
continuam executados. Novo teste de sanitização e caso browser error sem URL
passaram. Host66pass+1skip; cross Debug/test e Release compilados/linkados; checker5,
ASan/UBSan e whitespace aprovados. Nenhum prefixo AuthDebug nos objetos Release.
Variações de token/callback nos testes são sintéticas, não evidência do backend USP.
Aguardando trace Debug do iPhone: não há patch causal ou teste da regressão real.


## Trace real recebido: causa e correção

Responsável forneceu trace DEBUG do iPhone físico em 2026-10-02. Request token
HTTP200, body form presente, token/secret presentes. Authorization abriu no ambiente
dev USP; duas navegações authorize e callback `http://localhost/`, sem fragmento,
query names oauth_callback/oauth_token/oauth_verifier. Action URL e webView.URL
coincidem; token_correlated=true, verifier não vazio. Nenhum valor real registrado.

**Última transição correta:** callback validado/verifier extraído e access exchange
iniciado POST. **Primeira transição incorreta:** browser recebe erro WK102 depois
de consumir callback e o encaminha como cancelamento ao provider. Provider.abort
incrementa geração e cancela o task access: resultado -999/cancelled, sem body.
Perfil/registro não começaram. Completion chegou ao consumer com erro102 e user
nil: não houve sucesso perdido nem falta de completion. Discard de resultado
access tardio é consequência do cancelamento incorreto, não causa primária.

Em USPWKAuthBrowser.fail, callback=nil (já entregue) fazia fallback para cancellation.
Apenas erro -999/finished eram ignorados. Baseline não implementava didFail handlers;
não cancelava exchange em consequência desse erro. Portanto regressão introduzida
pela extração/browser error propagation da modernização, não por validação/token
mismatch, assinatura ou configuração. O domínio do erro original não foi capturado;
a fixture usa WebKitErrorDomain sintético com código observado102. A correção
não depende desse domínio ou de ignorar um código globalmente.

Patch mínimo em USPAuthBrowser.m: flag callbackConsumed marcada **antes** de
invocar decisionHandler(Cancel); erros de navegação posteriores são ignorados pelo
browser. Provider continua responsável pelo exchange/erro/transporte. finished
não é antecipado: cancel explícito/logout ainda podem interromper autenticação.
Erros antes do callback, inclusive102, continuam propagados. Validação de destino/
correlação, completion única/generations, singleton independence, endpoints e
wire não foram relaxados/alterados. Diagnostics retidos temporariamente para gate.

### Regressão executável

`testUSPCallbackPolicyFailureAfterHandoffDoesNotCancelAccessExchangeAndConsumerCompletion`
reproduz estrutura real com valores sintéticos: localhost callback com três query
names → access iniciado → erro102. Usa browser WK real/RecordingWebView, transporte
fake, provider1/coordinator/fachada reais e verifica usuário/wsuserid após perfil/
registro. Cobre didFailNavigation e didFailProvisionalNavigation.

Antes do patch: **falhou**, reproduzindo task cancelado, completion precoce e erro102,
`/tmp/uspauth-wk102-reproduced.xcresult` (1test/6asserções reportadas). Primeira
invocação only-testing usou target incorreto e não executou; corrigida para
USPAuthSessionHarness antes da reprodução válida.

Depois: **62 Auth iOS passaram**,0fail/skip/warnings,108,1s,
`/tmp/uspauth-wk102-fixed.xcresult`:59existentes+3testes de regressão/controle.
Controles cobrem erro reentrante dentro do decisionHandler, cancel explícito depois
do handoff e erro102 antes do callback. R02/fake/fixtures/headers intactos.

### Gate ainda aberto

Solicitada nova execução Debug no Cardápio/iPhone: validar access response, perfil,
wsuserid, registro, completion sem erro e navegação do app. Até receber essa evidência,
não declarar OAuth1 funcionalmente equivalente ao baseline em produção. Não houve
alteração do Cardápio nem acesso/registro de credenciais reais pelo agente.

## Ownership e controles adicionais

Browser extrai/consome candidato uma vez e cancela sua navegação por policyCancel.
Provider decide validade/correlação; candidato inválido continua gerando erro101.
Flag de handoff precede decisionHandler, protegendo contra falha WK reentrante,
mas não torna o browser finished nem desabilita cancel explícito. Não é regra
'ignorar erro102': qualquer erro antes do handoff ainda pode falhar a operação.
O trace não prova conexão de rede a localhost: policyCancel já impede a navegação,
mas WK pode reportar falha dessa navegação. Esta notificação não pertence ao
resultado de uma troca HTTP já sob controle do provider.

Controle adicional com WK/provider reais cobre mismatch de token, verifier vazio,
destino estranho e erro102 posterior: completion erro101 uma vez, sem access task.
Suíte final63Auth iOS passou,0fail/skip/warnings; nenhuma mudança adicional em
produção foi necessária para esse controle. Gate continua sendo novo login real.


## Homologação real pós-patch — 2026-10-02

Responsável confirmou execução bem-sucedida no Cardápio/iPhone: request token200,
callback validado/token correlacionado, access200, profile200/application-json,
dictionary válido, USPAuthUser/wsuserid presentes, registro200, completion user
presente e wsuserid funcional nas demais requisições. Gate do fluxo OAuth1/browser
homologado neste cenário. Não prova todos ambientes/versões/cancelamentos.
Problema de exibição dos vínculos tratado separadamente na [iteração09](../09-profile-relationships/walkthrough.md).
