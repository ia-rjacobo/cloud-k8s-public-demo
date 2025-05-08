######################################
## Create EC2 Roles
######################################
resource "aws_iam_role" "instance_role" {
  name = "SSMRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
         }
        Action = "sts:AssumeRole"
      }
    ]
 })
}

resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ecr_attach" {
  role       = aws_iam_role.instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "secrets_manager_attach" {
  role       = aws_iam_role.instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}

resource "aws_iam_instance_profile" "iam_ssm_profile" {
  name = "iam_ssm_profile"
  role = "${aws_iam_role.instance_role.name}"
}




######################################
## Create Random string(s)
######################################
resource "random_string" "random" {
  length           = 12
  special          = true
  override_special = "-"
}


######################################
## Create Instance(s) SG
######################################
resource "aws_security_group" "instance_sg_group" {
    name = "instance_sg_group"
    description = "Security group"
    vpc_id = aws_vpc.vpc.id

    ingress {
        description = "security group"
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["${var.cidr_block}"]
    }
    ingress {
        description = "security group"
        from_port = 1080
        to_port = 1080
        protocol = "tcp"
        cidr_blocks = ["${var.cidr_block}"]
    }
    ingress {
        description = "security group"
        from_port = 8080
        to_port = 8080
        protocol = "tcp"
        cidr_blocks = ["${var.cidr_block}"]
    }
    ingress {
        description = "security group"
        from_port = 8088
        to_port = 8088
        protocol = "tcp"
        cidr_blocks = ["${var.cidr_block}"]
    }
ingress {
        description = "security group"
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["${var.private_subnet[0]}","${var.private_subnet[1]}","${var.private_subnet[2]}"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
        ipv6_cidr_blocks = [ "::/0" ]
    }

}


######################################
## Create EC2 Instance(s) mangement linux
######################################

resource "aws_instance" "linux-management" {
    count = var.enable_mgmt ? var.mgmt_instance_count : 0
    ami = "${var.linux_ami}"
    subnet_id = aws_subnet.private_subnet[0].id
    associate_public_ip_address = false
    #security_groups = [aws_security_group.instance_sg_group.id]
    vpc_security_group_ids = [aws_security_group.instance_sg_group.id]
    instance_type = "t3.medium"
    iam_instance_profile = "${aws_iam_instance_profile.iam_ssm_profile.name}"
    root_block_device {
      delete_on_termination = true
      encrypted             = true
      volume_type           = "gp3"
      volume_size           = "${var.ec2_vol_size}"
    }
    user_data = file("userdata/userdata-linux-mgmt.txt")

  tags = {
    Name = "linux-management"
    Orchestrator = "terraform"
    Ticket = "${var.ticket}"
  }

}




######################################
## Create EC2 Instance(s) mangement windows
######################################
resource "aws_instance" "windows-management" {
    count = var.enable_mgmt ? var.mgmt_instance_count : 0
    ami = "${var.windows_ami}"
    subnet_id = aws_subnet.private_subnet[0].id
    associate_public_ip_address = false
    vpc_security_group_ids = [aws_security_group.instance_sg_group.id]
    instance_type = "t3.medium"
    iam_instance_profile = "${aws_iam_instance_profile.iam_ssm_profile.name}"
    root_block_device {
      delete_on_termination = true
      encrypted             = true
      volume_type           = "gp3"
      volume_size           = "${var.ec2_vol_size}"
    }
    user_data = file("userdata/userdata-windows-mgmt.txt")

  tags = {
    Name = "windows-management"
    Orchestrator = "terraform"
    Ticket = "${var.ticket}"
  }

}