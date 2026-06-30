resource "openstack_compute_instance_v2" "controlplane" {
  name        = "${var.cluster_name}-cp-1"
  image_id    = openstack_images_image_v2.talos.id
  flavor_name = var.flavor_cp
  region      = var.region
  user_data   = data.talos_machine_configuration.controlplane.machine_configuration

  network {
    port = openstack_networking_port_v2.cp_private.id
  }

  tags = ["talos", "controlplane", var.cluster_name]
}

resource "openstack_compute_instance_v2" "worker" {
  count       = 2
  name        = "${var.cluster_name}-worker-${count.index + 1}"
  image_id    = openstack_images_image_v2.talos.id
  flavor_name = var.flavor_worker
  region      = var.region
  user_data   = data.talos_machine_configuration.worker.machine_configuration

  network {
    port = openstack_networking_port_v2.worker_private[count.index].id
  }

  tags = ["talos", "worker", var.cluster_name]
}
