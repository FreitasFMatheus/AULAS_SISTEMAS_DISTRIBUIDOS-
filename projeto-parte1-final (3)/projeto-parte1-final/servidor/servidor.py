import zmq
import msgpack
import sqlite3
import time
import os
import re

BROKER_BACKEND = os.getenv("BROKER_BACKEND", "tcp://broker:5556")
SERVER_NAME = os.getenv("SERVER_NAME", "servidor-1")
DB_PATH = f"/data/{SERVER_NAME}.db"


def init_db(conn):
    conn.execute("""
        CREATE TABLE IF NOT EXISTS logins (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL,
            timestamp REAL NOT NULL
        )
    """)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS canais (
            nome TEXT PRIMARY KEY,
            criado_em REAL NOT NULL
        )
    """)
    conn.commit()


def registrar_login(conn, username, ts):
    conn.execute("INSERT INTO logins (username, timestamp) VALUES (?, ?)", (username, ts))
    conn.commit()


def usuario_ja_existe(conn, username):
    row = conn.execute("SELECT 1 FROM logins WHERE username = ?", (username,)).fetchone()
    return row is not None


def inserir_canal(conn, nome, ts):
    try:
        conn.execute("INSERT INTO canais (nome, criado_em) VALUES (?, ?)", (nome, ts))
        conn.commit()
        return True
    except sqlite3.IntegrityError:
        return False


def buscar_canais(conn):
    rows = conn.execute("SELECT nome FROM canais ORDER BY criado_em").fetchall()
    return [r[0] for r in rows]


def pack(obj):
    return msgpack.packb(obj, use_bin_type=True)


def unpack(data):
    return msgpack.unpackb(data, raw=False)


def handle_login(conn, payload):
    username = payload.get("username", "").strip()
    ts = payload.get("timestamp", time.time())

    if not username:
        return {"status": "erro", "motivo": "username vazio", "timestamp": time.time()}

    if usuario_ja_existe(conn, username):
        registrar_login(conn, username, ts)
        print(f"[{SERVER_NAME}] re-login: {username}", flush=True)
        return {"status": "ok", "mensagem": f"bem-vindo de volta, {username}", "timestamp": time.time()}

    registrar_login(conn, username, ts)
    print(f"[{SERVER_NAME}] login: {username}", flush=True)
    return {"status": "ok", "mensagem": f"login ok, {username}", "timestamp": time.time()}


def handle_criar_canal(conn, payload):
    nome = payload.get("canal", "").strip()
    ts = payload.get("timestamp", time.time())

    if not nome:
        return {"status": "erro", "motivo": "nome vazio", "timestamp": time.time()}

    if not re.match(r'^[\w\-]{1,64}$', nome):
        return {"status": "erro", "motivo": "nome invalido", "timestamp": time.time()}

    criado = inserir_canal(conn, nome, ts)
    if criado:
        print(f"[{SERVER_NAME}] canal criado: {nome}", flush=True)
        return {"status": "ok", "mensagem": f"canal {nome} criado", "timestamp": time.time()}
    else:
        print(f"[{SERVER_NAME}] canal ja existe: {nome}", flush=True)
        return {"status": "ok", "mensagem": f"canal {nome} ja existe", "timestamp": time.time()}


def handle_listar_canais(conn, payload):
    canais = buscar_canais(conn)
    print(f"[{SERVER_NAME}] listando canais: {canais}", flush=True)
    return {"status": "ok", "canais": canais, "timestamp": time.time()}


def main():
    os.makedirs("/data", exist_ok=True)
    conn = sqlite3.connect(DB_PATH, check_same_thread=False)
    init_db(conn)

    context = zmq.Context()
    socket = context.socket(zmq.DEALER)
    socket.connect(BROKER_BACKEND)

    print(f"[{SERVER_NAME}] conectado em {BROKER_BACKEND}", flush=True)

    handlers = {
        "login": handle_login,
        "criar_canal": handle_criar_canal,
        "listar_canais": handle_listar_canais,
    }

    while True:
        try:
            frames = socket.recv_multipart()
            if len(frames) < 3:
                continue

            identity, empty, raw = frames[0], frames[1], frames[2]
            payload = unpack(raw)

            op = payload.get("operacao", "")
            fn = handlers.get(op)

            if fn:
                resp = fn(conn, payload)
            else:
                resp = {"status": "erro", "motivo": f"operacao desconhecida: {op}", "timestamp": time.time()}

            socket.send_multipart([identity, empty, pack(resp)])

        except Exception as e:
            print(f"[{SERVER_NAME}] erro: {e}", flush=True)


if __name__ == "__main__":
    main()
