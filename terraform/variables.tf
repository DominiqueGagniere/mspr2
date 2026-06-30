variable "region" {
  type    = string
}

variable "flavor_cp" {
  type    = string
}

variable "flavor_worker" {
  type    = string
}

variable "talos_version" {
  type    = string
}

variable "talos_schematic_id" {
  type    = string
}

variable "kubernetes_version" {
  type    = string
}

variable "cluster_name" {
  type    = string
}

variable "ext_net_name" {
  type    = string
}

variable "allowed_cidrs" {
  type        = list(string)
  description = "CIDR autorisés pour l'API Talos et Kubernetes"
}

variable "k8s_network_name" {
  type        = string
  default     = "k8s-network"
  description = "Nom du réseau privé vRack pour le LoadBalancer Octavia"
}
