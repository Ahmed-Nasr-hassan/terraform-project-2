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
