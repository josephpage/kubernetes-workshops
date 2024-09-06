# Retrieve the resource group of the AKS cluster
data "azurerm_resource_group" "cluster" {
  name = var.resource_group_name
}

# Define the resource for the static public IP
resource "azurerm_public_ip" "nginx_ingress_ip" {
  name     = "nginx-ingress-ip"
  location = var.location
  # resource_group_name = module.aks.node_resource_group
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"

  lifecycle {
    create_before_destroy = true
  }
}

# Assign the Network Contributor role to the managed identity
resource "azurerm_role_assignment" "jopa_network_contributor" {
  principal_id         = module.aks.cluster_identity.principal_id
  role_definition_name = "Network Contributor"
  scope                = data.azurerm_resource_group.cluster.id
}

resource "helm_release" "nginx_ingress" {
  name             = "nginx-ingress"
  namespace        = "nginx-ingress"
  create_namespace = true

  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"

  values = [yamlencode(
    {
      controller = {
        service = {
          type = "LoadBalancer"

          # To forward Client IP to the backend
          externalTrafficPolicy = "Local"

          annotations = {
            # we use here the static public IP we created above
            "service.beta.kubernetes.io/azure-load-balancer-ipv4" = azurerm_public_ip.nginx_ingress_ip.ip_address

            # in case the static public IP is in a different resource group than the AKS cluster
            "service.beta.kubernetes.io/azure-load-balancer-resource-group" = var.resource_group_name
          }
        }
      }
    }
  )]

  depends_on = [module.aks,
  azurerm_public_ip.nginx_ingress_ip]

  lifecycle {
    replace_triggered_by = [azurerm_public_ip.nginx_ingress_ip]
  }
}

locals {
  ingress_domain_name = "${replace(azurerm_public_ip.nginx_ingress_ip.ip_address, ".", "-")}.${var.magic_xip_domain}"
}
