output "vpc_id" {
  value = module.vpc.vpc_id
}

output "sg_id" {
  value = module.ec2.sg_id
}

output "ec2_id" {
  value = module.ec2.ec2_id
}

output "elb_dns_name" {
  value = module.elb.elb_dns_name
}

output "cognito_user_pool_id" {
  value = module.cognito.pool_id
}

