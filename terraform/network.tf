data "openstack_networking_network_v2" "ext_net" {
  name = var.ext_net_name
}
