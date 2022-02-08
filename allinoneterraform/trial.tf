
provider "azurerm" {
  features {}
}
locals {
 
  zones = toset(["1", "2", "3"])
}
resource "azurerm_resource_group" "myterraformgroup" {
  name     = "VM-Set-Zone-NSG-FireWallRG"
  location = "eastus"
}
resource "azurerm_virtual_network" "myterraformgroup" {
  name                = "myVnet"
  address_space       = ["10.0.0.0/16"]
  location            = "eastus"
  resource_group_name = azurerm_resource_group.myterraformgroup.name
}
resource "azurerm_subnet" "myterraformgroup" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.myterraformgroup.name
  virtual_network_name = azurerm_virtual_network.myterraformgroup.name
  address_prefixes      = ["10.0.1.0/24"]
}
resource "azurerm_subnet" "myterraformsubnet" {
  name                 = "mySubnet"
  resource_group_name  = azurerm_resource_group.myterraformgroup.name
  virtual_network_name = azurerm_virtual_network.myterraformgroup.name
  address_prefixes       = ["10.0.2.0/24"]
}

resource "azurerm_network_interface" "myterraformgroup" {
  for_each            = local.zones
  name                = "myNIC${each.value}"
  location            = "eastus"
  resource_group_name = azurerm_resource_group.myterraformgroup.name

  ip_configuration {
    name                          = "myNicConfiguration${each.value}"
    subnet_id                     = azurerm_subnet.myterraformsubnet.id
    private_ip_address_allocation = "Dynamic"
  }

}

resource "azurerm_public_ip" "myterraformgroup" {
  name                = "testpip"
  location            = azurerm_resource_group.myterraformgroup.location
  resource_group_name = azurerm_resource_group.myterraformgroup.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_firewall" "myterraformgroup" {
  name                = "testfirewall"
  location            = azurerm_resource_group.myterraformgroup.location
  resource_group_name = azurerm_resource_group.myterraformgroup.name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.myterraformgroup.id
    public_ip_address_id = azurerm_public_ip.myterraformgroup.id
  }
}


resource "azurerm_network_security_group" "myterraformgroup" {
  name                = "acceptanceTestSecurityGroup1"
  location            = azurerm_resource_group.myterraformgroup.location
  resource_group_name = azurerm_resource_group.myterraformgroup.name

  security_rule {
    name                       = "rksecurityrl"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "Production"
  }
}

resource "azurerm_availability_set" "set" {
  count                        = 2
  name                         = "availabilitySet${count.index}"
  location                     = azurerm_resource_group.myterraformgroup.location
  resource_group_name          = azurerm_resource_group.myterraformgroup.name
  managed                      = true
  platform_update_domain_count = 20
  platform_fault_domain_count  = 3
}

resource "azurerm_virtual_machine" "vm" {
  for_each              = local.zones
  name                  = "vm_zone${each.value}"
  location              = "eastus"
  resource_group_name   = azurerm_resource_group.myterraformgroup.name
  network_interface_ids = ["${azurerm_network_interface.myterraformgroup[each.value].id}"]
  vm_size               = "Standard_B1ls"
  zones                 = [each.value]

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "myOsDisk${each.value}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
  }

  os_profile {
    computer_name  = "rkcomputer"
    admin_username = "testadmin"
    admin_password = "Password1234!"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }   

}



