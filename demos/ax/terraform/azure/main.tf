# Infrastructure de l'atelier AX sur Azure :
# - un cluster AKS 1.37 (2 nœuds x86_64, Azure CNI propulsé par Cilium) ;
# - un Azure Container Registry en lecture anonyme : atelet (Substrate v0.3.0)
#   ne sait pas s'authentifier auprès d'ACR ;
# - pas d'API S3 chez Azure : les snapshots vont dans rustfs, déployé dans le
#   cluster par scripts/10-install-substrate.sh (S3_IN_CLUSTER=true) ;
# - une ressource Azure OpenAI et un déploiement de modèle pour la passerelle LLM.

resource "random_id" "suffix" {
  byte_length = 3
}

locals {
  suffix = random_id.suffix.hex
}

resource "azurerm_resource_group" "this" {
  name     = "${var.cluster_name}-${local.suffix}"
  location = var.location
  tags = {
    project = "kubernetes-workshops"
    usage   = "ax-workshop"
  }
}

resource "azurerm_kubernetes_cluster" "this" {
  name                = var.cluster_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  dns_prefix          = "${var.cluster_name}-${local.suffix}"
  kubernetes_version  = var.kubernetes_version

  # Pas de mise à jour automatique pendant un atelier : un worker supprimé fait
  # perdre l'état des sandboxes non suspendues.
  automatic_upgrade_channel = null
  node_os_upgrade_channel   = "None"

  default_node_pool {
    name                        = "axworkers"
    vm_size                     = var.vm_size
    node_count                  = var.node_count
    os_disk_size_gb             = 64
    temporary_name_for_rotation = "axrotation"

    upgrade_settings {
      max_surge = "10%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  # Pool de nœuds classique, de taille fixe (pas de Node Auto Provisioning) :
  # l'installeur de Substrate labellise les nœuds présents à l'installation.
  node_provisioning_profile {
    mode = "Manual"
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "cilium"
    network_policy      = "cilium"
  }

  tags = azurerm_resource_group.this.tags
}

resource "local_sensitive_file" "kubeconfig" {
  filename        = pathexpand("~/.kube/kubeconfig-${var.cluster_name}")
  file_permission = "0600"
  content         = azurerm_kubernetes_cluster.this.kube_config_raw
}

# --- Registre -------------------------------------------------------------------

resource "azurerm_container_registry" "this" {
  name                   = "axworkshop${local.suffix}"
  resource_group_name    = azurerm_resource_group.this.name
  location               = azurerm_resource_group.this.location
  sku                    = "Standard" # minimum pour la lecture anonyme
  admin_enabled          = false
  anonymous_pull_enabled = true
}

resource "azurerm_role_assignment" "kubelet_acr_pull" {
  scope                = azurerm_container_registry.this.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
}

# --- Snapshots : identifiants du rustfs déployé dans le cluster --------------------

resource "random_password" "rustfs_access_key" {
  length  = 20
  special = false
}

resource "random_password" "rustfs_secret_key" {
  length  = 40
  special = false
}

# --- Passerelle LLM : Azure OpenAI --------------------------------------------------

resource "azurerm_cognitive_account" "openai" {
  name                  = "${var.cluster_name}-${local.suffix}"
  location              = var.openai_location
  resource_group_name   = azurerm_resource_group.this.name
  kind                  = "OpenAI"
  sku_name              = "S0"
  custom_subdomain_name = "${var.cluster_name}-${local.suffix}"
  tags                  = azurerm_resource_group.this.tags
}

resource "azurerm_cognitive_deployment" "agent" {
  name                 = "workshop-agent"
  cognitive_account_id = azurerm_cognitive_account.openai.id

  model {
    format  = "OpenAI"
    name    = var.llm_model
    version = var.llm_model_version
  }

  sku {
    name     = "GlobalStandard"
    capacity = 50 # milliers de tokens par minute
  }
}

# --- Contrat commun avec les scripts ------------------------------------------------

resource "local_sensitive_file" "workshop_env" {
  filename        = "${path.module}/../../workshop.env"
  file_permission = "0600"
  content = templatefile("${path.module}/../workshop.env.tftpl", {
    cloud        = "azure"
    cluster_name = var.cluster_name
    kubeconfig   = local_sensitive_file.kubeconfig.filename

    image_repo       = "${azurerm_container_registry.this.login_server}/ax-workshop"
    agent_image_repo = "${azurerm_container_registry.this.login_server}/ax-workshop/ax-agent-runner"

    snapshot_backend     = "s3"
    snapshot_location    = "gs://ax-snapshots/ax"
    s3_endpoint          = "http://rustfs.ate-system.svc:9000"
    s3_region            = "us-east-1"
    s3_force_path_style  = "true"
    s3_access_key_id     = random_password.rustfs_access_key.result
    s3_secret_access_key = random_password.rustfs_secret_key.result
    s3_in_cluster        = "true"

    llm_provider                   = "azure"
    llm_model                      = azurerm_cognitive_deployment.agent.name
    llm_api_base                   = azurerm_cognitive_account.openai.endpoint
    llm_api_key                    = azurerm_cognitive_account.openai.primary_access_key
    llm_api_version                = var.llm_api_version
    llm_aws_region                 = ""
    llm_vertex_project             = ""
    llm_vertex_location            = ""
    llm_service_account_annotation = ""
  })
}
