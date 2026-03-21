local zmq     = require("lzmq")
local mp      = require("MessagePack")
local sqlite3 = require("lsqlite3")
local os      = require("os")

local BROKER_BACKEND = os.getenv("BROKER_BACKEND") or "tcp://broker:5556"
local SERVER_NAME    = os.getenv("SERVER_NAME")    or "servidor-lua-1"
local DB_PATH        = "/data/" .. SERVER_NAME .. ".db"

local function now()
    return os.time() + 0.0
end

local function log(op, detail)
    local t = os.date("%H:%M:%S")
    io.write(string.format("[%s][%s] %s | %s\n", SERVER_NAME, t, op, detail))
    io.flush()
end

local db

local function init_db()
    os.execute("mkdir -p /data")
    db = sqlite3.open(DB_PATH)
    db:exec([[
        CREATE TABLE IF NOT EXISTS logins (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL,
            timestamp REAL NOT NULL
        );
    ]])
    db:exec([[
        CREATE TABLE IF NOT EXISTS canais (
            nome TEXT PRIMARY KEY,
            criado_em REAL NOT NULL
        );
    ]])
    log("db", "banco aberto em " .. DB_PATH)
end

local function registrar_login(username, ts)
    local stmt = db:prepare("INSERT INTO logins (username, timestamp) VALUES (?, ?)")
    stmt:bind_values(username, ts)
    stmt:step()
    stmt:finalize()
end

local function usuario_existe(username)
    local stmt = db:prepare("SELECT 1 FROM logins WHERE username = ? LIMIT 1")
    stmt:bind_values(username)
    local row = stmt:step()
    stmt:finalize()
    return row == sqlite3.ROW
end

local function inserir_canal(nome, ts)
    local stmt = db:prepare("INSERT OR IGNORE INTO canais (nome, criado_em) VALUES (?, ?)")
    stmt:bind_values(nome, ts)
    stmt:step()
    local n = db:changes()
    stmt:finalize()
    return n > 0
end

local function buscar_canais()
    local lista = {}
    for row in db:nrows("SELECT nome FROM canais ORDER BY criado_em") do
        table.insert(lista, row.nome)
    end
    return lista
end

local function handle_login(payload)
    local username = (payload.username or ""):match("^%s*(.-)%s*$")
    local ts = payload.timestamp or now()

    if username == "" then
        return { status = "erro", motivo = "username vazio", timestamp = now() }
    end

    if usuario_existe(username) then
        registrar_login(username, ts)
        log("re-login", username)
        return { status = "ok", mensagem = "bem-vindo de volta, " .. username, timestamp = now() }
    end

    registrar_login(username, ts)
    log("login", username)
    return { status = "ok", mensagem = "login ok, " .. username, timestamp = now() }
end

local function handle_criar_canal(payload)
    local nome = (payload.canal or ""):match("^%s*(.-)%s*$")
    local ts = payload.timestamp or now()

    if nome == "" then
        return { status = "erro", motivo = "nome vazio", timestamp = now() }
    end

    if not nome:match("^[%w%-_]+$") or #nome > 64 then
        return { status = "erro", motivo = "nome invalido", timestamp = now() }
    end

    local ok = inserir_canal(nome, ts)
    if ok then
        log("canal criado", nome)
        return { status = "ok", mensagem = "canal " .. nome .. " criado", timestamp = now() }
    else
        log("canal ja existe", nome)
        return { status = "ok", mensagem = "canal " .. nome .. " ja existe", timestamp = now() }
    end
end

local function handle_listar_canais(payload)
    local canais = buscar_canais()
    log("list", table.concat(canais, ", "))
    return { status = "ok", canais = canais, timestamp = now() }
end

local handlers = {
    login         = handle_login,
    criar_canal   = handle_criar_canal,
    listar_canais = handle_listar_canais,
}

local function main()
    init_db()

    local ctx = zmq.context()
    local socket = ctx:socket(zmq.DEALER)
    socket:connect(BROKER_BACKEND)
    log("init", "conectado em " .. BROKER_BACKEND)

    while true do
        local identity = socket:recv()
        local empty    = socket:recv()
        local raw      = socket:recv()

        if raw then
            local ok, payload = pcall(mp.unpack, raw)
            local resp

            if not ok then
                log("erro", "falha ao desserializar")
                resp = { status = "erro", motivo = "mensagem invalida", timestamp = now() }
            else
                local op = payload.operacao or ""
                local fn = handlers[op]
                if fn then
                    local s, r = pcall(fn, payload)
                    resp = s and r or { status = "erro", motivo = tostring(r), timestamp = now() }
                else
                    resp = { status = "erro", motivo = "operacao desconhecida: " .. op, timestamp = now() }
                end
            end

            socket:send(identity, zmq.SNDMORE)
            socket:send(empty,    zmq.SNDMORE)
            socket:send(mp.pack(resp))
        end
    end
end

main()
