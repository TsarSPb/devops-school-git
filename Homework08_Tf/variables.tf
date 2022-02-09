variable "rg_name" {
  default = "myTFResourceGroup2"
  description = "Resource Group to store the resources"
}

variable "location" {
    default = "westeurope"
    description = "Azure region to use"
}

variable "admin_user" {
    description = "admin username for the created VM"
}

variable "admin_pass" {
    description = "admin password for the created VM. Not really used - SSH cert is uploaded and should be used as a primary way to login"
}

variable "db_user" {
    description = "admin username for the created DB"
}

variable "db_pass" {
    description = "admin password for the created DB"
}

variable "tag_name" {
  default = "test tag"
  description = "for testing purposes"
}

variable "tag_name2" {
  description = "for testing purposes"
}
