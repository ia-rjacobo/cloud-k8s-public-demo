######################################
## Create EC2 Instance(s) node01
######################################

resource "aws_instance" "green" {
    count = var.enable_green_env ? var.green_instance_count : 0
    ami = "${var.linux_ami}"
    subnet_id = aws_subnet.private_subnet[0].id
    associate_public_ip_address = false
    #security_groups = [aws_security_group.instance_sg_group.id]
    vpc_security_group_ids = [aws_security_group.instance_sg_group.id]
    instance_type = "m5.large"
    iam_instance_profile = "${aws_iam_instance_profile.iam_ssm_profile.name}"
    root_block_device {
      delete_on_termination = true
      encrypted             = true
      volume_type           = "gp3"
      volume_size           = "${var.ec2_vol_size}"
    }
    user_data = <<-OUTEREOF
#!/bin/bash
sudo apt update && sudo apt install wget vim curl -y
sudo hostnamectl set-hostname g-server0${count.index+1}

mkdir -p /etc/rancher/rke2/
echo "token: my-shared-secret" > /etc/rancher/rke2/config.yaml
echo "enable-servicelb: true" >> /etc/rancher/rke2/config.yaml
echo "tls-san:" >> /etc/rancher/rke2/config.yaml
echo "  - demo.inductiveautomation.com" >> /etc/rancher/rke2/config.yaml
echo "cluster-domain:" >> /etc/rancher/rke2/config.yaml
echo "  - dev.demo.cluster.local" >> /etc/rancher/rke2/config.yaml
curl -sfL https://get.rke2.io | sh -
systemctl enable rke2-server.service
systemctl start rke2-server.service

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Copy Config
mkdir -p /root/.kube
cp /etc/rancher/rke2/rke2.yaml /root/.kube/config

sudo snap install aws-cli --classic
sudo snap install powershell --classic

OUTEREOF

  tags = {
    Name = "g-server0${count.index+1}"
    Orchestrator = "terraform"
    Ticket = "${var.ticket}"
  }

}


######################################
## Create Additional EC2 Instance(s)
######################################

resource "aws_instance" "greens" {
    depends_on = [
    aws_instance.green
    ]
    count = var.enable_green_env ? var.greens_instance_count : 0
    ami = "${var.linux_ami}"
    subnet_id = aws_subnet.private_subnet[0].id
    associate_public_ip_address = false
    #security_groups = [aws_security_group.instance_sg_group.id]
    vpc_security_group_ids = [aws_security_group.instance_sg_group.id]
    instance_type = "m5.large"
    iam_instance_profile = "${aws_iam_instance_profile.iam_ssm_profile.name}"
    root_block_device {
      delete_on_termination = true
      encrypted             = true
      volume_type           = "gp3"
      volume_size           = "${var.ec2_vol_size}"
    }
    user_data = <<-OUTEREOF
#!/bin/bash
sudo apt update && sudo apt install wget vim curl -y
sudo hostnamectl set-hostname g-server0${count.index+1}

#!/bin/bash
sudo apt update && sudo apt install wget vim curl -y
sudo hostnamectl set-hostname b-server0${count.index+2}

mkdir -p /etc/rancher/rke2/
echo "token: my-shared-secret" > /etc/rancher/rke2/config.yaml
echo "enable-servicelb: true" >> /etc/rancher/rke2/config.yaml
echo "server: https://${aws_instance.green[0].private_ip}:9345" >> /etc/rancher/rke2/config.yaml
echo "tls-san:" >> /etc/rancher/rke2/config.yaml
echo "  - demo.inductiveautomation.com" >> /etc/rancher/rke2/config.yaml
echo "cluster-domain:" >> /etc/rancher/rke2/config.yaml
echo "  - dev.demo.cluster.local" >> /etc/rancher/rke2/config.yaml
curl -sfL https://get.rke2.io | sh -
systemctl enable rke2-server.service
systemctl start rke2-server.service

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Copy Config
mkdir -p /root/.kube
cp /etc/rancher/rke2/rke2.yaml /root/.kube/config

sudo snap install aws-cli --classic
sudo snap install powershell --classic


OUTEREOF

  tags = {
    Name = "g-server0${count.index+2}"
    Orchestrator = "terraform"
    Ticket = "${var.ticket}"
  }


}



######################################
## Create Additional EC2 Instance(s)
######################################

resource "aws_instance" "green-agent" {
    depends_on = [
    aws_instance.green
    ]
    count = var.enable_green_env ? var.green_agent_instance_count : 0
    ami = "${var.linux_ami}"
    subnet_id = aws_subnet.private_subnet[0].id
    associate_public_ip_address = false
    #security_groups = [aws_security_group.instance_sg_group.id]
    vpc_security_group_ids = [aws_security_group.instance_sg_group.id]
    instance_type = "m5.xlarge"
    iam_instance_profile = "${aws_iam_instance_profile.iam_ssm_profile.name}"
    root_block_device {
      delete_on_termination = true
      encrypted             = true
      volume_type           = "gp3"
      volume_size           = "${var.ec2_vol_size}"
    }
    user_data = <<-OUTEREOF
#!/bin/bash
sudo apt update && sudo apt install wget vim curl -y
sudo hostnamectl set-hostname g-agent0${count.index+1}

mkdir -p /etc/rancher/rke2/
echo "server: https://${aws_instance.blue[0].private_ip}:9345" > /etc/rancher/rke2/config.yaml
echo "token: my-shared-secret" >> /etc/rancher/rke2/config.yaml

curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE="agent" sh -
systemctl enable rke2-agent.service
systemctl start rke2-agent.service


sudo snap install aws-cli --classic
sudo snap install powershell --classic

OUTEREOF

  tags = {
    Name = "g-agent0${count.index+1}"
    Orchestrator = "terraform"
    Ticket = "${var.ticket}"
  }


}

######################################
## ALB
######################################
resource "aws_lb_target_group" "green" { // Target Group Green
 name     = "target-group-green"
 port     = 1080
 protocol = "HTTP"
 vpc_id   = aws_vpc.vpc.id
 load_balancing_algorithm_type = "round_robin"
 stickiness {
   enabled = true
   type    = "lb_cookie"
   cookie_duration = "86400"
  }
 health_check {
   #path = "/StatusPing"
   path = "/"
   port = 1080
   healthy_threshold = 2
   unhealthy_threshold = 2
   timeout = 2
   interval = 5
   matcher = "200,301,302"  # has to be HTTP 200 or fails
 }
}

resource "aws_lb_target_group_attachment" "tg_attachment_green" {
count            = length(aws_instance.green)
 target_group_arn = aws_lb_target_group.green.arn
 target_id        = aws_instance.green[count.index].id
 port             = 1080
}

resource "aws_lb_target_group_attachment" "tg_attachment_greens" {
count = var.enable_green_env ? var.greens_instance_count : 0
 target_group_arn = aws_lb_target_group.green.arn
 target_id        = aws_instance.greens[count.index].id
 port             = 1080
}

resource "aws_lb_target_group_attachment" "tg_attachment_green_agent" {
count = var.enable_green_env ? var.green_agent_instance_count : 0
 target_group_arn = aws_lb_target_group.green.arn
 target_id        = aws_instance.green-agent[count.index].id
 port             = 1080
}
