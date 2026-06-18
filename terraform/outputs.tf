output "controlplane_ip" {
  value = openstack_compute_instance_v2.controlplane.access_ip_v4
}

output "worker_ips" {
  value = openstack_compute_instance_v2.worker[*].access_ip_v4
}

output "talosconfig" {
  value     = data.talos_client_configuration.this.talos_config
  sensitive = true
}

output "kubeconfig" {
  value     = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive = true
}
