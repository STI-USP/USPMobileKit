# Iteração 02.1 — Privacy Manifests: walkthrough

## Objetivo

Distribuir declarações de privacidade específicas para `USPAuthKit` e
`USPObservabilityKit`, cobrindo Required Reason APIs e os dados que cada product
efetivamente coleta ou habilita o app a coletar, sem alterar comportamento ou API
pública.

## Fontes de verdade

A auditoria foi confrontada em 23 de setembro de 2026 com a documentação vigente
da Apple:

- [Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files);
- [Required Reason API categories and reasons](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype);
- [Collected data types](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacycollecteddatatypes/nsprivacycollecteddatatype);
- [Collection purposes](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacycollecteddatatypes/nsprivacycollecteddatatypepurposes);
- [App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/).

Não havia Privacy Manifest ou reason code local anterior com o qual pudesse haver
divergência. A Apple lista atualmente cinco categorias de Required Reason APIs:
timestamps de arquivo, boot time, espaço em disco, teclados ativos e UserDefaults.

## Estado anterior

O package tinha dois products SPM independentes, iOS 14+, sem dependências
externas. Ambos usavam defaults, mas nenhum target continha
`PrivacyInfo.xcprivacy` e o `Package.swift` não declarava resources.

O código funcional já continha proteções de observabilidade — allowlist de hosts,
IDs aleatórios e preservação de headers — e elas foram mantidas sem alterações.

## Auditoria encontrada

### Required Reason APIs

| Categoria | Target | Uso real | Reason |
|---|---|---|---|
| `NSPrivacyAccessedAPICategoryUserDefaults` | `USPAuthKit` | Sessão OAuth, token/plataforma de push, estado de registro e cache JSON do usuário em defaults privados do app | `CA92.1` |
| `NSPrivacyAccessedAPICategoryUserDefaults` | `USPObservabilityKit` | UUID aleatório da instalação em defaults privados do app | `CA92.1` |

Não foram encontrados usos de timestamps de arquivos, `FileManager`/atributos de
arquivo, `stat`/`fstat`/`lstat`, system uptime, `mach_absolute_time`, espaço em
disco ou teclados ativos.

O `USPAuthKit` usa `standardUserDefaults` por padrão. Seu inicializador permite
injetar um objeto de defaults para testes/isolamento, mas não cria suite de App
Group, não lê domínio global e não funciona como wrapper genérico de defaults.
Portanto, `CA92.1` representa o comportamento próprio do target; `C56D.1` não
representaria o uso dos dados pelo Auth.

O `USPObservabilityKit` usa `UserDefaults.standard` por padrão. Não há App Group,
leitura de outro app, defaults globais ou Keychain para preservar o Installation
ID após reinstalação.

### USPAuthKit

Valores persistidos:

- `oauthToken` e `oauthTokenSecret`;
- `notificationToken` e `notificationPlatform`;
- `isRegistered`;
- `userData` serializado como JSON.

Dados enviados pelo próprio target:

- parâmetros OAuth e credenciais necessárias ao fluxo de autenticação;
- `wsuserid`, usado nos endpoints de registro, invalidação e consulta;
- token de push fornecido pelo app, registrado no mesmo payload do `wsuserid`;
- chaves técnicas do app e da plataforma de notificação.

Declarações de coleta:

| Tipo Apple | Linked | Tracking | Purpose | Evidência |
|---|---:|---:|---|---|
| `NSPrivacyCollectedDataTypeUserID` | `true` | `false` | `AppFunctionality` | IDs OAuth/`wsuserid` usados para autenticação e operações da conta |
| `NSPrivacyCollectedDataTypeDeviceID` | `true` | `false` | `AppFunctionality` | token de push único do dispositivo registrado junto ao `wsuserid` |

O endpoint de usuário devolve nome, e-mails, telefone e vínculos. O target armazena
essa resposta localmente e a expõe ao app, mas o código auditado não retransmite
esses campos. Por isso, eles não foram adicionados como collected data types do
SDK. Se o app retransmitir esses valores ou o backend mudar o payload/uso, o
consumidor precisa atualizar sua própria declaração.

### USPObservabilityKit

| Valor | Origem | Decisão |
|---|---|---|
| `USP-App-Platform` | constante `ios` | contexto técnico em `OtherDiagnosticData` |
| `USP-App-Version` | `CFBundleShortVersionString` | contexto técnico em `OtherDiagnosticData` |
| `USP-App-Build` | `CFBundleVersion` | contexto técnico em `OtherDiagnosticData` |
| `USP-OS-Version` | `ProcessInfo.operatingSystemVersion` | contexto técnico em `OtherDiagnosticData`; não é boot time |
| `USP-Device-Model` | `sysctlbyname("hw.machine")` | classe de hardware em `OtherDiagnosticData`; não identifica unidade física |
| `USP-Installation-Id` | UUID aleatório persistido | `DeviceID` |
| `traceparent`/`trace_id` | aleatório por operação | contexto técnico em `OtherDiagnosticData`, não User ID nem Device ID |

Declarações de coleta:

| Tipo Apple | Linked pelo SDK | Tracking | Purpose |
|---|---:|---:|---|
| `NSPrivacyCollectedDataTypeDeviceID` | `false` | `false` | `AppFunctionality` |
| `NSPrivacyCollectedDataTypeOtherDiagnosticData` | `false` | `false` | `AppFunctionality` |

`AppFunctionality` foi escolhido porque a definição oficial inclui autenticação,
disponibilidade do servidor, redução de falhas, escalabilidade, desempenho e
suporte. `Analytics` descreve avaliação de comportamento do usuário, audiência ou
efetividade de features, comportamento ausente neste package.

### Installation ID e vinculação

O provider gera `UUID().uuidString`, persiste-o em `UserDefaults`, não deriva de
IDFA, IDFV, serial, usuário ou número USP e não usa Keychain. O valor só é anexado
a requests cujo host está na allowlist explícita.

O SDK não recebe identidade e não executa vinculação, logo seu manifest registra
`NSPrivacyCollectedDataTypeLinked = false`. Entretanto, o backend do consumidor
pode receber o ID em request autenticada e associá-lo a uma conta. Essa decisão é
externa ao package. Se houver associação direta ou facilmente realizável, o app
deve declarar o dado como vinculado em seu contexto e manter App Store Connect e
política de privacidade coerentes.

### Tracking e privacidade por design

Os dois manifests declaram `NSPrivacyTracking = false` e omitem
`NSPrivacyTrackingDomains`. O código não contém publicidade, marketing, data
broker nem correlação entre propriedades de empresas diferentes.

No `USPObservabilityKit`, foi reconfirmado que:

- os headers não contêm PII, credenciais ou token de autorização;
- `Authorization` é somente preservado na request, não copiado para contexto;
- `trace_id` e `parent_id` são aleatórios e separados do Installation ID;
- o Installation ID é separado de identidade de usuário no SDK;
- nenhum header é adicionado fora da allowlist;
- não há envio direto a terceiros, tracking ou fingerprinting.

## Estado resultante

Cada target agora possui e processa seu próprio manifest:

```text
Sources/
├── USPAuthKit/
│   └── PrivacyInfo.xcprivacy
└── USPObservabilityKit/
    └── PrivacyInfo.xcprivacy
```

O `Package.swift` adiciona somente
`.process("PrivacyInfo.xcprivacy")` aos dois targets. Products, modules, imports,
iOS 14, APIs públicas e dependências permanecem iguais.

## Arquivos alterados

- `Package.swift`;
- `README.md`.

## Arquivos criados

- `Sources/USPAuthKit/PrivacyInfo.xcprivacy`;
- `Sources/USPObservabilityKit/PrivacyInfo.xcprivacy`;
- `docs/iterations/02.1-privacy-manifest/plan.md`;
- `docs/iterations/02.1-privacy-manifest/walkthrough.md`.

## Testes e validações

### Property lists

```text
plutil -lint Sources/USPAuthKit/PrivacyInfo.xcprivacy
Sources/USPAuthKit/PrivacyInfo.xcprivacy: OK

plutil -lint Sources/USPObservabilityKit/PrivacyInfo.xcprivacy
Sources/USPObservabilityKit/PrivacyInfo.xcprivacy: OK
```

`plutil -p` também confirmou os tipos: arrays para APIs/dados/purposes, strings
para categorias/reasons e booleanos para tracking/linked. Não há categorias,
purposes ou reasons customizados e não há duplicidades dentro de cada manifest.

### Swift Package

```text
swift test --parallel
Build complete
66/66 testes aprovados

swift build -c release
Build complete
```

O SwiftPM precisou ser executado fora do sandbox restrito do agente porque seu
próprio `sandbox-exec` foi bloqueado pelo ambiente. Isso não foi falha do projeto.

`swift package dump-package` confirmou:

- iOS mínimo 14.0 inalterado;
- products `USPAuthKit` e `USPObservabilityKit` inalterados;
- resource `PrivacyInfo.xcprivacy` processado nos dois targets;
- lista de dependências externas vazia.

Os builds debug e release produziram bundles separados:

```text
USPMobileKit_USPAuthKit.bundle/.../PrivacyInfo.xcprivacy
USPMobileKit_USPObservabilityKit.bundle/.../PrivacyInfo.xcprivacy
```

Um build adicional com Xcode para `generic/platform=iOS`, sem assinatura, também
terminou com `BUILD SUCCEEDED` e gerou:

```text
Debug-iphoneos/USPMobileKit_USPAuthKit.bundle/PrivacyInfo.xcprivacy
Debug-iphoneos/USPMobileKit_USPObservabilityKit.bundle/PrivacyInfo.xcprivacy
```

O build iOS apresentou dois warnings preexistentes no Auth, sem relação com os
manifests: uso de `UI_USER_INTERFACE_IDIOM` já deprecado e declaração de
`disposeWebView` sem implementação encontrada. Eles não foram alterados por
estarem fora do escopo desta revisão.

O `Package.swift` continua declarando iOS 14. A toolchain Xcode 27 disponível
compilou o build genérico com deployment target efetivo iOS 15, portanto não foi
possível executar uma validação específica em runtime iOS 14 neste ambiente. A
adição é somente de resources SPM e não introduz API de runtime mais recente.

### Consumidor mínimo

Um package temporário fora do repositório declarou dependência local do
USPMobileKit, importou simultaneamente `USPAuthKit` e `USPObservabilityKit`, criou
um `USPContextInstrumenter` e foi compilado em release com sucesso. A execução
confirmou os dois imports. Seu diretório de produtos continha os dois resource
bundles, cada um com seu manifest, sem colisão de nomes.

## Compatibilidade

- APIs públicas: sem alteração;
- products/modules: sem alteração;
- deployment target: iOS 14, sem alteração;
- persistência: keys e comportamento inalterados;
- integrações e rede: inalteradas;
- configuração: somente resources adicionados aos targets;
- dependências: nenhuma adicionada;
- breaking changes: nenhum.

## Limitações e responsabilidades do consumidor

- A retenção no backend determina se uma transmissão satisfaz a definição Apple
  de coleta; o package declara as capacidades esperadas de autenticação e
  observabilidade, mas não controla retenção.
- A vinculação do Installation ID depende do app/backend. O consumidor deve
  corrigir sua declaração se associar o valor a conta ou identidade.
- O inicializador de `USPAuthService` aceita uma instância de `NSUserDefaults`.
  Caso o app injete uma suite de App Group, deve auditar e declarar o reason
  correspondente (`1C8F.1` quando aplicável); o package não cria esse cenário.
- Logs de servidor, endereço IP, retenção, compartilhamento e qualquer
  enriquecimento de dados são invisíveis ao código local e precisam de auditoria
  do backend.
- Não foi alterado um app real nem o App Store Connect. A agregação final precisa
  ser validada no archive do consumidor.

## Validação posterior no app

1. Integrar a versão do package que contém estes manifests.
2. No Xcode, executar **Product → Archive**.
3. No Organizer, abrir o menu de contexto do archive e selecionar
   **Generate Privacy Report**.
4. Verificar a agregação do manifest do app, `USPAuthKit`,
   `USPObservabilityKit` e demais SDKs.
5. Comparar o relatório com rede e retenção reais do backend.
6. Atualizar, se necessário, o manifest do app, a política de privacidade e as
   respostas de App Privacy no App Store Connect.

## Próximos passos

Auditar novamente os manifests sempre que houver mudança de persistência, headers,
backend, SDKs, tipos de dados ou finalidade. A Iteração 3 de observabilidade não foi
iniciada nem alterada nesta entrega.
