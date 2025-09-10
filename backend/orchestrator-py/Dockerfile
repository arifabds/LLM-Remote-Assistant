# backend/orchestrator-py/Dockerfile - NİHAİ VE EN SAĞLAM VERSİYON

FROM python:3.10-slim

WORKDIR /app

ENV PYTHONPATH=/app

COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

COPY . .

RUN python -m grpc_tools.protoc -I./protos --python_out=./protos --pyi_out=./protos --grpc_python_out=./protos ./protos/orchestrator.proto

EXPOSE 8000
EXPOSE 50051

# 'start.sh' yerine doğrudan 'uvicorn' komutunu çalıştır.
# --reload bayrağını da şimdilik kaldırarak en stabil başlangıcı garanti edelim.
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]