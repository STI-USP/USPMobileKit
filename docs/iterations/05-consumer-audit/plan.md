# R01 — auditoria do consumidor Cardápio USP

## Objetivo e baseline

Inventariar contratos efetivamente usados pelo consumidor real `../Cardapio USP`, sem modificar código, dependências ou testes de nenhum projeto. Ler os sete documentos de modernização, incluindo a validação de R02, antes da análise. R02 permanece intacto.

## Abordagem e escopo

1. Identificar resolução SPM, targets e callers Swift/Objective-C.
2. Seguir adapter, navegação, perfil, saldo, Pix, avisos, push e logout.
3. Seguir `wsuserid` até requests, caches e diagnóstico; separar propriedade pública de chave persistida e código ativo de comentários/testes.
4. Documentar evidências com arquivo/linha, contratos a preservar, riscos, piloto e limites de R01.
5. Validar referências e ausência de alterações não documentais; registrar progresso real no roadmap.

A auditoria é estática, sem login, chamadas de backend, builds ou resolução de pacotes. Não copiar valores de secrets, credenciais ou PII. Diretórios de resultados/checkouts gerados não representam callers do app. Não extrapolar achados para outros consumidores. R01 só fecha quando houver inventário dos consumidores relevantes confirmado pelas equipes.

## Critério de conclusão desta etapa

Inventário reproduzível do Cardápio, destinos da credencial mobile identificados, classificação fundamentada e lacunas explícitas. Esta etapa não conclui automaticamente R01 nem autoriza R04–R08.
