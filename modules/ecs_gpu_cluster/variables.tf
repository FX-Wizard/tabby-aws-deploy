variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "ecs-gpu"
}

variable "vpc_id" {
  description = "Id of existing VPC to deploy resources into"
  type        = string
}

variable "security_group_id" {
  description = "Id of Security group to attach to the ECS cluster"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet ids to deploy resources into"
  type        = list(string)
}

variable "gpu_instance_type" {
  description = "Select the GPU-enabled EC2 instance type for the ECS cluster"
  type        = string
}

variable "container_definitions" {
  description = "Container definitions for the ECS task"
  type        = string
}

variable "lb_target_group_arn" {
  description = "ARN of the load balancer target group"
  type        = string
}