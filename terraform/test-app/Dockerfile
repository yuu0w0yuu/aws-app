### Builder Stage
FROM golang:1.26.0-alpine AS builder

WORKDIR /app

# 依存関係のキャッシュ用に先にgo.modをコピー
COPY go.mod .
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -o server

### Final Stage
FROM debian:12-slim
WORKDIR /app

RUN apt-get update && \
    apt-get install -y --no-install-recommends curl ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# 非特権ユーザーを作成して実行
RUN useradd -u 65532 -U appuser
USER appuser

COPY --from=builder /app/server .
EXPOSE 8080
ENTRYPOINT ["./server"]