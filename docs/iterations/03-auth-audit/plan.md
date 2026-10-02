# Auditoria e roadmap do USPAuthKit

Data: 2026-10-01. Baseline: `11d9582`.

## Objetivo e escopo

Auditar o product USPAuthKit dentro de USPMobileKit, estabelecer o contrato exportado e propor evolução incremental compatível. Entregas exclusivamente documentais em `docs/modernization`; OAuth 2, alterações funcionais, endpoints, criptografia e refatoração ficam fora desta execução.

## Abordagem

1. Ler manifest, headers exportados, implementação ObjC/C, testes e documentação anterior.
2. Distinguir uso comprovado local, contrato exportado e uso externo desconhecido.
3. Mapear fluxo, persistência, HTTP, UI, acoplamento e riscos com evidência por arquivo/método.
4. Executar build/testes/manifest e tentar validação iOS/Xcode; registrar limitações sem mudar deployment target.
5. Documentar arquitetura atual, inventário público, mapa OAuth 1, segurança, arquitetura proposta e roadmap com gates.
6. Verificar referências documentais e diff; produzir walkthrough final.

## Riscos e decisões

O macOS exclui a implementação de UIKit: sucesso no host não comprova funcionamento iOS. Consumidores e contrato futuro do backend não estão neste workspace. O inventário cobre a API disponível, sem alegar uso por todos os apps. A compatibilidade de propriedades OAuth mutáveis e WKWebView exige caminho legado separado; não será simulada por tokens OAuth 2. Recomendações são propostas, não decisões arquiteturais já implementadas.

## Validação e conclusão

Executar `swift build`, `swift test`, `swift package dump-package`, tentativas via `xcodebuild`, compilação cruzada iOS e lint dos manifests. Conferir todos os headers públicos contra o inventário; todos os achados contra prioridades/fases. Concluir com seis documentos completos, walkthrough e limitações explícitas. O gate de refatoração futura depende de testes iOS de serviço/UI que esta auditoria não cria.
