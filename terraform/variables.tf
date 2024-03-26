variable "billing_tag_value" {
  description = "CostCentre billing tag value."
  type        = string
  default     = "SRE"
}

variable "database_password" {
  description = "Database password to use for the RDS cluster."
  type        = string
  sensitive   = true
}

variable "database_username" {
  description = "Database username to use for the RDS cluster."
  type        = string
  sensitive   = true
}

variable "project_name" {
  description = "Name of the project, which will be used as a prefix for resources."
  type        = string
  default     = "rds-kinesis-activity-stream"
}

variable "region" {
  description = "AWS region to deploy resources in."
  type        = string
  default     = "ca-central-1"
}