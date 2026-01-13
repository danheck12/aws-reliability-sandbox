terraform {
  backend "s3" {
    bucket         = "aws-reliability-sandbox-tfstate-812020187306-1768275824"
    key            = "aws-reliability-sandbox/staging/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "aws-reliability-sandbox-tflock"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-2"
}

locals {
  project = "aws-reliability-sandbox"
  env     = "staging"
  name    = "${local.project}-${local.env}"
}

# --- Networking ---
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.name
  cidr = "10.20.0.0/16"

  azs             = ["us-east-2a", "us-east-2b"]
  public_subnets  = ["10.20.0.0/24", "10.20.1.0/24"]
  private_subnets = ["10.20.10.0/24", "10.20.11.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
}

# --- ECS Cluster ---
resource "aws_ecs_cluster" "this" {
  name = local.name
}

# --- Cloud Map namespace for service discovery ---
resource "aws_service_discovery_private_dns_namespace" "ns" {
  name        = "${local.env}.${local.project}.local"
  description = "Service discovery namespace"
  vpc         = module.vpc.vpc_id
}

# --- ECR repos ---
resource "aws_ecr_repository" "api" {
  name = "${local.name}-api"
  image_scanning_configuration { scan_on_push = true }
}

# --- ALB Security Group ---
resource "aws_security_group" "alb_sg" {
  name        = "${local.name}-alb-sg"
  description = "ALB SG"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- ECS Tasks Security Group ---
resource "aws_security_group" "task_sg" {
  name        = "${local.name}-task-sg"
  description = "ECS tasks SG"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  # Prometheus -> API scrape
  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    self            = true
    description     = "Allow tasks to talk to each other"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- ALB ---
resource "aws_lb" "this" {
  name               = "${substr(local.name, 0, 32)}"
  load_balancer_type = "application"
  subnets            = module.vpc.public_subnets
  security_groups    = [aws_security_group.alb_sg.id]
}

resource "aws_lb_target_group" "api" {
  name        = "${substr(local.name, 0, 26)}-api"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"

  health_check {
    path                = "/healthz"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 15
    timeout             = 5
    matcher             = "200-399"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

# --- IAM for ECS task execution ---
resource "aws_iam_role" "ecs_task_execution" {
  name = "${local.name}-ecs-exec"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_exec_attach" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# --- CloudWatch Log Groups ---
resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/${local.name}/api"
  retention_in_days = 14
}

# --- Cloud Map service for API ---
resource "aws_service_discovery_service" "api" {
  name = "api"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.ns.id
    dns_records {
      ttl  = 10
      type = "A"
    }
    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

# --- ECS Task Definition (API) ---
resource "aws_ecs_task_definition" "api" {
  family                   = "${local.name}-api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([{
    name  = "api"
    image = "${aws_ecr_repository.api.repository_url}:latest"
    portMappings = [{ containerPort = 8080, hostPort = 8080, protocol = "tcp" }]
    environment = [
      { name = "ERROR_RATE", value = "0.0" },
      { name = "LATENCY_MS", value = "0" },
      { name = "JITTER_MS", value = "0" }
    ]
    logConfiguration = {
      logDriver = "awslogs",
      options = {
        awslogs-group         = aws_cloudwatch_log_group.api.name,
        awslogs-region        = "us-east-2",
        awslogs-stream-prefix = "ecs"
      }
    }
  }])
}

# --- ECS Service (API) ---
resource "aws_ecs_service" "api" {
  name            = "${local.name}-api"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = module.vpc.private_subnets
    security_groups  = [aws_security_group.task_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = "api"
    container_port   = 8080
  }

  service_registries {
    registry_arn = aws_service_discovery_service.api.arn
  }

  depends_on = [aws_lb_listener.http]
}

output "alb_dns" {
  value = aws_lb.this.dns_name
}

output "ecr_api" {
  value = aws_ecr_repository.api.repository_url
}
