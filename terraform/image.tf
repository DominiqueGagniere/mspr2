resource "openstack_images_image_v2" "talos" {
  name             = "talos-${var.talos_version}"
  image_source_url = "https://factory.talos.dev/image/${var.talos_schematic_id}/${var.talos_version}/openstack-amd64.qcow2"
  container_format = "bare"
  disk_format      = "qcow2"
  visibility       = "private"
  region           = var.region

  properties = {
    os_distro     = "talos"
    os_version    = var.talos_version
    hw_disk_bus   = "scsi"
    hw_scsi_model = "virtio-scsi"
  }
}
