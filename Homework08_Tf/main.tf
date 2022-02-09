terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.65"
    }

    null = {

    }
  }
  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
  # DON'T DO IT - USE EITHER ENV VARS (BELOW) OR??? TF VARS
  #  subscription_id = "00000000-0000-0000-0000-000000000000"
  #  client_id       = "00000000-0000-0000-0000-000000000000"
  #  client_secret   = var.client_secret
  #  tenant_id       = "00000000-0000-0000-0000-000000000000"
  # DON'T DO IT - USE EITHER ENV VARS (BELOW) OR??? TF VARS
  # $ export ARM_CLIENT_ID="00000000-0000-0000-0000-000000000000"
  # $ export ARM_CLIENT_SECRET="00000000-0000-0000-0000-000000000000"
  # $ export ARM_SUBSCRIPTION_ID="00000000-0000-0000-0000-000000000000"
  # $ export ARM_TENANT_ID="00000000-0000-0000-0000-000000000000"
}

# data "azurerm_virtual_network" "data-vnet" {
#   
# }

module "sqldb" {
  source = "./modules/sqldb"
  db_user = var.db_user
  db_pass = var.db_pass
  rg_name = var.rg_name
  location = var.location
}

# This data source gets a complete list of resource in a rg
data "azurerm_resources" "data-rg-resources" {
  resource_group_name = var.rg_name
}

# This data source gets a list of ssh keys in a rg
data "azurerm_resources" "data-keys" {
  resource_group_name = var.rg_name
  type = "Microsoft.Compute/sshPublicKeys"
}

# This data source gets a list of security groups in a rg
data "azurerm_resources" "data-sgs" {
  resource_group_name = var.rg_name
  type = "Microsoft.Network/networkSecurityGroups"
  depends_on = [
    null_resource.deployment
  ]
}
data "azurerm_network_security_group" "data-sgs-explicit" {
  resource_group_name = var.rg_name
  name = azurerm_network_security_group.example.name
}
data "azurerm_network_security_group" "data-sgs-explicit2" {
  resource_group_name = var.rg_name
  name = azurerm_network_security_group.example2.name
}
data "azurerm_network_security_group" "data-sgs-explicit3" {
  resource_group_name = var.rg_name
  name = azurerm_network_security_group.example3.name
}
# This data source gets a list of vnets in a rg
data "azurerm_resources" "data-vnets" {
  resource_group_name = var.rg_name
  type = "Microsoft.Network/virtualNetworks"
}
# This data source gets a list of subnets in a rg
data "azurerm_resources" "data-subnets" {
  resource_group_name = var.rg_name
  type = "Microsoft.Network/virtualNetworks/subnets"
}

data "azurerm_public_ip" "example" {
  name                = "${azurerm_public_ip.example.name}"
  resource_group_name = "${azurerm_resource_group.example.name}"
  depends_on          = [azurerm_linux_virtual_machine.example]
}

############################################################
############################################################
############################################################

resource "azurerm_resource_group" "example" {
  name     = var.rg_name
  location = var.location
  tags = {
    owner   = "Dmitry Tsarev"
    project = "Sandkasten"
  }
}

resource "azurerm_network_security_group" "example" {
  name                = "nsg-test1"
  location            = azurerm_resource_group.example.location
  resource_group_name = var.rg_name
}

resource "azurerm_network_security_group" "example2" {
  name                = "nsg-test2"
  location            = azurerm_resource_group.example.location
  resource_group_name = var.rg_name
}

resource "azurerm_network_security_group" "example3" {
  name                = "nsg-test3"
  location            = azurerm_resource_group.example.location
  resource_group_name = var.rg_name
}

resource "azurerm_virtual_network" "example" {
  name = "example-network"
  # Getting RG name and location from RG
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  address_space       = ["10.0.0.0/16"]
  # Getting tags from the RG and adding another one
  tags = merge(azurerm_resource_group.example.tags, tomap({
    "Name" = var.tag_name, "Name2" = var.tag_name2 }
  ))
}

resource "azurerm_subnet" "example" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "example" {
  name                    = "test-pip"
  location                = azurerm_resource_group.example.location
  resource_group_name     = azurerm_resource_group.example.name
  allocation_method       = "Dynamic"
  idle_timeout_in_minutes = 30

  tags = {
    environment = "test"
  }
}

resource "azurerm_network_interface" "example" {
  name                = "example-nic"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.example.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.example.id
  }
}

resource "azurerm_linux_virtual_machine" "example" {
  name                = "example-machine"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  size                = "Standard_F2"
  admin_username      = var.admin_user
  network_interface_ids = [
    azurerm_network_interface.example.id,
  ]

  admin_ssh_key {
    username   = var.admin_user
    public_key = file("./id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
}

# Fake resource which gets executed on every apply
# to test provisioners
resource "null_resource" "deployment" {
  triggers = {
    always_run = timestamp()
  }
  depends_on = [
    azurerm_linux_virtual_machine.example,
    azurerm_public_ip.example
  ]

# ssh adminuser@${azurerm_public_ip.example.ip_address} -i ./id_rsa 'uname -a'
# commented out because of ' Permissions 0777 for './id_rsa' are too open.'
# feel free to uncomment and move below as the secont command to echo
  provisioner "local-exec" {
    command = <<EOT
    echo Public IP is ${azurerm_public_ip.example.ip_address}
     EOT
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update && sudo apt -y install nginx",
      "sudo sh -c 'echo \"Some new text\" > /var/www/html/index.html'",
      "echo Public IP is ${azurerm_public_ip.example.ip_address}",
      "echo $(uname -a)"
    ]
    connection {
      type = "ssh"
      host = data.azurerm_public_ip.example.ip_address
      user     = "${var.admin_user}"
      # password = "${var.ssh_pass}"
      # file("${path.module}/id_rsa")
      private_key = file("./id_rsa")
      port = 22
      timeout = "1m"
      agent = false
    }
  }
}
