# Registro da sessão mobile

Garantir que `ensureLoggedIn` só retorne sucesso após o registro mobile da identidade atual, inclusive ao reutilizar credenciais em cache. Preservar identidade em falhas para permitir retry sem novo login e manter notificações independentes do resultado de autenticação.

Alterar o coordinator e testes determinísticos do transporte. Validar falha seguida de retry, sessão em cache, cancelamento no logout, chegada tardia e retry do token de notificação, API pública e harness iOS. Não alterar o contrato do backend nem inferir sucesso sem resposta HTTP aceita.
