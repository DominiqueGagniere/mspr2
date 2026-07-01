terraform init -upgrade
terraform plan
terraform apply

# Export des configs
terraform output -raw kubeconfig  > kubeconfig
terraform output -raw talosconfig > talosconfig

