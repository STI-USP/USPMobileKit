# Regressão real OAuth1 / Cardápio

> Registro histórico da investigação. Encerrada por homologação do responsável
> em 2026-10-02: OAuth1 real completou; DEV tinha vínculos vazios, PROD vínculos
> esperados, perfil/metadata/restauração preservados. Diagnóstico temporário foi
> removido na [consolidação10](../10-auth-consolidation/walkthrough.md).
> Pendências mencionadas abaixo descrevem a execução anterior, não o estado atual.


2026-10-02. Não modificar consumidor ou relaxar validação sem evidência.
Comparar baseline a0e523e, instrumentar DEBUG com estrutura/status/booleans,
sem URLs completas, valores de query, secrets/tokens/PII/Authorization/body.
Observar login real com o responsável, identificar primeira transição falha,
reproduzir sequência sanitizada em teste que falha antes de patch mínimo.
Executar suíte iOS/R02/fake/fixtures/API/cross/C e homologar novamente no app.
Gate obrigatório: completion real com perfil/wsuserid. Testes não substituem gate.
Config/credenciais/login são operados pelo responsável, não compartilhados.

## Progresso após trace real

Causa comprovada: propagação de erro WK102 depois de consumir callback cancela
access exchange. Regressão do browser modernizado, não erro de correlação/destino.
Fixture da sequência falhou antes do patch; patch mínimo flag callbackConsumed
preserva troca HTTP e cancel explícito.62Auth iOS + host/cross/API/C passam.
**Gate em aberto:** responsável recompilar e repetir login no iPhone, confirmar
perfil/wsuserid/registro/completion/navegação. Não executar fase posterior ainda.
