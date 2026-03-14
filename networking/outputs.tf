# outputs.tf

output "vnet_name" {
  description = "The name of the Virtual Network"
  value       = azurerm_virtual_network.main.name
}

output "lb_public_ip" {
  description = "The Public IP of the Load Balancer"
  value       = azurerm_public_ip.lb_pip.ip_address
}

output "db_server_name" {
  description = "The name of the PostgreSQL Flexible Server"
  value       = azurerm_postgresql_flexible_server.postgres.name
}

output "db_server_fqdn" {
  description = "The fully qualified domain name of the PostgreSQL server"
  value       = azurerm_postgresql_flexible_server.postgres.fqdn
}

output "bastion_public_ip" {
  description = "The public IP of the Bastion Host"
  value       = azurerm_public_ip.bastion_pip.ip_address
}

output "public_subnet_ids" {
  value = azurerm_subnet.public[*].id
}

output "app_subnet_ids" {
  value = azurerm_subnet.app[*].id
}

output "db_subnet_ids" {
  value = azurerm_subnet.db[*].id
}
