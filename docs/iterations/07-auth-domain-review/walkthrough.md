# Revisão do domínio implementada

2026-10-02, mesma branch feature/auth-architecture-modernization; alterações
anteriores de composição foram preservadas, sem commits nesta etapa.

## Resultado

Quatro conceitos distintos: configuração do aplicativo; configuração/estado
privados do provider; perfil público USPAuthUser/USPAuthVinculo; wsuserid como
identificador operacional incluído nesse perfil. Não há credencial mobile
separada derivada da mesma string.

Removido USPMobileCredential de USPAuthSession.h/.m. Backend/coordinator agora
usam user.wsuserid com métodos internos register/check/invalidateUserIdentifier.
Nenhum endpoint/payload mudou: campo wire token continua contendo wsuserid.
Estado backend independente retido: app/push e flag local isRegistered.

USPIdentity ganhou initWithUser: interno para resultado tipado. O mapper JSON
existente é Identity Resolution OAuth1; metadata ainda preserva userData e schema
legado. Serialização tipada inclui todos os campos públicos e vínculos, sem novo
formato. CurrentWSUserId preserva nullable legado mediante adapter, sem armazenar
cópia paralela do identificador.

USPApplicationConfiguration.h/.m internos separam endpoint/appKey/header mobile
de consumerKey/consumerSecret. USPAuthServiceInternal permite aplicar configuração
por instância sem USPAuthConfig/provider1. Adapter setConfig preserva a precedência
config.appKey sobre appKey para requests; propriedades públicas continuam iguais.
Environment é resolvido pelo factory legado para baseURL; sem enum novo especulativo.

## Testes e compatibilidade

FakeAuthenticationProvider não conhece OAuth1 e fornece identidade tipada; teste
novo inicia sessão vazia, recebe todos os campos básicos/vínculo/wsuserid pela
fachada e registra o app com fake transporte. Duas configurações são exercitadas;
nenhum provider OAuth1 é instanciado sequer no setup desse teste. Segundo teste
prova round-trip tipado pelo store legado sem tokens. Testes existentes foram
adaptados à remoção do wrapper interno; R02/fixtures/headers públicos intactos.

55→57 testes iOS, zero falhas/skips; 24baseline preservados. Swift/ObjC
compilaram/linkaram/executaram. Host66pass+1skip, build host/cross iOS aprovados,
checker5 e regressão C ASan/UBSan aprovados. Detalhes:
[validation](../../modernization/validation.md#revisão-do-domínio--2026-10-02).

## Limites

Sem novos atributos deprecation/breaking público. Sem mudança consumer/endpoints/
keys/OAuth1 wire/Keychain/algoritmo. Configuração pública/default store/provider
continuam legados OAuth1; núcleo neutro desacoplado não significa que o package
inteiro esteja livre do protocolo. Sem login real, device/runtime iOS14 ou prova
remota de validade/autorização. Nenhum contrato futuro foi modelado.

A documentação corrente é [architecture](../../authentication/architecture.md)
e [consumer-migration](../../authentication/consumer-migration.md).
