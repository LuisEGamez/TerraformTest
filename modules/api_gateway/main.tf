resource "aws_api_gateway_rest_api" "eurovota_api" {
  name = "eurovota-api"
}

resource "aws_api_gateway_resource" "eurovota_api_root" {
  parent_id   = aws_api_gateway_rest_api.eurovota_api.root_resource_id
  path_part   = "eurovota-api"
  rest_api_id = aws_api_gateway_rest_api.eurovota_api.id
}

resource "aws_api_gateway_resource" "eurovota_api_login" {
  parent_id   = aws_api_gateway_resource.eurovota_api_root.id
  path_part   = "login"
  rest_api_id = aws_api_gateway_rest_api.eurovota_api.id
}

# Crear el modelo de solicitud
resource "aws_api_gateway_model" "login2" {
  rest_api_id = aws_api_gateway_rest_api.eurovota_api.id
  name        = "login2"
  content_type = "application/json"
  schema = <<EOF
{
  "$schema": "http://json-schema.org/draft-04/schema#",
  "title": "LoginRequest",
  "type": "object",
  "properties": {
    "phone": {
      "type": "string",
      "pattern": "^\\+\\d{1,15}$"
    },
    "password": {
      "type": "string",
      "minLength": 8,
      "maxLength": 20,
      "pattern": "^(?=.*[A-Z])(?=.*[a-z])(?=.*\\d)(?=.*[@$!%*?&])[A-Za-z\\d@$!%*?&]{8,}$"
    }
  },
  "required": ["phone", "password"],
  "additionalProperties": false
}
EOF
}

resource "aws_api_gateway_method" "eurovota_api_root_get" {
  authorization = "NONE"
  http_method   = "POST"
  resource_id   = aws_api_gateway_resource.eurovota_api_login.id
  rest_api_id   = aws_api_gateway_rest_api.eurovota_api.id

  request_models = {
    "application/json" = aws_api_gateway_model.login2.name
  }
}

resource "aws_api_gateway_vpc_link" "eurovota_users_vpc_link" {
  name = "eurovota-users-vpc-link"
  target_arns = [var.users_nlb_arn]
}

resource "aws_api_gateway_integration" "test" {
  rest_api_id = aws_api_gateway_rest_api.eurovota_api.id
  resource_id = aws_api_gateway_resource.eurovota_api_login.id
  http_method = aws_api_gateway_method.eurovota_api_root_get.http_method

  type                    = "HTTP"
  uri                     = "${var.protocol_type}${var.users_nlb_dns}/${aws_api_gateway_resource.eurovota_api_login.path_part}"
  integration_http_method = "POST"
  passthrough_behavior    = "WHEN_NO_TEMPLATES"
  content_handling        = "CONVERT_TO_TEXT"

  connection_type = "VPC_LINK"
  connection_id   = aws_api_gateway_vpc_link.eurovota_users_vpc_link.id
}

resource "aws_api_gateway_integration_response" "example" {
  http_method = aws_api_gateway_method.eurovota_api_root_get.http_method
  resource_id = aws_api_gateway_resource.eurovota_api_login.id
  response_templates = {
    "application/json": ""
  }
  rest_api_id = aws_api_gateway_rest_api.eurovota_api.id
  status_code = "200"

}

resource "aws_api_gateway_method_response" "login_response_200" {

  http_method = aws_api_gateway_method.eurovota_api_root_get.http_method
  resource_id = aws_api_gateway_resource.eurovota_api_login.id
  rest_api_id = aws_api_gateway_rest_api.eurovota_api.id
  status_code = "200"
  response_models = {
    "application/json": "Empty"
  }

}

resource "aws_api_gateway_deployment" "eurovota_api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.eurovota_api.id

  triggers = {
    # NOTE: The configuration below will satisfy ordering considerations,
    #       but not pick up all future REST API changes. More advanced patterns
    #       are possible, such as using the filesha1() function against the
    #       Terraform configuration file(s) or removing the .id references to
    #       calculate a hash against whole resources. Be aware that using whole
    #       resources will show a difference after the initial implementation.
    #       It will stabilize to only change when resources change afterwards.
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.eurovota_api_root.id,
      aws_api_gateway_resource.eurovota_api_login.id,
      aws_api_gateway_integration.test.id,
      aws_api_gateway_integration_response.example.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "eurovota_api_stage" {
  deployment_id = aws_api_gateway_deployment.eurovota_api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.eurovota_api.id
  stage_name    = "eurovota-test"
}
