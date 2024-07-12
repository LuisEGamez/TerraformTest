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