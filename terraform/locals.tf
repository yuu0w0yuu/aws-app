locals {
  # 共通設定
  service = "sandbox-app"
  env     = "prd"
  ## 作成した全リソースにデフォルトで付与されるタグ
  default_tags = {
    service   = local.service,
    env       = local.env,
    ManagedBy = "https://github.com/yuu0w0yuu/aws-app.git"
  }
}