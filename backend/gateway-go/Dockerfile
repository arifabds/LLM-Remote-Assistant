# === AŞAMA 1: DERLEME (BUILDER) ===
# Senin istediğin gibi Go 1.25 kullanıyoruz.
FROM golang:1.25-alpine AS builder

WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY . .

# Derlenmiş dosyayı /app/gateway olarak değil, /gateway olarak derleyelim. Daha basit.
RUN CGO_ENABLED=0 go build -o /gateway .


# === AŞAMA 2: ÇALIŞTIRMA (RUNNER) ===
FROM alpine:latest

# Çalışma dizini olarak kök dizini kullanalım, bu en basitidir.
WORKDIR /

# Builder'dan keys klasörünü kopyala.
# Dikkat: Builder'da WORKDIR /src olduğu için kaynak yolu /src/keys olmalı.
COPY --from=builder /src/keys ./keys

# Derlenmiş uygulamayı kopyala.
COPY --from=builder /gateway .

EXPOSE 8080

# Komut, kök dizindeki gateway dosyasını çalıştıracak.
CMD ["./gateway"]