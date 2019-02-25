#################
#VARIABLES
#################

variable "aws_access_key" {}
variable "aws_secret_key" {}

variable "network_address_space" {
	default = "10.0.0.0/16"
}

variable "subnet1_address_space" {
	default = "10.0.1.0/24"
}

variable "subnet2_address_space" {
	default = "10.0.2.0/24"
}





#################
#PROVIDERS
#################

# Configure the AWS Provider
provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "us-west-1"
}

##################
#DATA
##################

data "aws_availability_zones" "available" {}


##################
#RESOURCES
##################

# NETWORKING #

resource "aws_vpc" "vpc" {
	cidr_block = "${var.network_address_space}"
}

resource "aws_internet_gateway" "igw" {
	vpc_id = "${aws_vpc.vpc.id}"
}

resource "aws_subnet" "subnet1" {
	cidr_block = "${var.subnet1_address_space}"
	vpc_id = "${aws_vpc.vpc.id}"
	availability_zone = "${data.aws_availability_zones.available.names[0]}"
}

resource "aws_subnet" "subnet2" {
	cidr_block = "${var.subnet2_address_space}"
	vpc_id = "${aws_vpc.vpc.id}"
	availability_zone = "${data.aws_availability_zones.available.names[0]}"
}

# ROUTING #

resource "aws_route_table" "ext_rtb" {
	vpc_id = "${aws_vpc.vpc.id}"
	
	route {
		cidr_block = "0.0.0.0/0"
		gateway_id = "${aws_internet_gateway.igw.id}"
	}
}

resource "aws_route_table" "int_rtb" {
	vpc_id = "${aws_vpc.vpc.id}"
	
	route {
		cidr_block = "10.0.0.0/16"
	}
}

resource "aws_route_table_association" "subnet1" {
	subnet_id = "${aws_subnet.subnet1.id}"
	route_table_id = "${aws_route_table.ext_rtb.id}"
}

resource "aws_route_table_association" "subnet2" {
	subnet_id = "${aws_subnet.subnet2.id}"
	route_table_id = "${aws_route_table.int_rtb.id}"
}

# SECURITY GROUPS #

resource "aws_security_group" "jen_test" {
	name = "jen_test"
	vpc_id = "${aws_vpc.vpc.id}"
	
	# SSH Access from All IP
	ingress {
		from_port = 22
		to_port = 22
		protocol = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}
	
	# Outbound access
	egress {
		from_port = 0
		to_port = 0
		protocol = "-1"
		cidr_blocks = ["0.0.0.0/0"]
	}
}

# INSTANCES #


resource "aws_instance" "master" {
	ami = "ami-0ac019f4fcb7cb7e6"
	instance_type = "t2.micro"
	subnet_id = "${aws_subnet.subnet1.id}"
	vpc_security_group_ids = ["${aws_security_group.jen_test.id}"]
}
	












