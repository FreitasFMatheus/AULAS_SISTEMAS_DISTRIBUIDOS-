local zmq = require("lzmq")
local mp  = require("MessagePack")
local os  = require("os")

local BROKER_FRONTEND = os.getenv("BROKER_FRONTEND") or "tcp://broker:5555"
local BOT_NAME        = os.getenv("BOT_NAME")        or "lua-bot"

local function now()
    return os.time() + 0.0
end

local function log(op, detail)
    local t = os.date("%H:%M:%S")
    io.write(string.format("[%s][%s] %s | %s\n", BOT_NAME, t, op, detail))
    io.flush()
end

local function sleep(s)
    os.execute("sleep " .. tostring(s))
end

local socket

local function enviar(payload)
    socket:send(mp.pack(payload))

    local poller = zmq.poller(1)
    poller:add(socket, zmq.POLLIN)
    local n = poller:poll(5000)

    if n and n > 0 then
        local raw = socket:recv()
        local ok, resp = pcall(mp.unpack, raw)
        if ok then return resp end
    end
    return nil
end

local function fazer_login()
    while true do
        local payload = {
            operacao  = "login",
            username  = BOT_NAME,
            timestamp = now(),
        }
        log("SEND login", "username=" .. BOT_NAME)
        local resp = enviar(payload)

        if resp == nil then
            log("RECV login", "timeout, tentando de novo...")
            sleep(2)
            -- socket REQ trava depois de timeout, precisa recriar
            socket:close()
            local ctx = zmq.context()
            socket = ctx:socket(zmq.REQ)
            socket:connect(BROKER_FRONTEND)
        else
            local status = resp.status or "?"
            local msg = resp.mensagem or resp.motivo or ""
            log("RECV login", "status=" .. status .. " msg=" .. msg)
            if status == "ok" then return end
            sleep(2)
        end
    end
end

local function listar_canais()
    local payload = {
        operacao  = "listar_canais",
        username  = BOT_NAME,
        timestamp = now(),
    }
    log("SEND listar_canais", "")
    local resp = enviar(payload)
    if resp then
        local canais = resp.canais or {}
        log("RECV listar_canais", table.concat(canais, ", "))
        return canais
    end
    log("RECV listar_canais", "timeout")
    return {}
end

local function criar_canal(nome)
    local payload = {
        operacao  = "criar_canal",
        canal     = nome,
        username  = BOT_NAME,
        timestamp = now(),
    }
    log("SEND criar_canal", "canal=" .. nome)
    local resp = enviar(payload)
    if resp then
        local status = resp.status or "?"
        local msg = resp.mensagem or resp.motivo or ""
        log("RECV criar_canal", "status=" .. status .. " msg=" .. msg)
        return status == "ok"
    end
    log("RECV criar_canal", "timeout")
    return false
end

local function random_suffix(n)
    local chars = "abcdefghijklmnopqrstuvwxyz"
    local result = ""
    math.randomseed(os.time())
    for _ = 1, n do
        local i = math.random(1, #chars)
        result = result .. chars:sub(i, i)
    end
    return result
end

local function main()
    sleep(4)

    local ctx = zmq.context()
    socket = ctx:socket(zmq.REQ)
    socket:connect(BROKER_FRONTEND)
    log("init", "conectado em " .. BROKER_FRONTEND)

    fazer_login()

    local canais = listar_canais()

    if #canais < 5 then
        local novo = "canal-" .. random_suffix(4)
        criar_canal(novo)
        canais = listar_canais()
    end

    io.write(string.format("[%s] canais: %s\n", BOT_NAME, table.concat(canais, ", ")))
    io.flush()

    while true do
        sleep(30)
    end
end

main()
