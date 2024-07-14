resource "aws_api_gateway_rest_api" "eurovota_api" {
  name = "eurovota-api"
}

resource "aws_api_gateway_resource" "eurovota_api_root" {
  parent_id   = aws_api_gateway_rest_api.eurovota_api.root_resource_id
  path_part   = "eurovota-api"
  rest_api_id = aws_api_gateway_rest_api.eurovota_api.id
}

resource "aws_api_gateway_vpc_link" "eurovota_users_vpc_link" {
  name        = "eurovota-users-vpc-link"
  target_arns = [var.users_nlb_arn]
}

resource "aws_api_gateway_vpc_link" "eurovota_votes_vpc_link" {
  name        = "eurovota-votes-vpc-link"
  target_arns = [var.votes_nlb_arn]
}

module "auth" {
  source        = "./authorized"
  user_pool_arn = var.user_pool_arn
  rest_api_id   = aws_api_gateway_rest_api.eurovota_api.id
}

module "login" {
  source                  = "./login"
  parent_id               = aws_api_gateway_resource.eurovota_api_root.id
  rest_api_id             = aws_api_gateway_rest_api.eurovota_api.id
  protocol_type           = var.protocol_type
  users_nlb_dns           = var.users_nlb_dns
  eurovota_users_vpc_link = aws_api_gateway_vpc_link.eurovota_users_vpc_link.id
}

module "users" {
  source                  = "./users"
  parent_id               = aws_api_gateway_resource.eurovota_api_root.id
  rest_api_id             = aws_api_gateway_rest_api.eurovota_api.id
  protocol_type           = var.protocol_type
  users_nlb_dns           = var.users_nlb_dns
  eurovota_users_vpc_link = aws_api_gateway_vpc_link.eurovota_users_vpc_link.id
  authorizer_id           = module.auth.authorizer_id

}

module "votes" {
  source                  = "./votes"
  parent_id               = aws_api_gateway_resource.eurovota_api_root.id
  rest_api_id             = aws_api_gateway_rest_api.eurovota_api.id
  protocol_type           = var.protocol_type
  votes_nlb_dns           = var.votes_nlb_dns
  eurovota_votes_vpc_link = aws_api_gateway_vpc_link.eurovota_votes_vpc_link.id
  authorizer_id           = module.auth.authorizer_id
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
      var.redeploy,
      aws_api_gateway_resource.eurovota_api_root,
      module.login,
      module.users.registry_module,
      module.users.get_by_id_module,
      module.votes,
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
