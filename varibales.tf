variable "project_name" {
  type        = string
  description = "Name of the project"
  default     = "terraform-sandbox"
}


variable "region" {
  type        = string
  description = "Current AWS region"
  default     = "us-east-2"
}

variable "account_id" {
  type = string
}

variable "keep_lock_tables" {
  type = bool
  default = true
}
