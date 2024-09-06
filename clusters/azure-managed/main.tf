resource "random_id" "prefix" {
  byte_length = 8
}

resource "azurerm_resource_group" "main" {
  count = var.create_resource_group ? 1 : 0

  location = var.location
  name     = coalesce(var.resource_group_name, "${random_id.prefix.hex}-rg")
}

data "azurerm_location" "default" {
  location = var.location
}

locals {
  resource_group = {
    name     = var.create_resource_group ? azurerm_resource_group.main[0].name : var.resource_group_name
    location = var.location
  }

  nodes = var.use_arm64_nodes ? {
    "worker-x86" = {
      name                  = "x86${substr(random_id.prefix.hex, 0, 5)}"
      vm_size               = "Standard_D2s_v5"
      node_count            = 3
      vnet_subnet_id        = azurerm_subnet.test.id
      create_before_destroy = true
      zones = data.azurerm_location.default.zone_mappings[*].logical_zone
    }
  } : {
    "worker-arm" = {
      name                  = "arm${substr(random_id.prefix.hex, 0, 5)}"
      vm_size               = "Standard_D2ps_v5"
      node_count            = 3
      vnet_subnet_id        = azurerm_subnet.test.id
      create_before_destroy = false
      zones = data.azurerm_location.default.zone_mappings[*].logical_zone
    }
  }
}

module "aks" {
  source  = "Azure/aks/azurerm"
  version = "9.1.0"

  prefix              = "prefix-${random_id.prefix.hex}"
  resource_group_name = local.resource_group.name
  os_disk_size_gb     = 60
  sku_tier            = "Free"
  rbac_aad            = false
  vnet_subnet_id      = azurerm_subnet.test.id

  agents_availability_zones = data.azurerm_location.default.zone_mappings[*].logical_zone
  node_pools          = local.nodes

  kubernetes_version = "1.30"

  azure_policy_enabled       = true
  microsoft_defender_enabled = true
}

module "cert-manager" {
  source = "../modules/cert-manager"
  email  = "jopa@octo.com"

  depends_on = [
    module.aks
  ]
}

module "grafana" {
  source           = "../modules/prometheus-grafana"
  base_domain_name = local.ingress_domain_name

  depends_on = [
    module.aks,
    helm_release.nginx_ingress
  ]
}

module "kubeseal" {
  source           = "../modules/kubeseal"

  depends_on = [module.aks]
}
