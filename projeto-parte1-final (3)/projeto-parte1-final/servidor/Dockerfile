FROM python:3.12-slim
WORKDIR /app
RUN pip install --no-cache-dir pyzmq msgpack
RUN mkdir -p /data
COPY servidor.py .
CMD ["python", "servidor.py"]
