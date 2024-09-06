resource "azurerm_virtual_network" "test" {
  address_space       = ["10.52.0.0/16"]
  location            = local.resource_group.location
  name                = "${random_id.prefix.hex}-vn"
  resource_group_name = local.resource_group.name
}

resource "azurerm_subnet" "test" {
  address_prefixes                  = ["10.52.0.0/24"]
  name                              = "${random_id.prefix.hex}-sn"
  resource_group_name               = local.resource_group.name
  virtual_network_name              = azurerm_virtual_network.test.name
  private_endpoint_network_policies = "Enabled"
}
