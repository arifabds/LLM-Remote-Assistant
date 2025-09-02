FROM python:3.10-slim as builder

RUN pip install --upgrade pip
COPY requirements.txt .
RUN pip install --prefix=/install -r requirements.txt

FROM python:3.10-slim

WORKDIR /app

COPY --from=builder /install /usr/local

COPY . .

RUN chmod +x start.sh

EXPOSE 8000
EXPOSE 50051

CMD ["./start.sh"]