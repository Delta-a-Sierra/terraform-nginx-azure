terraform {
  required_providers {
    azurerm = {
        source = "hashicorp/azurerm"
        version = "=2.46.0"
    }
  }
}

variable "subscription_id" {
  description = "subscription id"
  type = string
}
variable "ssh_key" {
  description = "public ssh key"
  type = string
}

variable "location" {
  description = "resource location"
  type = string
}

variable "my_ip" {
  description = "private ip address to restrict"
  type = string
  
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

resource "azurerm_resource_group" "devops_rg" {
  name     = "rg-devops-learning-${var.location}"
  location = var.location
  tags = {
    enviroment = "learning"
  }
}

resource "azurerm_network_security_group" "nsg_frontend" {
  name                = "nsg-frontend-${var.location}"
  location            = var.location
  resource_group_name = azurerm_resource_group.devops_rg.name

  security_rule {
    name                       = "allow-http"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-https"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-ssh"
    priority                   = 102
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = var.my_ip
    destination_address_prefix = "*"
  }

  tags = {
    environment = "learning"
  }
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-devops-learning-${var.location}"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.devops_rg.name
  tags = {
    enviroment = "learning"
  }
}

resource "azurerm_subnet" "frontend" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.devops_rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]   
}


resource "azurerm_subnet_network_security_group_association" "nsg_association" {
  subnet_id  = azurerm_subnet.frontend.id
  network_security_group_id = azurerm_network_security_group.nsg_frontend.id
}

resource "azurerm_public_ip" "pip_ngix" {
  name = "pip-ngix-${var.location}"
  location            = var.location
  resource_group_name = azurerm_resource_group.devops_rg.name
  allocation_method   = "Static"
  tags = {
    enviroment = "learning"
  }
}

resource "azurerm_network_interface" "nic_ngix" {
  name                = "nic-ngix-${var.location}"
  location            = var.location
  resource_group_name = azurerm_resource_group.devops_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.frontend.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.pip_ngix.id
  }

    tags = {
    enviroment = "learning"
  }
}

resource "azurerm_linux_virtual_machine" "vm_nginx" {
  name = "vm-nginx-srv01-${var.location}"
  resource_group_name = azurerm_resource_group.devops_rg.name
  location = var.location
  size = "standard_B1s"

  admin_username = "adminuser"

  admin_ssh_key {
    username = "adminuser"
    public_key  = file(var.ssh_key)
  }

  network_interface_ids = [azurerm_network_interface.nic_ngix.id]

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

# provisioner "remote-exec" {
#   inline = [
#     "sudo yum install nginx -y",
#     "sudo service nginx start"
#   ]
# }
