variable "users_nlb_arn" {
  description = "The ARN of the users NLB"
}

variable "users_nlb_dns" {
    description = "The DNS name of the users NLB"
}

variable "protocol_type" {
  description = "The type of connection"
  default = "http://"
}

variable "user_pool_arn" {
    description = "The ARN of the user pool"
}

variable "redeploy" {
    description = "Change this to redeploy the API Gateway resources"
    default = false
}
