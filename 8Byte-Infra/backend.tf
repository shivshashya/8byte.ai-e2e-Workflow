terraform {
  # This bucket was created manually and is not managed by this configuration.
  backend "s3" {
    bucket       = "8byte.ai"
    key          = "shared/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
