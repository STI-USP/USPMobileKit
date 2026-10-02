# Revisão do domínio de autenticação

2026-10-02. Preservar a composição existente e R02, sem alterar consumidores,
endpoints, persistência, headers públicos ou implementar outro protocolo.

1. Remover USPMobileCredential: somente encapsula wsuserid, sem estado próprio.
   Backend recebe o identificador operacional do perfil tipado.
2. Separar configuração interna de aplicação (baseURL/appKey/header) da config
   legada OAuth1; manter API antiga como adapter de composição.
3. Permitir resultado de identidade construído pelo modelo público USPAuthUser,
   com USPAuthVinculo, sem exigir payload HTTP/OAuth. JSON continua somente adapter
   de resolução/persistência/compatibilidade.
4. Testar autenticação completa por fake independente de OAuth1 e duas instâncias
   com configuração própria. Executar R02/fixtures/API checker/iOS/host/cross/C.
5. Atualizar arquitetura, classificação dos campos, migração e evidência.

Risco: currentWSUserId distingue campo ausente/NSNull de string vazia enquanto
USPAuthUser normaliza para string vazia. Preservar essa diferença exclusivamente
no adapter legado, sem duplicar identificador no domínio.

## Resultado

Etapas1–5 executadas. Modelo/fake e compatibilidade protegidos por57testes iOS
(24baseline+33arquitetura), fixtures Swift/ObjC, checker5, host/cross e regressão C.
Sem alteração de cliente, OAuth2, endpoint, keys, Keychain ou API pública.
Walkthrough e validação registram limites e dependências legadas restantes.
