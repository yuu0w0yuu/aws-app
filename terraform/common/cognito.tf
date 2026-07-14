resource "aws_cognito_user_pool" "main" {
  name = "${local.service}-${local.env}-user-pool"
  auto_verified_attributes = ["email"]
  username_attributes      = ["email"]
  mfa_configuration        = "OFF"
  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }
  tags = local.default_tags
}