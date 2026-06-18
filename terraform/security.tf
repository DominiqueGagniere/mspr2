resource "openstack_networking_secgroup_v2" "talos" {
  name        = "${var.cluster_name}-sg"
  description = "Security group pour cluster Talos"
  region      = var.region
}

# Talos API
resource "openstack_networking_secgroup_rule_v2" "talos_api" {
  for_each          = toset(var.allowed_cidrs)
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 50000
  port_range_max    = 50000
  remote_ip_prefix  = each.value
  security_group_id = openstack_networking_secgroup_v2.talos.id
}

# Kubernetes API
resource "openstack_networking_secgroup_rule_v2" "k8s_api" {
  for_each          = toset(var.allowed_cidrs)
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 6443
  port_range_max    = 6443
  remote_ip_prefix  = each.value
  security_group_id = openstack_networking_secgroup_v2.talos.id
}

# Communication intra-cluster
resource "openstack_networking_secgroup_rule_v2" "cluster_internal" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  remote_group_id   = openstack_networking_secgroup_v2.talos.id
  security_group_id = openstack_networking_secgroup_v2.talos.id
}

resource "openstack_networking_secgroup_rule_v2" "cluster_internal_udp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "udp"
  remote_group_id   = openstack_networking_secgroup_v2.talos.id
  security_group_id = openstack_networking_secgroup_v2.talos.id
}
