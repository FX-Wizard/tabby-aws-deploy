module "ecs_gpu_cluster" {
  source                = "./modules/ecs_gpu_cluster"
  name_prefix           = var.name_prefix
  vpc_id                = var.vpc_id
  subnet_ids            = var.subnet_ids
  gpu_instance_type     = var.gpu_instance_type
  security_group_id     = aws_security_group.ecs_security_group.id
  lb_target_group_arn   = aws_lb_target_group.target_group.arn
  container_name        = "tabby-container"
  container_definitions = <<DEFINITION
[
  {
    "name": "tabby-container",
    "image": "tabbyml/tabby",
    "resourceRequirements": [
      {
        "type": "GPU",
        "value": "1"
      }
    ],
    "command": [
      "serve", "--model", "${var.tabby_model}", "--chat-model", "${var.tabby_chat_model}", "--device", "cuda"
    ],
    "portMappings": [
      {
        "containerPort": 8080,
        "hostPort": 8080
      }
    ],
    "mountPoints": [
      {
        "sourceVolume": "tabby-efs-volume",
        "containerPath": "/data"
      }
    ]
  }
]
DEFINITION
}

# Security Group for ECS
resource "aws_security_group" "ecs_security_group" {
  name_prefix = "tabbyml"
  description = "${var.name_prefix} ECS Security Group"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "Tabby ML"
  }
}

# Allow egress to internet for downloading AI models
resource "aws_security_group_rule" "ecs_egress_rule_http" {
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ecs_security_group.id
}

resource "aws_security_group_rule" "ecs_egress_rule_https" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ecs_security_group.id
}

# Create Application Load Balancer
resource "aws_lb" "load_balancer" {
  count              = var.is_public ? 0 : 1
  name_prefix        = var.name_prefix
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ecs_security_group.id]
  subnets            = var.subnet_ids
}

# Associate the target group with the load balancer
resource "aws_lb_listener" "listener" {
  count              = var.is_public ? 0 : 1
  load_balancer_arn = aws_lb.load_balancer[0].arn
  port              = 8080
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.arn
  }
}

# Security Group for ECS
resource "aws_security_group" "public_alb_security_group" {
  name_prefix = "${var.name_prefix}-alb"
  description = "${var.name_prefix} ALB Security Group"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "Tabby ML ALB"
  }
}

# Allow egress to internet for downloading AI models
resource "aws_security_group_rule" "alb_egress_rule" {
  type                     = "egress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs_security_group.id
  security_group_id        = aws_security_group.public_alb_security_group.id
}

# Public ALB
resource "aws_lb" "public_lb" {
  count              = var.is_public ? 1 : 0
  name               = "${var.name_prefix}-public-lb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.public_alb_security_group.id]
  subnets            = var.public_subnet_ids
}

resource "aws_lb_listener" "public_listener" {
  count             = var.is_public ? 1 : 0
  load_balancer_arn = aws_lb.public_lb[0].arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.arn
  }
}

# Load Balancer Target Group
resource "aws_lb_target_group" "target_group" {
  name_prefix = var.name_prefix
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path = "/"
  }
}
