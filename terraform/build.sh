terraform init -upgrade
terraform plan
terraform apply

# Export des configs
terraform output -raw kubeconfig  > kubeconfig
terraform output -raw talosconfig > talosconfig

export TALOSCONFIG=$PWD/talosconfig
export KUBECONFIG=$PWD/kubeconfig

kubectl get nodes -o wide
