######################################
## VPC Variables
######################################
variable "region" {
    default = "us-west-2"
}

variable "cidr_block" {
    default = "10.0.0.0/16"
}

variable "private_subnet" {
    type = list(string)
    default = ["10.0.1.0/24","10.0.2.0/24","10.0.3.0/24"]
    description = "private subnet"
}

variable "public_subnet" {
    type = list(string)
    default = ["10.0.5.0/24","10.0.6.0/24","10.0.7.0/24"]
    description = "Public subnet"
}

variable "azs" {
    type = list(string)
    description = "Availability Zones"
    default = [ "us-west-2a", "us-west-2b", "us-west-2c" ] 
}


######################################
## Domain Variables
######################################
variable "vpc_zone_id" {
    default = "Z067132213MFQ3U79GMJ1"
}

variable "route53_cert_domain_name" {
    default = "dev.demo.inductiveautomation.com"
}

variable "route53_fealb" {
    default = "us.dev.demo.inductiveautomation.com"
}

variable "route53_bealb" {
    default = "be.us.dev.demo.inductiveautomation.com"
}

variable "route53_db" {
    default = "db.us.dev.demo.inductiveautomation.com"
}

######################################
## ECR Variables
######################################
variable "ecr_repo" {
    default = "590183919098.dkr.ecr.us-west-2.amazonaws.com"
}

######################################
## Instance Variables
######################################
variable "linux_ami" {
    default = "ami-075686beab831bb7f"
}

variable "windows_ami" {
    default = "ami-005148a6a3abb558a"
}

variable "ec2_vol_size" {
    default = "50"
}


variable "enable_mgmt" {
  description = "Enable mgmt server"
  type        = bool
  default     = true
}

variable "mgmt_instance_count" {
  description = "Number of mgmt instances"
  type        = number
  default     = 1
}

######################################
## DB Variables
######################################
variable "db_username" {
    default = "ignition"
}

variable "enable_db" {
  description = "Enable blue environment"
  type        = bool
  default     = true
}
######################################
## Routing Traffic Distribution
######################################

variable "traffic_distribution" {
  description = "Levels of traffic distribution"
  type        = string
  default = "blue" 
    # green blue split blue-90 green-90
    # See routing weights section below
}

######################################
## Blue Variables
######################################
variable "enable_blue_env" {
  description = "Enable blue environment"
  type        = bool
  default     = false
}

variable "blue_instance_count" {
  description = "Number of instances in blue environment"
  type        = number
  default     = 1
}

variable "blues_instance_count" {
  description = "Number of additional instances in blue environment"
  type        = number
  default     = 2
}

variable "blue_agent_instance_count" {
  description = "Number of instances in blue environment"
  type        = number
  default     = 3
}
######################################
## Green Variables
######################################
variable "enable_green_env" {
  description = "Enable green environment"
  type        = bool
  default     = true
}

variable "green_instance_count" {
  description = "Number of instances in green environment"
  type        = number
  default     = 1
}

variable "greens_instance_count" {
  description = "Number of instances in green environment"
  type        = number
  default     = 2
}

variable "green_agent_instance_count" {
  description = "Number of instances in green environment"
  type        = number
  default     = 3
}
######################################
## Ticket Metadata
######################################
variable "ticket" {
    default = "cloud-1299"
}
variable "domain_name" {
    default = "dev.demo.inductiveautomation.com"
}
######################################
## Routing Weights 
######################################
locals {
  traffic_dist_map = {
    blue = {
      blue  = 100
      green = 0
    }
    blue-90 = {
      blue  = 90
      green = 10
    }
    split = {
      blue  = 50
      green = 50
    }
    green-90 = {
      blue  = 10
      green = 90
    }
    green = {
      blue  = 0
      green = 100
    }
  }
}
