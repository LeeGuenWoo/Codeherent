provider "aws" {
  region     = "ap-northeast-2"
}

# vpc module을 정의한다.
module "vpc" {
  # source는 variables.tf, main.tf, outputs.tf 파일이 위치한 디렉터리 경로를 넣어준다.
  source = "./modules/vpc"

  # VPC이름을 넣어준다. 이 값은 VPC module이 생성하는 모든 리소스 이름의 prefix가 된다.
  name = "test"
  # VPC의 CIDR block을 정의한다.
  cidr = "172.17.0.0/16"

  # VPC가 사용할 AZ를 정의한다.
  azs              = ["ap-northeast-2a", "ap-northeast-2c"]
  # VPC의 Public Subnet CIDR block을 정의한다.
  public_subnets   = ["172.17.1.0/24", "172.17.2.0/24"]
  # VPC의 Private WEB Subnet CIDR block을 정의한다.
  private_web_subnets  = ["172.17.3.0/24", "172.17.4.0/24"]
  # VPC의 Private LB Subnet CIDR block을 정의한다. (private LB를 사용하지 않으면 이 라인은 필요없다.)
  private_lb_subnets  = ["172.17.5.0/24", "172.17.6.0/24"]
  # VPC의 Private WAS Subnet CIDR block을 정의한다. (was subnet을 사용하지 않으면 이 라인은 필요없다.)
  private_was_subnets  = ["172.17.7.0/24", "172.17.8.0/24"]
  # VPC의 Private DB Subnet CIDR block을 정의한다. (RDS를 사용하지 않으면 이 라인은 필요없다.)
  database_subnets = ["172.17.9.0/24", "172.17.10.0/24"]

  # VPC module이 생성하는 모든 리소스에 기본으로 입력될 Tag를 정의한다.
  tags = {
    "TerraformManaged" = "true"
  }
}

################
# pulbic LB용 SG
################

resource "aws_security_group" "public-lb-sg" {
  name = "public-lb-sg"
  description = "Security Group for Public LB"
  vpc_id      = module.vpc.vpc_id  

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
      Name = "public-lb-sg"
    }  
}

resource "aws_security_group_rule" "public-lb-sg-http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "TCP"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.public-lb-sg.id

  lifecycle { create_before_destroy = true }
}

resource "aws_security_group_rule" "public-lb-sg-https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "TCP"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.public-lb-sg.id

  lifecycle { create_before_destroy = true }
}

resource "aws_acm_certificate" "cert" {
  domain_name       = var.service_domain
  validation_method = "EMAIL"
}

resource "aws_acm_certificate_validation" "cert" {
  certificate_arn = aws_acm_certificate.cert.arn
}

# resource "aws_lb" "test" {
#   name               = "test-lb-tf"
#   internal           = false
#   load_balancer_type = "network"  
  
#   subnets            = module.vpc.public_subnets_ids 

#   enable_deletion_protection = true

#   tags = {
#     Environment = "production"
#   }
# }

# public ALB module을 정의한다.
module "public-alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 5.0"

  name = "my-public-alb"  
  #name_prefix = "alb#1"

  load_balancer_type = "application"

  vpc_id             = module.vpc.vpc_id
  subnets            = module.vpc.public_subnets_ids  
  security_groups    = [aws_security_group.public-lb-sg.id]

  # access_logs = {
  #   bucket = "my-alb-logs"
  # }

  target_groups = [
    {
      name_prefix      = "default"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "instance"
    }
  ]

  https_listeners = [
    {
      port               = 443
      protocol           = "HTTPS"
      certificate_arn    = aws_acm_certificate.cert.arn
      target_group_index = 0
    }
  ]

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    }
  ]

  tags = {
    Environment = "Test"
  }
}