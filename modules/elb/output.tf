output "elb_name" {
  description = "The name of the ELB"
  value       = aws_lb_target_group.users-tg2.name
}

output "elb_arn" {
  description = "The ARN of the ELB"
  value       = aws_lb_target_group.users-tg2.arn
}

output "elb_security_group_id" {
  description = "The ID of the security group of the ELB"
  value       = aws_security_group.euro-vota-sg.id
}

output "elb_dns_name" {
  description = "The DNS name of the ELB"
  value       = aws_lb.users-lb.dns_name
}

output "users_tg_arn" {
  description = "The arn of the users target group"
  value = aws_lb_target_group.users-tg2.arn
}

output "votes_tg_arn" {
  description = "The arn of the votes target group"
  value = aws_lb_target_group.votes-tg.arn
}

output "votes_nlb_dns_name" {
  description = "The DNS name of the NLB"
  value = aws_lb.votes-nlb.dns_name
}