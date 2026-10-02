# Diagnóstico dos vínculos do perfil

> Registro histórico da investigação. Encerrada por homologação do responsável
> em 2026-10-02: OAuth1 real completou; DEV tinha vínculos vazios, PROD vínculos
> esperados, perfil/metadata/restauração preservados. Diagnóstico temporário foi
> removido na [consolidação10](../10-auth-consolidation/walkthrough.md).
> Pendências mencionadas abaixo descrevem a execução anterior, não o estado atual.


2026-10-02. OAuth1 homologado pelo responsável no iPhone: tokens, perfil,
registro e completion bem-sucedidos; wsuserid aceito nas requisições do Cardápio.
Perfil exibe nome/foto/número, mas não vínculos. Não alterar OAuth/browser/HTTP,
cliente ou normalizar payload sem evidência.

Comparar a0e523e com parsing/modelos/identidade/store/fachada atuais e leitura
ProfileViewModel do consumidor. Instrumentar somente DEBUG: presença/tipos e
contagens singular/plural, modelo, metadata, persistência e restauração.
Adicionar proteção sintética de shape original; coletar trace real antes de
identificar causa/correção e fixture exata. R02 intacto. Gate: identificar primeira
perda e teste reproduzível com shape real sanitizado; não inferir números reais.
