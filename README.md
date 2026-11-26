# Serviços de Rede no Kathará: Publicação Segura (HTTP + SSH)

Laboratório reproduzível no **Kathará** que publica um servidor web (**NGINX**) e um servidor **OpenSSH** endurecido em uma DMZ atrás de um roteador/firewall (`gw`) com **DNAT**, **MASQUERADE** e política `FORWARD DROP`.

## Integrantes

- **Luís Gustavo Dos Anjos Correia e Rocha** (Turma LSOR 923A)
- **Agatha Marinho Santos** (Turma LSOR 923A)

---

## Visão de Pássaro — 5W1H de HTTP e SSH

| Pergunta | HTTP (NGINX) | SSH (OpenSSH) |
|---|---|---|
| **What (O quê)** | Protocolo de camada de aplicação para entrega de páginas e APIs (HTTP/1.1 em texto claro na porta 80). | Protocolo de camada de aplicação para acesso remoto administrativo com canal cifrado e autenticado (porta 22). |
| **Why (Por quê)** | Publicar o site institucional e o endpoint `/api/status` para clientes internos e externos. | Permitir administração remota segura dos servidores sem trafegar credenciais ou comandos em texto claro. |
| **Who (Quem)** | Clientes da Internet (`ext`) e estação de administração (`admin`) acessando o servidor `web`. | Administrador a partir da LAN (`admin`) ou da Internet (`ext`) autenticando como usuário `dupla` no `bastion`. |
| **Where (Onde)** | Servidor `web` na DMZ (`10.10.1.80:80`), exposto na Internet via DNAT em `203.0.113.1:80`. | Servidor `bastion` na DMZ (`10.10.1.22:22`), exposto na Internet via DNAT em `203.0.113.1:2222`. |
| **When (Quando)** | Sob demanda, a cada requisição `GET` de navegadores ou `curl`. | Sob demanda, sempre que o administrador precisa operar ou auditar o ambiente. |
| **How (Como)** | Server block dedicado em `/etc/nginx/sites-available/lsor.conf`, log exclusivo (`/var/log/nginx/lsor-access.log`), `/api/status` em JSON e página 404 personalizada. | Endurecido em `/etc/ssh/sshd_config.d/99-lsor-hardening.conf`: `PermitRootLogin no`, `PasswordAuthentication no`, `PubkeyAuthentication yes`, `AllowUsers dupla` e chaves de host geradas no boot (`ssh-keygen -A`). |

---

## Tabela de Endereçamento

| Dispositivo | Interface → Domínio | Endereço IP | Rota padrão | Imagem | Função |
|---|---|---|---|---|---|
| `ext` | `eth0` → `inet` | `203.0.113.50/24` | *(nenhuma)* | `agenteholden/lsor-tools:1.0` | Cliente na "Internet" (TEST-NET-3) |
| `gw` | `eth0` → `inet`<br>`eth1` → `dmz`<br>`eth2` → `lan` | `203.0.113.1/24`<br>`10.10.1.1/24`<br>`10.10.2.1/24` | — | `kathara/base` | Roteador, DNAT, MASQUERADE e firewall (`FORWARD DROP`) |
| `web` | `eth0` → `dmz` | `10.10.1.80/24` | `via 10.10.1.1` | `agenteholden/lsor-web:1.0` | Servidor HTTP (NGINX) |
| `bastion` | `eth0` → `dmz` | `10.10.1.22/24` | `via 10.10.1.1` | `kathara/base` | Servidor SSH (OpenSSH endurecido) |
| `admin` | `eth0` → `lan` | `10.10.2.10/24` | `via 10.10.2.1` | `agenteholden/lsor-tools:1.0` | Estação do administrador |

---

## Imagens no Docker Hub

- **Web (NGINX + site + server block):** `https://hub.docker.com/r/agenteholden/lsor-web` (`agenteholden/lsor-web:1.0`)
- **Tools (NMAP + curl + cliente SSH):** `https://hub.docker.com/r/agenteholden/lsor-tools` (`agenteholden/lsor-tools:1.0`)

---

## Decisão sobre Chaves SSH (Segurança e Riscos)

Adotamos a **geração efêmera no boot com troca de chaves públicas via `/shared`** do Kathará:

- No boot, `admin.startup` e `ext.startup` geram pares `ed25519` novos em `/root/.ssh/` e copiam apenas as chaves públicas (`admin.pub` e `ext.pub`) para `/shared/`.
- `bastion.startup` gera chaves de host novas (`ssh-keygen -A`) — nunca embutidas em imagem — e sincroniza `/shared/*.pub` em `/home/dupla/.ssh/authorized_keys` (`chmod 600`).
- **Por que esta escolha:** evita versionar chaves privadas no GitHub (o que seria uma má prática grave em produção e pode disparar alertas de vazamento de segredos).
- **Riscos e limitações:** em um ambiente real, não existe pasta `/shared` entre clientes externos e o bastion; a entrega da chave pública precisaria de um canal confiável (provisionamento/IdP/CI) e validação do fingerprint da chave de host do servidor (nos scripts automatizados usamos `StrictHostKeyChecking=no` apenas porque as chaves de host mudam a cada boot do lab).

---

## Como Executar

Pré-requisitos: **Docker** em execução e **Kathará** instalado (não é necessário rodar `docker build`).

```bash
git clone https://github.com/Luis-Vscode/lsor-servicos-kathara.git
cd lsor-servicos-kathara
kathara lstart
```

Para encerrar e limpar o laboratório:

```bash
kathara lclean
```

---

## Como Rodar os Testes (T1–T10)

Com o laboratório em execução (`kathara lstart`), copie/execute os scripts nos respectivos nós (a pasta do projeto fica acessível ou via `kathara exec`):

```bash
# Testes internos (T1 a T5) no nó admin:
kathara exec admin -- sh < testes/internos.sh

# Testes externos (T6 a T9) no nó ext:
kathara exec ext -- sh < testes/externos.sh

# Teste T10 (log de acesso no web confirmando IP real 203.0.113.50 via DNAT):
kathara exec web -- tail -n 5 /var/log/nginx/lsor-access.log
```

As saídas reais dos testes, o resultado do NMAP externo e as capturas `.pcap` feitas no `gw` (HTTP em texto claro vs. SSH cifrado) estão em [`evidencias/`](evidencias/).
