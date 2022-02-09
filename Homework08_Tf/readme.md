# General info and notes
Set the region and resource group name in the `variables.tf`, set admin_user and admin_pass in `terraform.tfvars` and run `terraform apply`

Used the `null_resource` kind of resource and trigger inside it to make it run every time - this helps to debug provisioners.  

The files even for such a small project are a reall mess. Should invest some time to find out approaches to do it in a more neat and structured way, e.g. using modules and imports.

# Homework 1
* Скачать последнюю версию terraform
* Написать terraform манифест, который с помощью data source сущностей получает из облака информацию о AWS VPC/Azure virtual network, subnets и security groups 
* Вывести в оутпут имена AWS VPC/Azure virtual network, subnets и security groups

[Assignment 1 Download terraform](#download-terraform)  
[Assignment 2 Data source](#data-source)  
[Assignment 3 serviceAccount](#output)  

## Download teraform
[Back to the top](#homework-1)
* Скачать последнюю версию terraform
```
tf -version
Terraform v1.1.5
on linux_amd64
```

## Data source
[Back to the top](#homework-1)
* Написать terraform манифест, который с помощью data source сущностей получает из облака информацию о AWS VPC/Azure virtual network, subnets и security groups 

There seem to be two approaches to get the result. Used them both to get better understanding and learn about the nuances.  

The first one is the explicit use of respective resource, e.g `azurerm_network_security_group`. The disadvantage is that we can have multiple resources of the same type and have to remember to add / remove them as the `.tf` files get updated.  
> Not sure if there is a workaround / different approach to this,
> e.g. using `for/loop` or passing lists to the `name` parameter

```
data "azurerm_network_security_group" "data-sgs-explicit" {
  resource_group_name = var.rg_name
  name = azurerm_network_security_group.example.name
}
```
The second approach is more generic - using `azurerm_resources`. It gets information about all the resources of a particular type in a given resourceGroup.  
There is a caveat, though - it doesn't always return the resources created during hte same run / `tf apply` (probably due to delays on the Azure side).  
Adding `depends_on` seem to work, but doesn't look reliable.
```
data "azurerm_resources" "data-sgs" {
  resource_group_name = var.rg_name
  type = "Microsoft.Network/networkSecurityGroups"
  depends_on = [
    null_resource.deployment
  ]
}
```

## Output
[Back to the top](#homework-1)
* Вывести в оутпут имена AWS VPC/Azure virtual network, subnets и security groups

Given that the previous part is complete, this one is kind of trivial.  
When using the first approach describled in the [Data source](#data-source) part, it's just as simple as
```
output "data-sgs-explicit" {
  value = data.azurerm_network_security_group.data-sgs-explicit.name
}
output "data-sgs-explicit2" {
  value = data.azurerm_network_security_group.data-sgs-explicit2.name
}
output "data-sgs-explicit3" {
  value = data.azurerm_network_security_group.data-sgs-explicit3.name
}
```
The end result in the ourput is like this:
```
data-sgs-explicit = "nsg-test1"
data-sgs-explicit2 = "nsg-test2"
data-sgs-explicit3 = "nsg-test3"
```

Gets a bit more complicated for the second approach described in the [Data source](#data-source) part, but it's more multi-purpose and error-prone since it doesn't require continuous tracking / rechecking updates in the list of the resources.  
```
output "data-sgs" {
  value = [for s in data.azurerm_resources.data-sgs.resources : join(" - ",[s.name,s.type])]
}
```
The end result in the output is like this:
```
data-sgs = [
  "nsg-test1 - Microsoft.Network/networkSecurityGroups",
  "nsg-test2 - Microsoft.Network/networkSecurityGroups",
  "nsg-test3 - Microsoft.Network/networkSecurityGroups",
]
```

# Homework 2
[Back to the top](#general-info-and-notes)
* Написать terraform манифест для разворачивания AWS EC2/Azure VM. Этот инстанс должен содержать nginx. Nginx должен быть установлен во время провиженинга инстанса, например с помощью user data.
* (Дополнительно) Добавить в манифест код для создания базы данных AWS RDS/Azure Database. Тип базы на ваше усмотрение. 

## Deploy VM

The VM is deployed as a part of `main.tf`.  
Some notes regarding the implementation.
* used `"azurerm_linux_virtual_machine"` resource
* uploaded ssh key for later use
  ```
  admin_ssh_key {
    username   = var.admin_user
    public_key = file("./id_rsa.pub")
  }
  ```
* used `remote-exec` provisioner

## Deploy database
* (Дополнительно) Добавить в манифест код для создания базы данных AWS RDS/Azure Database. Тип базы на ваше усмотрение.  

The creation of the database is implemented via a separate module (located in `modules/sqldb`).
Nothing special about it, just a basic deployment.  
