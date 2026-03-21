import zmq

# clientes mandam na 5555, servidores ouvem na 5556
FRONTEND_PORT = 5555
BACKEND_PORT = 5556

ctx = zmq.Context()

frontend = ctx.socket(zmq.ROUTER)
frontend.bind(f"tcp://*:{FRONTEND_PORT}")

backend = ctx.socket(zmq.DEALER)
backend.bind(f"tcp://*:{BACKEND_PORT}")

print(f"[broker] rodando frontend={FRONTEND_PORT} backend={BACKEND_PORT}", flush=True)

# zmq.proxy já faz o round-robin pra gente
zmq.proxy(frontend, backend)
