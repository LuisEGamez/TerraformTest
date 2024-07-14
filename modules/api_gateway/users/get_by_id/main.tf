resource "aws_api_gateway_resource" "eurovota_api_id_get_by_id" {
  parent_id   = var.parent_id
  path_part   = "id"
  rest_api_id = var.rest_api_id

}

resource "aws_api_gateway_resource" "eurovota_api_get_by_id" {
  parent_id   = aws_api_gateway_resource.eurovota_api_id_get_by_id.id
  path_part   = "{userId}"
  rest_api_id = var.rest_api_id

}


resource "aws_api_gateway_method" "get_method" {
  authorization = "COGNITO_USER_POOLS"
  http_method   = "GET"
  resource_id   = aws_api_gateway_resource.eurovota_api_get_by_id.id
  rest_api_id   = var.rest_api_id
  //"authorization_scopes": [],
  authorizer_id = var.authorizer_id
  request_parameters = {
    "method.request.header.Authorization" : true,
    "method.request.path.userId" : true
  }
}

resource "aws_api_gateway_integration" "get_integration" {
  rest_api_id = var.rest_api_id
  resource_id = aws_api_gateway_resource.eurovota_api_get_by_id.id
  http_method = aws_api_gateway_method.get_method.http_method

  type                    = "HTTP"
  uri                     = "${var.protocol_type}${var.users_nlb_dns}/${var.parent_path}/${aws_api_gateway_resource.eurovota_api_id_get_by_id.path_part}/${aws_api_gateway_resource.eurovota_api_get_by_id.path_part}"
  integration_http_method = "GET"
  passthrough_behavior    = "WHEN_NO_MATCH"
  //content_handling        = "CONVERT_TO_TEXT"

  connection_type = "VPC_LINK"
  connection_id   = var.eurovota_users_vpc_link


  cache_key_parameters = [
    "integration.request.header.Authorization",
    "method.request.header.Authorization"
  ]
  request_parameters = {
    "integration.request.header.Authorization" : "method.request.header.Authorization",
    "integration.request.path.userId" : "method.request.path.userId"
  }
}

resource "aws_api_gateway_method_response" "get_response_200" {

  http_method = aws_api_gateway_method.get_method.http_method
  resource_id = aws_api_gateway_resource.eurovota_api_get_by_id.id
  rest_api_id = var.rest_api_id
  status_code = "200"
  response_models = {
    "application/json" : "Empty"
  }

}

resource "aws_api_gateway_integration_response" "get_integration_response_200" {
  http_method = aws_api_gateway_method.get_method.http_method
  resource_id = aws_api_gateway_resource.eurovota_api_get_by_id.id
  response_templates = {
    "application/json" : ""
  }
  rest_api_id = var.rest_api_id
  status_code = aws_api_gateway_method_response.get_response_200.status_code
}

resource "aws_api_gateway_method_response" "get_response_400" {

  http_method = aws_api_gateway_method.get_method.http_method
  resource_id = aws_api_gateway_resource.eurovota_api_get_by_id.id
  rest_api_id = var.rest_api_id
  status_code = "400"
  response_models = {
    "application/json" : "Empty"
  }

}

resource "aws_api_gateway_integration_response" "get_integration_response_400" {
  http_method = aws_api_gateway_method.get_method.http_method
  resource_id = aws_api_gateway_resource.eurovota_api_get_by_id.id
  response_templates = {
    "application/json" : ""
  }
  rest_api_id       = var.rest_api_id
  status_code       = aws_api_gateway_method_response.get_response_400.status_code
  selection_pattern = "4\\d{2}"
}



