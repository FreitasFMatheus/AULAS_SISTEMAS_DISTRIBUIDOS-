FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    lua5.4 \
    liblua5.4-dev \
    luarocks \
    libzmq3-dev \
    build-essential \
    cmake \
    git \
    pkg-config \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Garante que 'lua' aponte para lua5.4
RUN ln -sf /usr/bin/lua5.4 /usr/local/bin/lua

RUN luarocks --lua-version 5.4 --lua-dir /usr install lua-messagepack

# lzmq 0.3.3 não inclui zmq.h explicitamente em zsocket.c — patch necessário para Ubuntu 22.04
RUN mkdir -p /tmp/lzmq_build && \
    cd /tmp/lzmq_build && \
    luarocks --lua-version 5.4 --lua-dir /usr download --source lzmq 0.3.3 && \
    luarocks --lua-version 5.4 --lua-dir /usr unpack lzmq-0.3.3-1.src.rock && \
    sed -i '1s|^|#include <zmq.h>\n#include <stdint.h>\n#define luaL_checkint(L,n) ((int)luaL_checkinteger(L,n))\n#define luaL_optint(L,n,d) ((int)luaL_optinteger(L,n,d))\n|' lzmq-0.3.3-1/lzmq-0.3.3/src/zsocket.c && \
    sed -i 's/zmq_event_t event;/struct { uint16_t event; int32_t value; } event;/' lzmq-0.3.3-1/lzmq-0.3.3/src/zsocket.c && \
    sed -i '1s|^|#define luaL_checkint(L,n) ((int)luaL_checkinteger(L,n))\n#define luaL_optint(L,n,d) ((int)luaL_optinteger(L,n,d))\n|' lzmq-0.3.3-1/lzmq-0.3.3/src/zsupport.h && \
    sed -i '1s|^|#define luaL_checkint(L,n) ((int)luaL_checkinteger(L,n))\n|' lzmq-0.3.3-1/lzmq-0.3.3/src/ztimer.c && \
    sed -i '1s|^|#define luaL_optint(L,n,d) ((int)luaL_optinteger(L,n,d))\n|' lzmq-0.3.3-1/lzmq-0.3.3/src/zmsg.c && \
    cd lzmq-0.3.3-1/lzmq-0.3.3 && \
    luarocks --lua-version 5.4 --lua-dir /usr make lzmq-0.3.3-1.rockspec && \
    rm -rf /tmp/lzmq_build

WORKDIR /app
COPY cliente.lua .

CMD ["lua5.4", "cliente.lua"]
