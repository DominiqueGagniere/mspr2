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
