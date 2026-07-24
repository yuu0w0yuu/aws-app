# About
Next.jsのDemo Webアプリケーション
実装方針については[ガイドライン](./docs/guideline)に記述

# ローカル環境構築
- 以前のデータベースのクリアをする場合
```
docker compose -f ./local-env-docker/docker-compose.yml  down --volumes
```

```bash
pnpm install

docker compose -f local-env-docker/docker-compose.yml up -d
pnpm prisma migrate dev
pnpm prisma db seed

pnpm dev
```

