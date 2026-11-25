# Conformidade v1 — iOS e Android

O arquivo [contract-v1.json](../../Tests/USPJourneyKitTests/Fixtures/contract-v1.json)
é fixture de contrato independente da API Swift. `<attempt>` é substituído por UUID
aleatório normalizado para comparação. `JourneyConformanceTests` executa ações
e compara o envelope completo, sem depender de Firebase ou backend.

| Ação fixture | Semântica |
| --- | --- |
| start | UUID novo, tipo da definição, `versao_contrato=1` |
| advance | Marco `apresentar` |
| complete | Concluir em `apresentar`, `resultado=sucesso` |
| fail | Falhar em `obter`, categoria `tempo_esgotado` |
| cancel | Cancelar explicitamente na etapa corrente |
| forget | Remover contexto, sem evento |

Exigir os mesmos resultados na implementação Android, incluindo envelope,
valores e ausência de terminal duplicado/tardio. Fixture cobre sucesso, etapa,
falha, cancelamento e perda de contexto; não certifica sozinha a implementação.

Casos adicionais exercitados nas suítes Swift e obrigatórios para paridade:
parâmetros proibidos/desconhecidos, valores não declarados, grafo inválido,
finalização inválida sem consumir tentativa, tentativas simultâneas, 50 chamadas
concorrentes de terminal, retry com novo ID, handles estrangeiros, falha do
registrador, gates dinâmicos e independentes, Firebase não configurado, isolamento
de contexto diagnóstico, consentimento revogado e ausência de abandono emitido.

Estas são definições técnicas desta entrega; revisar enums/serialização antes
da adoção conjunta. Não confundir sucesso destes testes com recebimento Firebase,
conformidade de uma jornada de app ou validação funcional em dispositivo.
