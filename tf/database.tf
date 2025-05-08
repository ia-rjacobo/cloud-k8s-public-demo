######################################
# Create Database
######################################

resource "aws_security_group" "allow_aurora" {
  name        = "Aurora_sg"
  description = "Security group for RDS Aurora"
  vpc_id = aws_vpc.vpc.id
  
  ingress {
    description = "MYSQL/Aurora"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["${var.cidr_block}"]
  }
  
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "ignition-subnet-group"
  subnet_ids = [
    aws_subnet.private_subnet[0].id,
    aws_subnet.private_subnet[1].id,
    aws_subnet.private_subnet[2].id
  ]
  
  tags = {
    Name = "dbSubnetGroup"
  }
}

resource "aws_rds_cluster" "aurorards" {
  cluster_identifier     = "auroracluster"
  engine                 = "aurora-mysql"
  engine_version         = "5.7.mysql_aurora.2.12.0"
  database_name          = "DB"
  master_username        = "${var.db_username}"
  master_password        = "${var.db_password}"
  vpc_security_group_ids = [aws_security_group.allow_aurora.id]
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  storage_encrypted      = false
  skip_final_snapshot    = true
}

resource "aws_rds_cluster_instance" "cluster_instances" {
  identifier          = "aurorainstance"
  cluster_identifier  = aws_rds_cluster.aurorards.id
  instance_class      = "db.t3.medium"
  engine              = aws_rds_cluster.aurorards.engine
  engine_version      = aws_rds_cluster.aurorards.engine_version
  publicly_accessible = true
}

######################################
## Create CNAME Record - DB
######################################

resource "aws_route53_record" "db" {
  zone_id = var.vpc_zone_id
  name    = var.route53_db
  type    = "CNAME"
  ttl     = 5
  records = [aws_rds_cluster.aurorards.endpoint]
}