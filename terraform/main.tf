resource "azurerm_resource_group" "pg" {
  name     = "pg-ha-rg"
  location = var.location
}

resource "azurerm_virtual_network" "pg_vnet" {
  name                = "pg-ha-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.pg.location
  resource_group_name = azurerm_resource_group.pg.name
}

resource "azurerm_subnet" "pg_subnet" {
  name                 = "pg-ha-subnet"
  resource_group_name  = azurerm_resource_group.pg.name
  virtual_network_name = azurerm_virtual_network.pg_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_security_group" "pg_nsg" {
  name                = "pg-ha-nsg"
  location            = azurerm_resource_group.pg.location
  resource_group_name = azurerm_resource_group.pg.name

  security_rule {
    name                       = "AllowPostgresInternal"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = "10.0.1.0/24"
    destination_port_range     = "5432"
    source_port_range          = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "pg_nsg_assoc" {
  subnet_id                 = azurerm_subnet.pg_subnet.id
  network_security_group_id = azurerm_network_security_group.pg_nsg.id
}

resource "azurerm_network_interface" "pg_nic" {
  count               = var.vm_count
  name                = "pg-ha-nic-${count.index + 1}"
  location            = azurerm_resource_group.pg.location
  resource_group_name = azurerm_resource_group.pg.name
  ip_configuration {
    name                          = "pg-ha-ipcfg"
    subnet_id                     = azurerm_subnet.pg_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "pg_vm" {
  count                 = var.vm_count
  name                  = "pg-ha-vm-${count.index + 1}"
  resource_group_name   = azurerm_resource_group.pg.name
  location              = azurerm_resource_group.pg.location
  size                  = var.vm_size
  admin_username        = var.admin_username
  admin_password        = var.admin_password
  disable_password_authentication = false
  network_interface_ids = [azurerm_network_interface.pg_nic[count.index].id]
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

  custom_data = filebase64("cloud-init-postgres.yaml")
}