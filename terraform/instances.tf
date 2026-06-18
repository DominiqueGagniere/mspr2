resource "openstack_compute_instance_v2" "controlplane" {
  name            = "${var.cluster_name}-cp-1"
  image_id        = openstack_images_image_v2.talos.id
  flavor_name     = var.flavor_cp
  region          = var.region
  security_groups = [openstack_networking_secgroup_v2.talos.name]

  network {
    name = var.ext_net_name
  }

  tags = ["talos", "controlplane", var.cluster_name]
}

resource "openstack_compute_instance_v2" "worker" {
  count           = 2
  name            = "${var.cluster_name}-worker-${count.index + 1}"
  image_id        = openstack_images_image_v2.talos.id
  flavor_name     = var.flavor_worker
  region          = var.region
  security_groups = [openstack_networking_secgroup_v2.talos.name]

  network {
    name = var.ext_net_name
  }

  tags = ["talos", "worker", var.cluster_name]
}
