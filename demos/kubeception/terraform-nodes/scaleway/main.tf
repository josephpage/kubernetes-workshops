terraform {
  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = "~> 2.48.0"
    }

    null   = "~> 3.2.3"
    random = "~> 3.6.3"
    local  = "~> 2.5.2"
  }

  required_version = "~> 1.4"
}

provider "scaleway" {}

locals {
  nodes = ["n1", "n2", "n3"]
}

resource "scaleway_instance_server" "kubeception-nodes" {
  for_each = toset(local.nodes)

  name="kubeception-${each.key}"
  type  = "DEV1-M"
  image = "ubuntu_noble"
  enable_dynamic_ip = true
  root_volume {
    size_in_gb = 20
  }
}

output "kubeception_nodes" {
  value = {
    for node in local.nodes : node => "ssh ubuntu@${scaleway_instance_server.kubeception-nodes[node].public_ip}"
  }
}
