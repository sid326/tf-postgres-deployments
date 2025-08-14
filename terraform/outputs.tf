output "vm_ips" {
  value = [for nic in azurerm_network_interface.pg_nic : nic.private_ip_address]
}

output "admin_password" {
  value     = var.admin_password
  sensitive = true
}
