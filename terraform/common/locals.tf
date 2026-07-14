locals {
  # 共通設定
  service = "sandbox-app"
  env     = "prd"
  ## 作成した全リソースにデフォルトで付与されるタグ
  default_tags = {
    service   = local.service,
    env       = local.env,
    ManagedBy = "https://github.com/yuu0w0yuu/aws-app.git/aws-app/terraform/common"
  }

  # VPC設定
  vpc = {
    vpc_cidr = "10.0.0.0/16"

    public_subnets = [
      { cidr = "10.0.0.0/24", az = "ap-northeast-1a" },
      { cidr = "10.0.1.0/24", az = "ap-northeast-1c" }
    ]

    private_subnets = [
      { cidr = "10.0.10.0/24", az = "ap-northeast-1a" },
      { cidr = "10.0.11.0/24", az = "ap-northeast-1c" }
    ]
  }
}