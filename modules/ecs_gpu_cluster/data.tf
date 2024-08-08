# Get Amazon Machine Image (AMI) ID for an Amazon ECS-optimized GPU AMI
data "aws_ssm_parameter" "ecs_gpu_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/gpu/recommended"
}

locals {
  ecs_gpu_ami_id = jsondecode(data.aws_ssm_parameter.ecs_gpu_ami.value)["image_id"]
}