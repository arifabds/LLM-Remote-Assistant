FROM golang:1.25-alpine as builder

WORKDIR /src

COPY go.mod go.sum ./

RUN go mod download

COPY . .

RUN CGO_ENABLED=0 go build -o /app/gateway .

FROM scratch
COPY --from=builder /app/gateway /gateway
EXPOSE 8080
CMD ["/gateway"]