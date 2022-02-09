output "rg-list-resources" {
  # value = data.azurerm_resources.data-keys.resources
  # using depends_on to explicitly make sure that it runs as late as possible
  # otherwise it doesn't always get information about the recently
  # created resources and doesn't output them on the same run
  depends_on = [
    null_resource.deployment
  ]
  value = [for s in data.azurerm_resources.data-rg-resources.resources : join(" - ",[s.name,s.type])]
#  + keys = [
#      + {
#          + id       = "/subscriptions/bd204c2f-7960-4217-85d2-3431d0e5d58e/resourceGroups/Sandkasten/providers/Microsoft.Compute/sshPublicKeys/mySSHKey"
#          + location = "westeurope"
#          + name     = "mySSHKey"
#          + tags     = {}
#          + type     = "Microsoft.Compute/sshPublicKeys"
#        }
}

output "data-keys" {
  #value = data.azurerm_resources.data-keys
  value = [for s in data.azurerm_resources.data-keys.resources : join(" - ",[s.name,s.type])]
}
output "data-sgs" {
#  value= data.azurerm_resources.data-sgs
  value = [for s in data.azurerm_resources.data-sgs.resources : join(" - ",[s.name,s.type])]
}
output "data-sgs-explicit" {
#  value= data.azurerm_resources.data-sgs
  value = data.azurerm_network_security_group.data-sgs-explicit.name
}
output "data-sgs-explicit2" {
#  value= data.azurerm_resources.data-sgs
  value = data.azurerm_network_security_group.data-sgs-explicit2.name
}
output "data-sgs-explicit3" {
#  value= data.azurerm_resources.data-sgs
  value = data.azurerm_network_security_group.data-sgs-explicit3.name
}
output "data-vnets" {
#    value = data.azurerm_resources.data-vnets
  value = [for s in data.azurerm_resources.data-vnets.resources : join(" - ",[s.name,s.type])]
}
output "data-subnets" {
  #  value = data.azurerm_resources.data-subnets
  value = [for s in data.azurerm_resources.data-subnets.resources : join(" - ",[s.name,s.type])]
}

# testing dynamic IP allocation
# the "ip_address" output won't work (on the first run),
# while "ip_address_data" will
# requesting it fron the resource doesn't work (on the first run only)
# Underlying Azure infrastructure won't allocate an IP Address to a Dynamic Public IP
# until it's assigned to a resource in that's running (such as a VM / LB etc) -
# whereas Static Public IP's will be returned a value even prior to being assigned to something.
# see https://github.com/hashicorp/terraform-provider-azurerm/issues/310 for more details

output "ip_address" {
  value = azurerm_public_ip.example.ip_address
}

output "ip_address_data" {
  value = data.azurerm_public_ip.example.ip_address
}
