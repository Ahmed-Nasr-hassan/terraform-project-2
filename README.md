# terraform project 2

## problem description

![Alt text](./photos/problem-description.png?raw=true "Title")

## global configuration

### global configuration/main.tf

```bash
    resource "aws_s3_bucket" "terraform-state"
    resource "aws_s3_bucket_versioning" "s3-enable-versioning"
    resource "aws_dynamodb_table" "terraform-lock-table" 

```

### global configuration/variables.tf

```bash
    variable "s3-bucket-name"
    variable "versioning-status"
    variable "dynamodb-table-name" 
    variable "dynamodb-billing-mode"
    variable "dynamodb-hash-key"
    variable "string-attribute"
```

### global-config.tf

```bash
    provider "aws" {
    shared_credentials_files = ["~/.aws/credentials"]
    shared_config_files = ["~/.aws/config"]
    region = var.selected-region
    }

    module "create-global-config-resources" {
    source = "./global-config-resources"
    s3-bucket-name = var.s3-bucket-name
    dynamodb-table-name = var.dynamodb-table-name
    }

    terraform {
        backend "s3" {
            bucket = "nasr-terraform-state-file"
            key = "dev/terraform.tfstate"
            region = "us-east-1"
            dynamodb_table = "terraform-state-lock-tracker"
            encrypt = true
        }
    }
```

### inputs.auto.tfvars global configuration part

```bash

    selected-region = "us-east-1"
    s3-bucket-name = "nasr-terraform-state-file"
    dynamodb-table-name = "terraform-state-lock-tracker"
    bucket-key = "dev/terraform.tfstate"

```

---

## vpc

### vpc/main.tf

```bash

    resource "aws_vpc" "nasr-vpc"
    resource "aws_subnet" "nasr-subnet"
    resource "aws_internet_gateway" "nasr-gateway"
    resource "aws_eip" "nasr-eip"
    resource "aws_nat_gateway" "nasr-nat-gtw"
    resource "aws_route_table" "nasr-route-table-public"
    resource "aws_route_table" "nasr-route-table-private" 
    resource "aws_route_table_association" "rt-associate-public"
    resource "aws_route_table_association" "rt-associate-private"

```
### vpc/variables.tf

```bash

    variable "vpc_cidr_block" 
    variable "subnet_cidr_blocks" 
    variable "allow_all_ipv4_cidr_blocks" 
    variable "allow_all_ipv6_cidr_blocks" 
    variable "public-subnet-key-to-nat" 
    variable "keys-of-public-subnets" 
    variable "keys-of-private-subnets" 
    variable "subnet_types" 

```

### vpc/outputs.tf

```bash
    output "nasr-vpc-id"
    output "public_subnet_ids" 
    output "private_subnet_ids" 

```

### main.tf vpc part

```bash
    module "creating-vpc-components" {
    source = "./vpc-components"
    vpc_cidr_block = var.vpc_cidr_block
    subnet_cidr_blocks = var.subnet_cidr_blocks
    public-subnet-key-to-nat = var.public-subnet-key-to-nat
    keys-of-public-subnets = var.keys-of-public-subnets
    keys-of-private-subnets = var.keys-of-private-subnets
    subnet_types =  var.subnet_types
    }

```

### inputs.auto.tfvars vpc part

```bash
    vpc_cidr_block = "10.0.0.0/16"
    subnet_cidr_blocks = {
        "10.0.0.0/24"="us-east-1a",
        "10.0.2.0/24"="us-east-1b",
        "10.0.1.0/24"="us-east-1a",
        "10.0.3.0/24"="us-east-1b",
    }
    subnet_types = {
        "10.0.0.0/24"="public",
        "10.0.2.0/24"="public",
        "10.0.1.0/24"="private",
        "10.0.3.0/24"="private",
    }
    public-subnet-key-to-nat = "10.0.0.0/24"
    keys-of-public-subnets = ["10.0.0.0/24","10.0.2.0/24"]
    keys-of-private-subnets = ["10.0.1.0/24","10.0.3.0/24"]

```

---

## ec2

### ec2/main.tf

```bash

    data "aws_ami" "ubuntu" 
    resource "aws_security_group" "nasrsg"

    resource "aws_instance" "nasr-ec2" {
    ami = coalesce(var.ec2-ami, data.aws_ami.ubuntu.id)
    instance_type = var.instance_type
    subnet_id = var.subnet_id
    associate_public_ip_address = var.is_public
    vpc_security_group_ids = [aws_security_group.nasrsg.id]
    key_name = var.key-name

    provisioner "local-exec" {
        command = var.is_public ? "echo public-ip-${var.item-count} ${self.public_ip} >> all-ips.txt" : "echo private-ip$-${var.item-count} ${self.private_ip} >> all-ips.txt"
    }

    provisioner "remote-exec" {

        inline = var.my-remote-commands

        connection {
            type = "ssh"
            host = var.is_public ? self.public_ip : self.private_ip
            user = "ubuntu"
            private_key = file(var.path-to-pem-file)

            bastion_host = var.is_public ? "" : var.bastion_host_ip
            bastion_user = var.is_public ? "" :  "ubuntu"
            bastion_host_key = var.is_public ? "" : file(var.path-to-pem-file)
        }
    }
    }

```

### ec2/variables.tf

```bash
    variable "vpc_id" 
    variable "subnet_id"
    variable "ec2-ami" 
    variable "is_public" 
    variable "instance_type" 
    variable "allow_all_ipv4_cidr_blocks" 
    variable "allow_all_ipv6_cidr_blocks"
    variable "key-name" 
    variable "path-to-pem-file" 
    variable "item-count" 
    variable "my-remote-commands" 
    variable "bastion_host_ip" 

```
### ec2/outputs.tf

```bash
    output "instances_ids" 
    output "public_ip" 
```

### main.tf ec2 part

```bash
    module "creating-private-ec2-instances" {
    source = "./ec2-instances-config"
    vpc_id = module.creating-vpc-components.nasr-vpc-id
    subnet_id = module.creating-vpc-components.private_subnet_ids[count.index]
    count = length(module.creating-vpc-components.private_subnet_ids)
    key-name = var.key-name
    path-to-pem-file = var.path-to-pem-file
    is_public = false
    item-count = count.index + 1
    bastion_host_ip = module.creating-public-ec2-instances[0].public_ip
    my-remote-commands = [
        "sudo apt update -y",
        "sudo apt install -y nginx",
        "private_ip=`curl http://169.254.169.254/latest/meta-data/local-ipv4`",
        "echo 'Hello from private instance of private ip' >> index.html",
        "echo $private_ip >> index.html",
        "sudo mv index.html /var/www/html/",
    ]
    }

    module "creating-public-ec2-instances" {
    source = "./ec2-instances-config"
    vpc_id = module.creating-vpc-components.nasr-vpc-id
    subnet_id = module.creating-vpc-components.public_subnet_ids[count.index]
    count = length(module.creating-vpc-components.public_subnet_ids)
    key-name = var.key-name
    path-to-pem-file = var.path-to-pem-file
    is_public = true
    item-count = count.index + 1
    my-remote-commands = [
        "sudo apt update -y",
        "sudo apt install -y nginx",
        "echo 'server { \n listen 80 default_server; \n  listen [::]:80 default_server; \n  server_name _; \n  location / { \n  proxy_pass http://${module.creating-private-load-balancer.lb-dns}; \n  } \n}' > default",
        "sudo mv default /etc/nginx/sites-enabled/default",
        "sudo systemctl stop nginx",
        "sudo systemctl start nginx",
    ]
    }


```

### inputs.auto.tfvars ec2 part

```bash
    key-name = "my-key"
    path-to-pem-file = "./my-key.pem"
```

---

## load balancer

### load balancer/main.tf

```bash
    resource "aws_alb" "load_balancer_template" 
    resource "aws_alb_listener" "lb_listener" 
    resource "aws_alb_target_group" "lb_target_group"
    resource "aws_alb_target_group_attachment" "attach_target_group" 
    resource "aws_security_group" "lb_sg" 

```

### load balancer/variable.tf

```bash

    variable "vpc_id" 
    variable "lb_name" 
    variable "is_lb_internal" 
    variable "lb_subnets_ids"
    variable "ec2_instance_ids" 
    variable "target_group_name" 
    variable "target_group_type"
    variable "allow_all_ipv4_cidr_blocks" 
    variable "allow_all_ipv6_cidr_blocks" 

```

### load balancer/outputs.tf

```bash
    output "lb-dns" 

```

### main.tf load balancer part

```bash

    module "creating-private-load-balancer" {
    source = "./load-balancers"
    vpc_id = module.creating-vpc-components.nasr-vpc-id
    lb_name = var.private_lb_name
    lb_subnets_ids = module.creating-vpc-components.public_subnet_ids
    is_lb_internal = true
    target_group_name = var.private_target_group_name
    target_group_type = var.target_group_type
    ec2_instance_ids = module.creating-private-ec2-instances[*].instances_ids
    }

    module "creating-public-load-balancer" {
    source = "./load-balancers"
    vpc_id = module.creating-vpc-components.nasr-vpc-id
    lb_name = var.lb_name
    lb_subnets_ids = module.creating-vpc-components.public_subnet_ids
    is_lb_internal = false
    target_group_name = var.target_group_name
    target_group_type = var.target_group_type
    ec2_instance_ids = module.creating-public-ec2-instances[*].instances_ids
    }

```

### inputs.auto.tfvars load balancer part

```bash

    lb_name = "nasr-alb"
    target_group_name = "nasr-target-group"
    target_group_type = "instance"

    private_lb_name = "nasr-private-alb"
    private_target_group_name = "nasr-private-target-group"

```

## output.tf

```bash
    output "lb-dns"

```

## global variables.tf

```bash

    # global configuration variables

    variable "selected-region" 
    variable "s3-bucket-name" 
    variable "dynamodb-table-name" 
    variable "bucket-key" 

    # vpc variables

    variable "vpc_cidr_block" 
    variable "subnet_cidr_blocks" 
    variable "public-subnet-key-to-nat"
    variable "keys-of-public-subnets" 
    variable "keys-of-private-subnets" 
    variable "subnet_types" 

    # ec2 variables

    variable "key-name" 
    variable "path-to-pem-file"

    # lb variables

    variable "lb_name" 
    variable "target_group_name" 
    variable "target_group_type" 
    variable "private_lb_name" 
    variable "private_target_group_name"


```

---

## photos

### configuration of public ec2 instances proxy

![Alt text](./photos/configuration-of-public-ec2-instances-proxy.png?raw=true "Title")

---

### created load balancer in console

![Alt text](./photos/created-load-balancers-from-console.png?raw=true "Title")

---

### curl of public load balancer dns result

![Alt text](./photos/curl-of-public-load-balancer-dns.png?raw=true "Title")

---

### public load balancer dns in browser

![Alt text](./photos/dns-return-private-ec2-1.png?raw=true "Title")

---

![Alt text](./photos/dns-return-private-ec2-2.png?raw=true "Title")

---

### terraform state file (object) in s3

![Alt text](./photos/terraform-state-file-in-s3.png?raw=true "Title")
