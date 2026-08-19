terraform {
  # Los valores de bucket/dynamodb_table deben coincidir con los outputs de
  # infrastructure/bootstrap (state_bucket_name / lock_table_name). Terraform
  # no permite variables en un bloque backend, por eso van hardcodeados aqui.
  backend "s3" {
    bucket         = "cloudpulse-terraform-state"
    key            = "environments/prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "cloudpulse-terraform-locks"
    encrypt        = true
  }
}
