import zmq
import msgpack
import time
import os
import random
import string

BROKER_FRONTEND = os.getenv("BROKER_FRONTEND", "tcp://broker:5555")
BOT_NAME = os.getenv("BOT_NAME", f"bot-{random.randint(1000, 9999)}")


def pack(obj):
    return msgpack.packb(obj, use_bin_type=True)


def unpack(data):
    return msgpack.unpackb(data, raw=False)


def enviar(socket, payload, timeout_ms=5000):
    socket.send(pack(payload))
    if socket.poll(timeout_ms):
        return unpack(socket.recv())
    return None


def log(op, detalhe):
    ts = time.strftime("%H:%M:%S")
    print(f"[{BOT_NAME}][{ts}] {op} | {detalhe}", flush=True)


def fazer_login(socket):
    while True:
        payload = {
            "operacao": "login",
            "username": BOT_NAME,
            "timestamp": time.time(),
        }
        log("SEND login", f"username={BOT_NAME}")
        resp = enviar(socket, payload)

        if resp is None:
            log("RECV login", "timeout, tentando de novo...")
            time.sleep(2)
            continue

        log("RECV login", f"status={resp.get('status')} msg={resp.get('mensagem', resp.get('motivo', ''))}")

        if resp.get("status") == "ok":
            return

        time.sleep(2)


def listar_canais(socket):
    payload = {
        "operacao": "listar_canais",
        "username": BOT_NAME,
        "timestamp": time.time(),
    }
    log("SEND listar_canais", "")
    resp = enviar(socket, payload)
    if resp:
        canais = resp.get("canais", [])
        log("RECV listar_canais", f"{canais}")
        return canais
    log("RECV listar_canais", "timeout")
    return []


def criar_canal(socket, nome):
    payload = {
        "operacao": "criar_canal",
        "canal": nome,
        "username": BOT_NAME,
        "timestamp": time.time(),
    }
    log("SEND criar_canal", f"canal={nome}")
    resp = enviar(socket, payload)
    if resp:
        log("RECV criar_canal", f"status={resp.get('status')} msg={resp.get('mensagem', resp.get('motivo', ''))}")
        return resp.get("status") == "ok"
    log("RECV criar_canal", "timeout")
    return False


def main():
    time.sleep(3)

    ctx = zmq.Context()
    socket = ctx.socket(zmq.REQ)
    socket.connect(BROKER_FRONTEND)
    print(f"[{BOT_NAME}] conectado em {BROKER_FRONTEND}", flush=True)

    fazer_login(socket)

    canais = listar_canais(socket)

    if len(canais) < 5:
        sufixo = ''.join(random.choices(string.ascii_lowercase, k=4))
        novo = f"canal-{sufixo}"
        criar_canal(socket, novo)
        canais = listar_canais(socket)

    print(f"[{BOT_NAME}] canais disponíveis: {canais}", flush=True)

    while True:
        time.sleep(30)


if __name__ == "__main__":
    main()
