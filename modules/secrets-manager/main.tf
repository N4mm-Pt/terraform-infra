resource "aws_secretsmanager_secret" "ably_api" {
  name = var.secret_name
}

resource "aws_secretsmanager_secret_version" "ably_api_version" {
  secret_id     = aws_secretsmanager_secret.ably_api.id
  secret_string = jsonencode(var.secret_value)
}

