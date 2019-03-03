#################
#VARIABLES
#################

variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "private_key_path" {}
variable "key_name" {}

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
  region     = "us-east-1"
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

	tags = {
    Name = "Jenkins_VPC"
  }
}

resource "aws_internet_gateway" "igw" {
	vpc_id = "${aws_vpc.vpc.id}"
}

resource "aws_subnet" "ext_subnet1" {
	cidr_block = "${var.subnet1_address_space}"
	vpc_id = "${aws_vpc.vpc.id}"
	map_public_ip_on_launch = "true"
	availability_zone = "${data.aws_availability_zones.available.names[0]}"
	tags = {
    Name = "External Subnet_1"
  }
}

resource "aws_subnet" "int_subnet2" {
	cidr_block = "${var.subnet2_address_space}"
	vpc_id = "${aws_vpc.vpc.id}"
	availability_zone = "${data.aws_availability_zones.available.names[0]}"
	tags = {
    Name = "Internal Subnet_2"
  }
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
	subnet_id = "${aws_subnet.ext_subnet1.id}"
	route_table_id = "${aws_route_table.ext_rtb.id}"
}

resource "aws_route_table_association" "subnet2" {
	subnet_id = "${aws_subnet.int_subnet2.id}"
	route_table_id = "${aws_route_table.ext_rtb.id}"
}

# SECURITY GROUPS #

resource "aws_security_group" "19_Feb_SG" {
	name = "19_Feb_SG"
	vpc_id = "${aws_vpc.vpc.id}"
	
	# SSH Access from All IP
	ingress {
		from_port = 22
		to_port = 22
		protocol = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}
	
	# Pport 8080 for Jenkins
	ingress {
		from_port = 8080
		to_port = 8080
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
	subnet_id = "${aws_subnet.ext_subnet1.id}"
	vpc_security_group_ids = ["${aws_security_group.19_Feb_SG.id}"]
	key_name = "${var.key_name}"

    connection {
      user = "ubuntu"
      private_key = "${file(var.private_key_path)}"
    }

    provisioner "remote-exec" {
        inline = [
        "wget -q -O - https://pkg.jenkins.io/debian/jenkins-ci.org.key | sudo apt-key add -",
        "sudo sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'",
				"sudo add-apt-repository --yes ppa:webupd8team/java",
        "sudo apt-get --yes update",
				"sudo apt install --yes openjdk-8-jre",
        "sudo apt-get install --yes jenkins",
				"sudo cp /var/lib/jenkins/secrets/initialAdminPassword initialAdminPasswordCP"
        ]
    }

# Trying to get script output into data

    #data "external" "jenkins_init_pass" {
     #   program = ["sh", "sudo cat /var/lib/jenkins/secrets/initialAdminPassword"]
    #}
    #data "external" "master_node_ip" {
    #    program = ["sudo sh", "curl https://ident.me"]
   #}
}

#########
# OUTPUT
#########

output "master_node_ip" {
        value = "${aws_instance.master.public_ip}"
    }


#output "jekins_init_pass" {
#    value = "${aws_instance.master.external.jenkins_init_pass}"
#}

output "aws_instance_public_dns" {
    value = "${aws_instance.master.public_dns}"
}









