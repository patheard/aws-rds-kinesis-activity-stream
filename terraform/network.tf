module "vpc" {
  source = "github.com/cds-snc/terraform-modules//vpc?ref=v9.2.6"
  name   = var.project_name

  enable_flow_log                  = true
  availability_zones               = 2
  cidrsubnet_newbits               = 8
  single_nat_gateway               = true
  allow_https_request_out          = true
  allow_https_request_out_response = true
  allow_https_request_in           = true
  allow_https_request_in_response  = true

  billing_tag_value = var.billing_tag_value
}
