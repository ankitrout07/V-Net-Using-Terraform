output "vnet_name" {
  description = "The name of the VNet"
  value       = module.networking.vnet_name
}

output "lb_public_ip" {
  description = "Public IP of the Load Balancer"
  value       = module.networking.lb_public_ip
}

output "db_server_fqdn" {
  description = "FQDN of the PostgreSQL Server"
  value       = module.database.db_server_fqdn
}

output "bastion_public_ip" {
  description = "Public IP for Bastion access"
  value       = module.networking.bastion_public_ip
}

output "app_subnet_ids" {
  value = module.networking.app_subnet_ids
}
