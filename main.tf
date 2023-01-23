module "creating-vpc-components" {
  source = "./vpc-components"
  vpc_cidr_block = var.vpc_cidr_block
  subnet_cidr_blocks = var.subnet_cidr_blocks
  public-subnet-key-to-nat = var.public-subnet-key-to-nat
  keys-of-public-subnets = var.keys-of-public-subnets
  keys-of-private-subnets = var.keys-of-private-subnets
  subnet_types =  var.subnet_types
}

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