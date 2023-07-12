variable "security_group_enabled" {
  default = true
  type    = bool
  description = "Specify wheather to enable security group over pod of roboshop application"
}

variable "security_group_config" {
  type = any
  default = {
    SecurityGroupPolicy_values_yaml   = ""
  }
  description = "Configuration options for the SecurityGroupPolicy attached over roboshop"
}

variable "roboshop_namespace" {
  default     = "roboshop"
  type        = string
  description = "Name of the namespace where roboshop application deployed"
}