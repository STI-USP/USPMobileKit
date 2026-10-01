# Auditoria de segurança

2026-10-01, baseline `11d9582`. [Roadmap e prioridades](modernization-roadmap.md). Análise de código + builds/testes locais; sem credenciais reais, servidor, app consumidor ou exploração end-to-end. Severidade é independente de P0–P3: P0 trata impedimento da migração, não significa incidente crítico.

## Modelo de risco

Ativos: par OAuth, consumerSecret, credencial funcional wsuserid, perfil/PII, push e estado de autenticação. Fronteiras: app/config → SDK; SDK → defaults; WKWebView → callback; SDK → rede. Controle do servidor sobre assinatura, replay, revogação e expiração é desconhecido. Sandbox/criptação do dispositivo não tornam defaults armazenamento específico de segredo. A Apple orienta manter informação sensível no [Keychain, não UserDefaults](https://developer.apple.com/documentation/foundation/userdefaults); detalhes de armazenamento em [Keychain Services](https://developer.apple.com/documentation/security/keychain-services).

## Achados

| ID | Severidade / evidência | Consequência e limite da conclusão | Recomendação (sem alteração agora) |
|---|---|---|---|
| S01 | **Alto** — USPAuthSessionStore setters oauthToken/oauthTokenSecret/userData em defaults | Credenciais persistidas sem proteção própria de Keychain; userData inclui wsuserid e PII. Não prova acesso arbitrário por outro app sandboxed | Store injetável; migração transacional para Keychain de credenciais, política de cache mínimo/proteção de perfil; testes de falha/upgrade/downgrade/logout |
| S02 | **Alto** — OAuth1Controller decidePolicy usa webView.URL + substring oauth_verifier; não valida scheme/host/path nem token pendente | Callback sem correlação pode causar confusão de fluxo; URL usada pode ser anterior à navegação. Exploit e aceitação pelo servidor não demonstrados | Caracterizar callback esperado, comparar navigationAction.request.URL/destino e request token; consumo único, cancelar navegação inválida |
| S03 | **Alto** — logout não cancela tasks/controller; setters e fetch persistem em callbacks tardios | Credenciais/cache podem reaparecer após logout/cancelamento; possível estado cruzado entre tentativas | Generation/identidade de operação interna, completion única, cancelamento e descarte de resultados tardios; testes determinísticos |
| S04 | **Alto** — hmac.c reduz chave longa escrevendo em inKey; sha1.c SHA1Transform escreve no buffer sem SHA1HANDSOFF; signClearText passa NSData.bytes por cast | Escrita em memória que o chamador fornece como const; corrupção/crash possível dependendo do armazenamento. Experimento C confirma mutação de mensagem 160 bytes e chave 80 bytes; não prova crash em NSData | Testes de buffers, vetores curtos/longos e sanitizers; corrigir propriedade/mutabilidade do buffer em mudança específica que preserve digest, antes de troca de crypto |
| S05 | **Médio** — User.description inclui nome/wsuserid; quatro NSLog de localizedDescription; README anterior imprimia wsuserid (exemplo removido nesta entrega documental) | Logging de objeto pode expor credencial mobile e PII. Não existe NSLog explícito de tokenSecret encontrado; NSError externo pode conter URL/detalhes | Description redigida e erros/logs sanitizados; exemplos sem credencial; testes com payloads/URLs sintéticos |
| S06 | **Médio** — request/access/profile ignoram HTTP status; accessParams não exige par final não vazio | HTTP de erro com body parseável pode ser tratado como sucesso; cache não vazio pode virar sessão sem wsuserid | Status/payload validados por operação; manter códigos legados em adapter e formalizar sessão completa |
| S07 | **Médio** — config custom concatena string sem validar HTTPS/host; defaults sem ambiente/app/account | Reconfiguração pode reutilizar sessão de outro ambiente; URL custom insegura depende de ATS do app | Validar config e escopo de credencial após testes; mudar ambiente invalida/reseleciona sessão de forma explícita |
| S08 | **Médio** — NSUUID prefix 10, remove hífen: 9 hex = espaço de 36 bits; NSDate direto | Nonce truncado aumenta colisão versus UUID completo; clock drift pode invalidar assinatura. Replay real depende de janela e armazenamento do servidor | Injetar fontes para teste; avaliar nonce completo compatível e políticas servidor; nunca mudar assinatura sem vetores |
| S09 | **Médio** — WKWebView padrão/cookies; logout só defaults; delegates não limpos explicitamente | Logout SDK não implica logout SSO; browser embutido tem acesso ao conteúdo, risco de phishing/isolamento | Documentar três escopos (local, mobile, SSO); avaliar browser externo futuramente conforme servidor, sem limpar cookies globais silenciosamente |
| S10 | **Médio (condicional)** — KeychainItemWrapper init chama resetKeychainItem antes de popular keychainItemData; SecItemAdd/Update ignoram retorno; não define accessibility | Wrapper não é caminho atual; reaproveitamento pode falhar e ocultar persistência malsucedida. Não afirmar tokens atuais nele | Testar item ausente, lock/unlock/access group/delete e OSStatus antes de reutilizar; fronteira pequena adequada pode ser mais simples |
| S11 | **Baixo** — Vinculo initWithDictionary chama integerValue em valor não validado | NSNull/tipo incompatível pode derrubar parsing; resposta remota malformada afeta disponibilidade | Fallback definido/testado, validar payload top-level e campos |
| S12 | **Melhoria preventiva** — consumerSecret legível na config pública; header backend fixo em Service/helper | App contém consumerSecret por desenho legado. Valor do header não tem confidencialidade demonstrada; não o reproduzir nos docs nem supor autorização segura | Confirmar função e permissões/rotação com backend; reduzir acesso por API nova; não confiar em segredo embarcado como prova forte de app |
| S13 | **Melhoria preventiva** — defaults/cache URLSession/WebKit; nenhum redirect delegate/allowlist | Política de redirects/cache é padrão do sistema; forwarding de Authorization em redirect não foi testado. Sem evidência de TLS bypass | Testar redirects entre origens, cache e TLS com fixtures locais; política de destino por operação, sem pinning automático |
| S14 | **Baixo** — Base64DecodeData tabela de 128 com índice int8_t e loops sem checar fim | Possíveis acessos inválidos em entradas fora do alfabeto/fim; **decoder não é chamado pelo fluxo de Auth**, que só usa encode | Teste/fuzz/sanitizer se mantido ou reaproveitado; verificar uso indireto antes de remover |
| S15 | **Melhoria preventiva** — licenças e crypto vendorizado antigo, nenhum SDK externo | Manutenção própria sem baseline suficiente; idade não comprova vulnerabilidade e HMAC-SHA1 não deve ser confundido com colisão de hash simples | Vetores/Sanitizers e inventário de licença; substituição só em fase própria com equivalência comprovada |

Nenhum achado foi classificado crítico com a evidência disponível. S01–S04 são riscos altos a tratar antes de expandir a adoção de novos fluxos.

## Evidência experimental da criptografia

Compilou-se **somente em /tmp**, sem alterar sources:

```sh
xcrun clang -dynamiclib Sources/USPAuthKit/Core/hmac.c Sources/USPAuthKit/Core/sha1.c -o /tmp/uspauth-audit-hmac.dylib
```

Harness Python ctypes usou buffers mutáveis com `bytes(i % 256 for i in range(n))`, comparando os 20 bytes com `hmac.new(key, message, hashlib.sha1).digest()` antes de examinar as entradas.

| Mensagem/chave em bytes | Digest correto no experimento | Mensagem alterada | Chave alterada |
|---|---|---|---|
| 3 / 3 | Sim | Não | Não |
| 160 / 3 | Sim | Sim | Não |
| 3 / 80 | Sim | Não | Sim |
| 160 / 80 | Sim | Sim | Sim |

Quatro verificações diagnósticas, não testes incorporados nem prova de conformidade completa. O buffer da mensagem é alterado em blocos processados diretamente; 80 bytes de mensagem não revelou essa alteração. A correção futura precisa preservar assinatura e não apenas fazer os casos curtos passarem.

## OAuth, callback e replay

Confrontar handshake/callback e normalização com [RFC 5849](https://www.rfc-editor.org/info/rfc5849/), principalmente §§2, 3.3, 3.4, 3.6, preservando convenções USP até obter evidência. Token na URL authorize é temporário e esperado nesse protocolo; não é evidência isolada de vazamento de access secret. Callback/verifier e URLs não devem ir para logs. Nonce+timestamp só mitigam replay se o servidor validar unicidade/janela; essa proteção não é comprovável no cliente.

## Sistema e privacidade

Nenhum Info.plist/ATS de app existe aqui. Não há exceção ATS ou trust-all no SDK; apps podem possuir exceções externas. TLS é delegado às APIs do sistema. Manifest de Auth declara User ID/Device ID vinculados e defaults CA92.1; presença/lint não certifica App Privacy do consumidor. Perfil retornado inclui dados pessoais além dos identificadores: revisar coleta/retenção efetiva com backend e apps; não concluir conformidade só pelo SDK.

Para OAuth2 futuro, a direção é browser externo e proteção apropriada de autorização em app nativo, conforme [RFC 8252](https://www.rfc-editor.org/info/rfc8252/) e [RFC 9700](https://www.rfc-editor.org/info/rfc9700/). Isso fundamenta a proposta futura, não autoriza mudar hoje o browser/handshake OAuth1. ASWebAuthenticationSession, PKCE e demais decisões aguardam contrato do servidor.
