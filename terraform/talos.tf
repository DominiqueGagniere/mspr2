resource "talos_machine_secrets" "this" {
  talos_version = var.talos_version
}

data "talos_machine_configuration" "controlplane" {
  cluster_name       = var.cluster_name
  cluster_endpoint   = "https://${openstack_networking_port_v2.cp_private.all_fixed_ips[0]}:6443"
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
        certSANs = [
          openstack_networking_floatingip_v2.cp_fip.address
        ]
      }
      cluster = {
        apiServer = {
          certSANs = [
            openstack_networking_floatingip_v2.cp_fip.address
          ]
        }
      }
    })
  ]
}

data "talos_machine_configuration" "worker" {
  cluster_name       = var.cluster_name
  cluster_endpoint   = "https://${openstack_networking_port_v2.cp_private.all_fixed_ips[0]}:6443"
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
  endpoints            = [openstack_networking_floatingip_v2.cp_fip.address]
  nodes = concat(
    [openstack_networking_port_v2.cp_private.all_fixed_ips[0]],
    openstack_networking_port_v2.worker_private[*].all_fixed_ips[0]
  )
}

resource "talos_machine_bootstrap" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoint             = openstack_networking_floatingip_v2.cp_fip.address
  node                 = openstack_networking_port_v2.cp_private.all_fixed_ips[0]

  depends_on = [
    openstack_compute_instance_v2.controlplane,
    openstack_networking_floatingip_associate_v2.cp_fip
  ]
}

resource "talos_cluster_kubeconfig" "this" {
  depends_on           = [talos_machine_bootstrap.this]
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoint             = openstack_networking_floatingip_v2.cp_fip.address
  node                 = openstack_networking_port_v2.cp_private.all_fixed_ips[0]
}
