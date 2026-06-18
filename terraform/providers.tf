terraform {
  required_version = ">= 1.14"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 3.4"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.11"
    }
  }
}

provider "openstack" {
  # Variables from openrc.sh (OS_AUTH_URL, OS_USERNAME, etc.)
}

provider "talos" {}