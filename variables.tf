variable "aws_region" {
  description = "The AWS region to deploy resources"
  type        = string
}

variable "vpc_id" {
  description = "Id of existing VPC to deploy resources into"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet ids to deploy resources into"
  type        = list(string)
}

variable "gpu_instance_type" {
  description = "Select the GPU-enabled EC2 instance type for the ECS cluster"
  type        = string
  default     = "g4dn.2xlarge"
  
  validation {
    condition     = contains(["p3.2xlarge", "p3.8xlarge", "p3.16xlarge", "g4dn.xlarge", "g4dn.2xlarge", "g4dn.4xlarge", "g4dn.8xlarge", "g4dn.16xlarge", "g5.xlarge", "g5.2xlarge", "g5.4xlarge", "g5.8xlarge", "g5.16xlarge"], var.gpu_instance_type)
    error_message = "Invalid GPU instance type. Please select a valid GPU-enabled instance type."
  }
}

variable "name_prefix" {
  description = "A prefix to add to resources"
  type        = string
  default     = "tabby"
}

# Loadbalancer variables
# Domain name required for SSL certificate generation
variable "is_public" {
  description = "Whether the App should be public or not"
  type        = bool
  default     = false
}

variable "domain_name" {
  description = "The domain name to use for the App. Only needed if public"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet ids to deploy load balancer into. Only needed if public"
  type        = list(string)
}

variable "acm_certificate_arn" {
  description = "ARN of the ACM certificate to use for the load balancer. Only needed if public"
  type        = string
}

# Tabby variables
variable "tabby_model" {
  description = "Code completion AI model to use with Tabby"
  type        = string
  default     = "StarCoder-1B"
}

variable "tabby_chat_model" {
  description = "Chat AI model to use with Tabby"
  type        = string
  default     = "Qwen2-1.5B-Instruct"
}

variable "tabby_port" {
  description = "Port on which Tabby server is running"
  type        = number
  default     = 8080
}