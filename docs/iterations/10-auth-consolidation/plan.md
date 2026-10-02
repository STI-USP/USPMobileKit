# Consolidação da modernização

2026-10-02. Responsável homologou OAuth1/Cardápio no iPhone e confirmou perfil,
vínculos PROD e restauração; DEV responde vinculo vazio. Consolidar branch sem
commit, mudança de API, nova arquitetura/protocolo, cliente, endpoints ou storage.

Remover instrumentação temporária e helpers de impressão; preservar testes
comportamentais do handoff/correlação, erro pré-callback, cancel/logout/late results,
perfil, vínculos e shape legado. Excluir somente testes exclusivos do diagnóstico.
Revisar README, arquitetura canônica, guias operacional/novo consumidor, inventário
Cardápio e roadmap atual; identificar baseline/histórico e limites de homologação.

Validar host build/test, cross iOS, suite Auth real iOS/R02/fake/fixtures/API,
C ASan/UBSan e whitespace. Nenhum gate baseado só em host. Não prometer Keychain,
refresh/revogação/SSO, todos consumidores ou execução runtime14. OAuth2 ausente.
