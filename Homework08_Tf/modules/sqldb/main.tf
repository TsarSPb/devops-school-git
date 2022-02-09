
variable "rg_name" {
  default = "myTFResourceGroup2"
  description = "Resource Group to store the resources"
}

variable "location" {
    default = "westeurope"
    description = "Azure region to use"
}

variable "db_user" {
  description = "admin username for the created DB"
}

variable "db_pass" {
    description = "admin password for the created DB"
}

resource "azurerm_mssql_server" "example" {
  name                         = "myexamplesqlserverts8912"
  resource_group_name          = var.rg_name
  location                     = var.location
  version                      = "12.0"
  administrator_login          = var.db_user
  administrator_login_password = var.db_pass
  minimum_tls_version          = "1.2"

  tags = {
    environment = "production"
  }
}

resource "azurerm_storage_account" "example" {
  name                     = "examplesats8912"
  resource_group_name          = var.rg_name
  location                     = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_mssql_database" "example" {
  name           = "acctest-db-d"
  server_id      = azurerm_mssql_server.example.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  license_type   = "LicenseIncluded"
  max_size_gb    = 4
  read_scale     = true
  sku_name       = "BC_Gen5_2"
  zone_redundant = true

  tags = {
    environment = "production"
  }
}