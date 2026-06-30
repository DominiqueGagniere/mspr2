data "openstack_networking_network_v2" "ext_net" {
  name = var.ext_net_name
}

# Réseau privé vRack pour tout le cluster
resource "openstack_networking_network_v2" "k8s_net" {
  name           = var.k8s_network_name
  admin_state_up = true
  region         = var.region
}

resource "openstack_networking_subnet_v2" "k8s_subnet" {
  name            = "${var.k8s_network_name}-subnet"
  network_id      = openstack_networking_network_v2.k8s_net.id
  cidr            = "10.1.0.0/16"
  ip_version      = 4
  enable_dhcp     = true
  dns_nameservers = ["213.186.33.99"]
  region          = var.region
}

# Routeur : SNAT pour accès internet sortant + support Floating IP
resource "openstack_networking_router_v2" "k8s_router" {
  name                = "${var.cluster_name}-k8s-router"
  admin_state_up      = true
  region              = var.region
  external_network_id = data.openstack_networking_network_v2.ext_net.id
}

resource "openstack_networking_router_interface_v2" "k8s_router_interface" {
  router_id = openstack_networking_router_v2.k8s_router.id
  subnet_id = openstack_networking_subnet_v2.k8s_subnet.id
  region    = var.region
}

# --- Port Control Plane ---
resource "openstack_networking_port_v2" "cp_private" {
  name           = "${var.cluster_name}-cp-1-k8s"
  network_id     = openstack_networking_network_v2.k8s_net.id
  admin_state_up = true
  region         = var.region

  security_group_ids = [openstack_networking_secgroup_v2.talos.id]

  fixed_ip {
    subnet_id = openstack_networking_subnet_v2.k8s_subnet.id
  }
}

# Floating IP pour l'API (talosctl + kubectl)
resource "openstack_networking_floatingip_v2" "cp_fip" {
  pool   = var.ext_net_name
  region = var.region
}

resource "openstack_networking_floatingip_associate_v2" "cp_fip" {
  floating_ip = openstack_networking_floatingip_v2.cp_fip.address
  port_id     = openstack_networking_port_v2.cp_private.id
  region      = var.region

  depends_on = [openstack_networking_router_interface_v2.k8s_router_interface]
}

# --- Ports Workers ---
resource "openstack_networking_port_v2" "worker_private" {
  count          = 2
  name           = "${var.cluster_name}-worker-${count.index + 1}-k8s"
  network_id     = openstack_networking_network_v2.k8s_net.id
  admin_state_up = true
  region         = var.region

  security_group_ids = [openstack_networking_secgroup_v2.talos.id]

  fixed_ip {
    subnet_id = openstack_networking_subnet_v2.k8s_subnet.id
  }
}
