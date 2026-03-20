# database.tf

resource "random_string" "sql_suffix" {
  length  = 6
  special = false
  upper   = false
}

# 1. Azure SQL Server
resource "azurerm_mssql_server" "sql" {
  name                         = "${lower(var.project_name)}-sql-srv-${random_string.sql_suffix.result}"
  resource_group_name          = azurerm_resource_group.main.name
  location                     = azurerm_resource_group.main.location
  version                      = "12.0"
  administrator_login          = var.admin_username
  administrator_login_password = var.db_password
}

# 2. Azure SQL Database
resource "azurerm_mssql_database" "db" {
  name      = var.db_name
  server_id = azurerm_mssql_server.sql.id
  sku_name  = "S0"
}

# 3. Private Endpoint for SQL Database
resource "azurerm_private_endpoint" "sql_pe" {
  name                = "${var.project_name}-sql-pe"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.db[0].id

  private_service_connection {
    name                           = "${var.project_name}-sql-psc"
    private_connection_resource_id = azurerm_mssql_server.sql.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.sql_zone.id]
  }
}

# 4. Private DNS Zone for Azure SQL
resource "azurerm_private_dns_zone" "sql_zone" {
  name                = "privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.main.name
}

# 5. Virtual Network Link for DNS Zone
resource "azurerm_private_dns_zone_virtual_network_link" "sql_zone_link" {
  name                  = "${var.project_name}-sql-vnet-link"
  private_dns_zone_name = azurerm_private_dns_zone.sql_zone.name
  virtual_network_id    = azurerm_virtual_network.main.id
  resource_group_name   = azurerm_resource_group.main.name
}
