# CC7261 - Projeto BBS/IRC - Parte 1

## Dupla

- Matheus Ferreira de Freitas — 22.125.085-5
- Henrique Hodel Babler — 22.125.084-8

## Descrição

Implementação da parte 1 do projeto de sistemas distribuídos. Nessa parte o bot consegue fazer login no servidor, listar os canais disponíveis e criar novos canais.

O projeto é feito em dupla usando Python e Lua. Cada linguagem tem seu próprio cliente (bot) e servidor, mas todos se comunicam pelo mesmo broker usando o mesmo protocolo, então um bot em Python pode ser atendido por um servidor em Lua e vice-versa.

## Como rodar

```bash
docker compose up --build
```

Isso sobe 9 containers: 1 broker, 2 servidores Python, 2 servidores Lua, 2 bots Python e 2 bots Lua.

## Escolhas do projeto

**Linguagens:** Python 3.12 e Lua 5.4

**Serialização:** MessagePack — escolhemos porque é binário, simples de usar nas duas linguagens (libs `msgpack` no Python e `lua-messagepack` no Lua) e toda mensagem tem o campo `timestamp` obrigatório.

**Persistência:** SQLite — um arquivo `.db` por servidor em `/data/`. Guardamos todos os logins com timestamp e todos os canais criados.

**Broker:** usa o padrão ROUTER/DEALER do ZeroMQ que já faz round-robin automaticamente entre os servidores.

## Formato das mensagens

Requisição:
```
{ operacao, username, timestamp, [canal] }
```

Resposta:
```
{ status, timestamp, [mensagem | motivo | canais] }
```

## Estrutura

```
broker/          - broker.py
servidor/        - servidor.py (Python)
cliente/         - cliente.py (Python)
servidor-lua/    - servidor.lua (Lua)
cliente-lua/     - cliente.lua (Lua)
docker-compose.yaml
```
