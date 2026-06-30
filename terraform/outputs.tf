output "controlplane_ip" {
  value       = openstack_networking_floatingip_v2.cp_fip.address
  description = "Floating IP publique du control plane (API)"
}

output "worker_ips" {
  value       = openstack_networking_port_v2.worker_private[*].all_fixed_ips[0]
  description = "IPs privées des workers sur k8s-network"
}

output "talosconfig" {
  value     = data.talos_client_configuration.this.talos_config
  sensitive = true
}

output "kubeconfig" {
  value = replace(
    talos_cluster_kubeconfig.this.kubeconfig_raw,
    "https://${openstack_networking_port_v2.cp_private.all_fixed_ips[0]}:6443",
    "https://${openstack_networking_floatingip_v2.cp_fip.address}:6443"
  )
  sensitive = true
}

output "k8s_network_id" {
  value       = openstack_networking_network_v2.k8s_net.id
  description = "ID du réseau privé k8s-network (pour cloud-config CCM)"
}

output "k8s_subnet_id" {
  value       = openstack_networking_subnet_v2.k8s_subnet.id
  description = "ID du subnet k8s-network (pour cloud-config CCM)"
}

# --- Fichiers générés automatiquement ---

resource "local_file" "kubeconfig" {
  content = replace(
    talos_cluster_kubeconfig.this.kubeconfig_raw,
    "https://${openstack_networking_port_v2.cp_private.all_fixed_ips[0]}:6443",
    "https://${openstack_networking_floatingip_v2.cp_fip.address}:6443"
  )
  filename        = "${path.module}/kubeconfig"
  file_permission = "0600"
}

resource "local_file" "talosconfig" {
  content         = data.talos_client_configuration.this.talos_config
  filename        = "${path.module}/talosconfig"
  file_permission = "0600"
}
