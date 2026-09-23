# Iteração 02.1 — Privacy Manifests

## Problema

O USPMobileKit usa APIs classificadas pela Apple como Required Reason APIs e
habilita coleta necessária às funcionalidades de autenticação e observabilidade,
mas ainda não distribui manifests de privacidade por target. O app consumidor não
deve justificar APIs acessadas internamente pelo package.

## Escopo

- auditar separadamente `USPAuthKit` e `USPObservabilityKit`;
- identificar Required Reason APIs e dados efetivamente tratados ou enviados;
- criar um `PrivacyInfo.xcprivacy` para cada target que precise dele;
- incluir os manifests como resources do Swift Package;
- documentar responsabilidades que dependem do app ou backend consumidor;
- validar plists, build, testes e consumo por outro package.

Não fazem parte do escopo novas funcionalidades de observabilidade, mudanças de
backend, analytics, tracking, ATT, App Groups, Keychain para Installation ID,
OpenTelemetry ou Firebase.

## Auditoria e decisões

### Required Reason APIs

A única categoria encontrada em `Sources/` foi
`NSPrivacyAccessedAPICategoryUserDefaults`:

- `USPAuthKit`: `NSUserDefaults.standardUserDefaults` persiste tokens OAuth,
  token/plataforma de push, estado de registro e o JSON do usuário. A injeção de
  outra instância existe para isolamento/testes; o kit não cria App Group nem lê
  defaults globais.
- `USPObservabilityKit`: `UserDefaults.standard` persiste um UUID aleatório da
  instalação. O kit não cria App Group, não lê dados de outros apps e não usa o
  valor para fingerprinting.

Para ambos, o comportamento corresponde ao approved reason `CA92.1`: leitura e
escrita de informações acessíveis somente pelo próprio app. `C56D.1` não se
aplica ao Auth: o target não é um wrapper genérico de defaults e usa os valores
para sua própria funcionalidade.

Não foram encontrados acessos a timestamps/atributos de arquivos, boot time,
espaço em disco ou teclados ativos.

### Dados coletados

Segundo a definição da Apple, coleta pressupõe transmissão off-device com acesso
além do necessário para servir a requisição em tempo real. Os manifests descrevem
as capacidades do código quando os backends retêm os dados usados pelas
funcionalidades:

- `USPAuthKit`:
  - `NSPrivacyCollectedDataTypeUserID`, vinculado, para autenticação e registro do
    usuário (`wsuserid`/identificadores OAuth);
  - `NSPrivacyCollectedDataTypeDeviceID`, vinculado, para registrar o token de
    push junto à conta;
  - finalidade `NSPrivacyCollectedDataTypePurposeAppFunctionality`.
- `USPObservabilityKit`:
  - `NSPrivacyCollectedDataTypeDeviceID`, não vinculado pelo próprio SDK, para o
    `USP-Installation-Id`;
  - `NSPrivacyCollectedDataTypeOtherDiagnosticData`, não vinculado pelo próprio
    SDK, para plataforma/versão/build do app, versão do SO, modelo do dispositivo
    e contexto técnico aleatório da operação;
  - finalidade `NSPrivacyCollectedDataTypePurposeAppFunctionality`, que inclui
    assegurar disponibilidade, minimizar falhas e melhorar desempenho. Não foi
    usado `Analytics`, pois o código não mede comportamento do usuário.

Nomes, e-mails, telefone e vínculos recebidos pelo Auth são armazenados localmente
e expostos ao app, mas o código auditado não os transmite de volta. O conteúdo
exato do dicionário retornado pelo endpoint de usuário é controlado pelo backend;
novos usos off-device exigem nova revisão.

O `trace_id` é aleatório e limitado a uma operação; não é `UserID` nem `DeviceID`.
Ele integra o contexto técnico declarado como `OtherDiagnosticData`.

### Tracking e vinculação

Nenhum target contém publicidade, data broker, correlação entre apps/sites de
empresas diferentes ou fingerprinting. Ambos declaram `NSPrivacyTracking = false`
e omitem `NSPrivacyTrackingDomains`.

O `USPObservabilityKit` não conhece identidade de usuário nem vincula o
Installation ID por conta própria, portanto o marca como não vinculado. Um backend
consumidor pode, contudo, receber esses headers em uma requisição autenticada e
associá-los a uma conta. Nesse caso, o app consumidor deve refletir a vinculação no
seu manifest, Privacy Report, política de privacidade e App Privacy no App Store
Connect. Essa propriedade não pode ser inferida apenas pelo código do package.

## Componentes afetados

- `Package.swift`;
- `Sources/USPAuthKit/PrivacyInfo.xcprivacy`;
- `Sources/USPObservabilityKit/PrivacyInfo.xcprivacy`;
- `README.md`;
- documentação desta iteração.

Nenhuma API pública, nome de product/module, deployment target ou dependência será
alterado.

## Etapas de implementação

1. Criar manifests específicos por target.
2. Registrá-los com `.process("PrivacyInfo.xcprivacy")` nos respectivos targets.
3. Validar estrutura e valores com `plutil`.
4. Executar testes e build release.
5. Consumir os dois products a partir de um package mínimo e inspecionar os
   resource bundles gerados.
6. Atualizar README e walkthrough com decisões e limitações.

## Estratégia de testes

- `plutil -lint` nos dois manifests;
- inspeção das chaves/tipos com `plutil -p`;
- `swift test --parallel`;
- `swift build -c release`;
- package consumidor temporário importando os dois products;
- inspeção dos bundles produzidos para confirmar `PrivacyInfo.xcprivacy` em cada
  target.

## Riscos

- O backend pode reter ou vincular dados de forma não observável no código local.
- O app pode injetar uma suite de `NSUserDefaults` com App Group no inicializador
  público do Auth, apesar de o package não criar nem exigir esse uso. Tal
  configuração deve ser auditada pelo consumidor e pode exigir reason adicional.
- A agregação final do Privacy Report depende de um archive de app real no Xcode;
  o package isolado só permite verificar empacotamento dos resources.

## Critérios de aceite

- manifests válidos e empacotados separadamente;
- Required Reason API declarada com reason atual e compatível;
- somente tipos de dados suportados pelo comportamento real;
- tracking coerente e sem domínio vazio;
- testes e build release aprovados;
- imports dos dois products aprovados em consumidor mínimo;
- responsabilidades de backend/app explicitadas;
- zero breaking changes e zero dependências novas.
