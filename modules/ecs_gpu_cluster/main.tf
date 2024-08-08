# ECS GPU Instance Role
data "aws_iam_policy_document" "ecs_gpu_instance_role_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_gpu_instance_role" {
  name_prefix        = "${var.name_prefix}-ecs-gpu-instance-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_gpu_instance_role_assume_role_policy.json

  managed_policy_arns = [
    # "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess",
    "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role",
    "arn:aws:iam::aws:policy/AmazonElasticFileSystemFullAccess",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]
}

resource "aws_iam_instance_profile" "ecs_gpu_instance_profile" {
  name_prefix = "${var.name_prefix}-ecs-gpu-instance-profile"
  role        = aws_iam_role.ecs_gpu_instance_role.name
}

# ECS Task IAM Role
data "aws_iam_policy_document" "ecs_task_execution_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "ecs-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_role.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Security Group for EFS
resource "aws_security_group" "efs_security_group" {
  name_prefix = var.name_prefix
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    security_groups = [var.security_group_id]
  }

  tags = {
    Name = "${var.name_prefix} EFS"
  }
}

# Allow ecs_security_group egress to efs_security_group
resource "aws_security_group_rule" "ecs_to_efs_egress_rule" {
  type                     = "egress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.efs_security_group.id
  security_group_id        = var.security_group_id
}

# EFS File System
resource "aws_efs_file_system" "efs_file_system" {
  performance_mode = "generalPurpose"
  encrypted        = true

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = {
    Name = "${var.name_prefix} ECS Volumes"
  }
}

resource "aws_efs_mount_target" "efs_mount_target" {
  file_system_id  = aws_efs_file_system.efs_file_system.id
  subnet_id       = var.subnet_ids[0]
  security_groups = [aws_security_group.efs_security_group.id]
}

resource "aws_efs_access_point" "efs_access_point" {
  file_system_id = aws_efs_file_system.efs_file_system.id

  posix_user {
    uid = 1000
    gid = 1000
  }

  root_directory {
    path = "/ecs-volume-data"
    creation_info {
      owner_uid = 1000
      owner_gid = 1000
      permissions = "755"
    }
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "ecs_cluster" {
  name = "${var.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_launch_configuration" "ecs_gpu_launch_config" {
  name_prefix                 = "${var.name_prefix}-ecs-gpu-launch-config"
  image_id                    = local.ecs_gpu_ami_id
  instance_type               = var.gpu_instance_type
  iam_instance_profile        = aws_iam_instance_profile.ecs_gpu_instance_profile.name
  associate_public_ip_address = false

  user_data = <<-EOF
#!/bin/bash
echo ECS_CLUSTER=${aws_ecs_cluster.ecs_cluster.name} >> /etc/ecs/ecs.config
echo ECS_ENABLE_GPU_SUPPORT=true >> /etc/ecs/ecs.config
EOF

  root_block_device {
    encrypted = true
  }
}

# ECS GPU Auto Scaling Group
resource "aws_autoscaling_group" "ecs_gpu_asg" {
  name_prefix               = "${var.name_prefix}-ecs-gpu-asg"
  vpc_zone_identifier       = var.subnet_ids
  launch_configuration      = aws_launch_configuration.ecs_gpu_launch_config.name
  min_size                  = 1
  max_size                  = 1
  desired_capacity          = 1
  health_check_grace_period = 300
  health_check_type         = "EC2"

  lifecycle {
    create_before_destroy = true
  }
  tag {
    key                 = "Name"
    value               = "${var.name_prefix}-ecs-gpu-instance"
    propagate_at_launch = true
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "gpu_task_definition" {
  family                   = "gpu-task"
  requires_compatibilities = ["EC2"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 8192
  task_role_arn = aws_iam_role.ecs_task_execution_role.arn

  volume {
    name = "${var.name_prefix}-efs-volume"

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.efs_file_system.id
      transit_encryption = "ENABLED"

      authorization_config {
        access_point_id = aws_efs_access_point.efs_access_point.id
        iam             = "ENABLED"
      }
    }
  }

  container_definitions = var.container_definitions
}

# ECS Service
resource "aws_ecs_service" "gpu_service" {
  name            = "${var.name_prefix}-gpu-service"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.gpu_task_definition.arn
  desired_count   = 1
  launch_type     = "EC2"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [var.security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.lb_target_group_arn
    container_name   = "${var.name_prefix}-container"
    container_port   = 8080
  }
}