terraform {
  required_version = ">= 1.0.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.0.0"
    }
  }
}

provider "azurerm" {
  features {
  }
}

resource "azurerm_resource_group" "rg-example-nuvem" {
  name     = "rg-example-nuvem"
  location = "East US"
}

resource "azurerm_virtual_network" "vnet-example-cloud" {
  name                = "vnet-example-cloud"
  location            = azurerm_resource_group.rg-example-nuvem.location
  resource_group_name = azurerm_resource_group.rg-example-nuvem.name
  address_space       = ["10.0.0.0/16"]

  tags = {
    environment = "Production"
    faculdade   = "Impacta"
  }
}

resource "azurerm_subnet" "subnet-example-cloud" {
  name                 = "subnet-example-cloud"
  resource_group_name  = azurerm_resource_group.rg-example-nuvem.name
  virtual_network_name = azurerm_virtual_network.vnet-example-cloud.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "ip-example-cloud" {
  name                = "ip-example-cloud"
  resource_group_name = azurerm_resource_group.rg-example-nuvem.name
  location            = azurerm_resource_group.rg-example-nuvem.location
  allocation_method   = "Static"

  tags = {
    environment = "Production"
  }
}

resource "azurerm_network_interface" "nic-example-cloud" {
  name                = "example-nic"
  location            = azurerm_resource_group.rg-example-nuvem.location
  resource_group_name = azurerm_resource_group.rg-example-nuvem.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet-example-cloud.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ip-example-cloud.id
  }
}

resource "azurerm_linux_virtual_machine" "vm-example-maquina" {
  name                            = "vm-example-maquina"
  resource_group_name             = azurerm_resource_group.rg-example-nuvem.name
  location                        = azurerm_resource_group.rg-example-nuvem.location
  size                            = "Standard_DS1_v2"
  admin_username                  = "adminuser"
  admin_password                  = "JoaoHenrique@1234"
  disable_password_authentication = false
  network_interface_ids = [
    azurerm_network_interface.nic-example-cloud.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}

resource "azurerm_network_security_group" "nsg-example-cloud" {
  name                = "nsg-example-cloud"
  location            = azurerm_resource_group.rg-example-nuvem.location
  resource_group_name = azurerm_resource_group.rg-example-nuvem.name

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Web"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "Production"
  }
}

resource "azurerm_network_interface_security_group_association" "nic-nsg-example-cloud" {
  network_interface_id      = azurerm_network_interface.nic-example-cloud.id
  network_security_group_id = azurerm_network_security_group.nsg-example-cloud.id
}

resource "null_resource" "install-nginx" {
  connection {
    type = "ssh"
    host = azurerm_public_ip.ip-example-cloud.ip_address
    user = "adminuser"
    password = "JoaoHenrique@1234"
  }
  
  provisioner "remote-exec" {
    inline = [ "sudo apt update", "sudo apt install -y nginx" ]
  }

  depends_on = [ azurerm_linux_virtual_machine.vm-example-maquina ]
}