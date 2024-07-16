resource "aws_api_gateway_resource" "eurovota_api_votes" {
  parent_id   = var.parent_id
  path_part   = "votes"
  rest_api_id = var.rest_api_id
}

resource "aws_api_gateway_model" "vote_model" {
  rest_api_id  = var.rest_api_id
  name         = "vote"
  content_type = "application/json"
  schema       = <<EOF
{
  "$schema": "http://json-schema.org/draft-04/schema#",
  "title": "VoteRequest",
  "type": "object",
  "properties": {
    "countryName": {
      "type": "string",
      "minLength": 1,
      "maxLength": 50
    },
    "voteValue": {
      "type": "number"
    }
  },
  "required": ["countryName", "voteValue"],
  "additionalProperties": false
}
EOF
}

resource "aws_api_gateway_method" "vote_method" {
  authorization = "COGNITO_USER_POOLS"
  http_method   = "POST"
  resource_id   = aws_api_gateway_resource.eurovota_api_votes.id
  rest_api_id   = var.rest_api_id
  authorizer_id = var.authorizer_id

  request_parameters = {
    "method.request.header.Authorization" : true,
    "method.request.path.userId" : true
  }
  request_models = {
    "application/json" = aws_api_gateway_model.vote_model.name
  }
}

resource "aws_api_gateway_integration" "vote_integration" {
  rest_api_id = var.rest_api_id
  resource_id   = aws_api_gateway_resource.eurovota_api_votes.id
  http_method = aws_api_gateway_method.vote_method.http_method

  type                    = "HTTP"
  uri                     = "${var.protocol_type}${var.votes_nlb_dns}/${aws_api_gateway_resource.eurovota_api_votes.path_part}"
  integration_http_method = "POST"
  passthrough_behavior    = "WHEN_NO_TEMPLATES"
  content_handling        = "CONVERT_TO_TEXT"

  connection_type = "VPC_LINK"
  connection_id   = var.eurovota_votes_vpc_link

  cache_key_parameters = [
    "integration.request.header.Authorization",
    "method.request.header.Authorization"
  ]
  request_parameters = {
    "integration.request.header.Authorization" : "method.request.header.Authorization"
  }
}

resource "aws_api_gateway_method_response" "vote_response_200" {

  http_method = aws_api_gateway_method.vote_method.http_method
  resource_id   = aws_api_gateway_resource.eurovota_api_votes.id
  rest_api_id = var.rest_api_id
  status_code = "200"
  response_models = {
    "application/json" : "Empty"
  }

  response_parameters = {
    "method.response.header.Location" : true
  }

}

resource "aws_api_gateway_integration_response" "vote_integration_response_200" {
  http_method = aws_api_gateway_method.vote_method.http_method
  resource_id   = aws_api_gateway_resource.eurovota_api_votes.id
  response_templates = {
    "application/json" : ""
  }
  rest_api_id = var.rest_api_id
  status_code = aws_api_gateway_method_response.vote_response_200.status_code

  response_parameters = {
    "method.response.header.Location" : "integration.response.header.Location"

  }
}

resource "aws_api_gateway_method_response" "vote_response_400" {

  http_method = aws_api_gateway_method.vote_method.http_method
  resource_id   = aws_api_gateway_resource.eurovota_api_votes.id
  rest_api_id = var.rest_api_id
  status_code = "400"
  response_models = {
    "application/json" : "Empty"
  }

}

resource "aws_api_gateway_integration_response" "vote_integration_response_400" {
  http_method = aws_api_gateway_method.vote_method.http_method
  resource_id   = aws_api_gateway_resource.eurovota_api_votes.id
  response_templates = {
    "application/json" : ""
  }
  rest_api_id = var.rest_api_id
  status_code = aws_api_gateway_method_response.vote_response_400.status_code
  selection_pattern = "4\\d{2}"
}



