resource "talos_machine_secrets" "this" {
  talos_version = var.talos_version
}

data "talos_machine_configuration" "controlplane" {
  cluster_name       = var.cluster_name
  cluster_endpoint   = "https://${openstack_compute_instance_v2.controlplane.access_ip_v4}:6443"
  machine_type       = "controlplane"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = var.talos_version
  kubernetes_version = trimprefix(var.kubernetes_version, "v")

  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk = "/dev/sda"
        }
        kubelet = {
          extraArgs = {
            "cloud-provider" = "external"
          }
        }
      }
    })
  ]
}

data "talos_machine_configuration" "worker" {
  cluster_name       = var.cluster_name
  cluster_endpoint   = "https://${openstack_compute_instance_v2.controlplane.access_ip_v4}:6443"
  machine_type       = "worker"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = var.talos_version
  kubernetes_version = trimprefix(var.kubernetes_version, "v")

  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk = "/dev/sda"
        }
        kubelet = {
          extraArgs = {
            "cloud-provider" = "external"
          }
        }
      }
    })
  ]
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [openstack_compute_instance_v2.controlplane.access_ip_v4]
  nodes = concat(
    [openstack_compute_instance_v2.controlplane.access_ip_v4],
    openstack_compute_instance_v2.worker[*].access_ip_v4
  )
}

resource "talos_machine_configuration_apply" "controlplane" {
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = openstack_compute_instance_v2.controlplane.access_ip_v4
}

resource "talos_machine_configuration_apply" "worker" {
  count                       = 2
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  node                        = openstack_compute_instance_v2.worker[count.index].access_ip_v4
}

resource "talos_machine_bootstrap" "this" {
  depends_on           = [talos_machine_configuration_apply.controlplane]
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = openstack_compute_instance_v2.controlplane.access_ip_v4
}

resource "talos_cluster_kubeconfig" "this" {
  depends_on           = [talos_machine_bootstrap.this]
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = openstack_compute_instance_v2.controlplane.access_ip_v4
}

data "talos_cluster_health" "this" {
  depends_on           = [talos_cluster_kubeconfig.this]
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [openstack_compute_instance_v2.controlplane.access_ip_v4]
  control_plane_nodes  = [openstack_compute_instance_v2.controlplane.access_ip_v4]
  worker_nodes         = openstack_compute_instance_v2.worker[*].access_ip_v4
}
