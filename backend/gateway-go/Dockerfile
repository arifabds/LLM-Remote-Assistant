# Build stage
FROM golang:1.19-alpine as builder

WORKDIR /app

COPY . .

# Build the application
RUN CGO_ENABLED=0 go build -o gateway .

# Runtime stage
FROM scratch

WORKDIR /

COPY --from=builder /app/gateway .

EXPOSE 8080

CMD ["/gateway"]