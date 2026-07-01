# mspr2

Bloc 2 -- Manager un projet informatique avec agilite en collaboration avec les parties prenantes

Deploiement d'un ERP Odoo sur un cluster Kubernetes Talos, heberge sur OpenStack (OVH Public Cloud).

---

## Table des matieres

1. [Architecture](#architecture)
2. [Prerequis](#prerequis)
3. [Phase 1 -- Terraform (infrastructure)](#phase-1--terraform-infrastructure)
4. [Phase 2 -- Post-tasks (synchronisation reseau)](#phase-2--post-tasks-synchronisation-reseau)
5. [Phase 3 -- Ansible (deploiement applicatif)](#phase-3--ansible-deploiement-applicatif)
6. [Post-deploiement et acces](#post-deploiement-et-acces)
7. [Verification et depannage](#verification-et-depannage)
8. [Teardown](#teardown)

---

## Architecture

```
                        Internet
                           |
                   +-------+-------+
                   | Floating IP   |
                   | (Ext-Net OVH) |
                   +-------+-------+
                           |
            +--------------+--------------+
            |                             |
   CP FIP (<CP_FIP>)            LB FIP (<LB_FIP>)
   ports 6443 / 50000           ports 80 / 443
            |                             |
+-----------+----------+     +------------+------------+
| Control Plane (d2-4) |     | Octavia Load Balancer   |
| - Talos OS           |     | (provisionne par CCM)   |
| - kube-apiserver     |     +------------+------------+
| - etcd               |                  |
+----------------------+       NodePorts 30000-32767
                               |                    |
                  +------------+--+    +--+------------+
                  | Worker 1 d2-2 |    | Worker 2 d2-2 |
                  | - Traefik     |    | - Traefik     |
                  | - Odoo        |    | - Cinder CSI  |
                  | - PostgreSQL  |    | - cert-manager|
                  +---------------+    +---------------+
                           |
                  Reseau prive k8s-network (10.1.0.0/16)
```

**Composants deployes :**

| Ordre | Composant | Namespace | Chart Helm | Version |
|-------|-----------|-----------|------------|---------|
| 1 | OpenStack Cloud Controller Manager | kube-system | cloud-provider-openstack | 2.36.0 |
| 2 | Cinder CSI | kube-system | cloud-provider-openstack | 2.36.0 |
| 3 | cert-manager | cert-manager | jetstack | v1.20.2 |
| 4 | Traefik | traefik | traefik | 41.0.0 |
| 5 | Odoo + PostgreSQL | default | imio/odoo | 1.2.0 |

**Chaine TLS (certificats auto-signes) :**

```
ClusterIssuer selfsigned-bootstrap
        |
   Certificate root-ca (ECDSA P-256, 10 ans)
        |
ClusterIssuer ca-issuer
        |
   Certificate odoo-tls-secret (Ingress Odoo)
```

---

## Prerequis

### Outils requis

| Outil | Version minimale | Verification |
|-------|-----------------|--------------|
| terraform | >= 1.14 | `terraform version` |
| kubectl | compatible K8s | `kubectl version --client` |
| kustomize | >= 5.0 | `kustomize version` |
| helm | >= 3.x | `helm version` |
| ansible | >= 2.15 | `ansible --version` |
| openstack CLI | >= 7.x | `openstack --version` |

### Fichiers de configuration

| Fichier | Role | A creer |
|---------|------|---------|
| `openrc.sh` | Credentials OpenStack (source avant terraform) | Fourni par OVH |
| `terraform/talos.auto.tfvars` | Variables Terraform du cluster | Oui (depuis `.sample`) |
| `kustomize/prod/cloud-controller-manager/resources/cloud-config-secret.yaml` | Secret OpenStack (CCM + Cinder) | Oui (depuis `.sample`) |

---

## Phase 1 -- Terraform (infrastructure)

### 1.1 Configurer les variables

Copier le fichier sample et renseigner les valeurs :

```bash
cp terraform/talos.auto.tfvars.sample terraform/talos.auto.tfvars
```

Editer `terraform/talos.auto.tfvars` :

```hcl
region             = "<REGION>"
flavor_cp          = "<FLAVOR_CONTROL_PLANE>"
flavor_worker      = "<FLAVOR_WORKER>"
talos_version      = "<TALOS_VERSION>"
talos_schematic_id = "<SCHEMATIC_ID>"
kubernetes_version = "<K8S_VERSION>"
cluster_name       = "<CLUSTER_NAME>"
ext_net_name       = "<EXT_NET_NAME>"
allowed_cidrs      = ["<CIDR_AUTORISE>"]
```

**Variables :**

| Variable | Description | Exemple |
|----------|-------------|---------|
| `region` | Region OVH | GRA9 |
| `flavor_cp` | Flavor VM control plane | d2-4 |
| `flavor_worker` | Flavor VMs worker | d2-2 |
| `talos_version` | Version Talos Linux | v1.13.3 |
| `talos_schematic_id` | ID schematic Talos Factory (image OpenStack) | 376567988ad3... |
| `kubernetes_version` | Version Kubernetes | v1.36.1 |
| `cluster_name` | Nom du cluster (prefixe ressources) | talos-ovh |
| `ext_net_name` | Nom du reseau externe OVH | Ext-Net |
| `allowed_cidrs` | CIDR(s) autorises pour API (Talos 50000, K8s 6443) | ["0.0.0.0/0"] |

> **Schematic ID :** genere sur https://factory.talos.dev avec le profil `openstack-amd64`.

### 1.2 Authentification OpenStack

```bash
source openrc.sh
# Entrer le mot de passe OpenStack quand demande
```

### 1.3 Deployer l'infrastructure

```bash
cd terraform
terraform init -upgrade
terraform plan
terraform apply
```

Ou en une commande :

```bash
cd terraform && bash build.sh
```

**Ce que Terraform cree :**
- Image Talos (telecharge depuis factory.talos.dev)
- Reseau prive `k8s-network` (10.1.0.0/16) + subnet + routeur
- Security group (ports 50000, 6443, intra-cluster TCP/UDP, NodePorts 30000-32767)
- 1 VM control plane + Floating IP (API)
- 2 VMs worker
- Bootstrap Talos + generation kubeconfig/talosconfig

### 1.4 Verifier le cluster

```bash
export KUBECONFIG=$PWD/kubeconfig

kubectl get nodes -o wide
```

**Sortie attendue :**

```
NAME                 STATUS   ROLES           AGE   VERSION    INTERNAL-IP   EXTERNAL-IP
<cluster>-cp-1       Ready    control-plane   2m    <k8s_ver>  10.1.x.x      <CP_FIP>
<cluster>-worker-1   Ready    <none>          1m    <k8s_ver>  10.1.x.x      <none>
<cluster>-worker-2   Ready    <none>          1m    <k8s_ver>  10.1.x.x      <none>
```

Les 3 noeuds doivent etre `Ready` avant de continuer.

### 1.5 Recuperer les outputs

```bash
terraform output controlplane_ip
terraform output k8s_network_id
terraform output k8s_subnet_id
```

> **Noter ces valeurs** -- elles sont necessaires pour la Phase 2.

---

## Phase 2 -- Post-tasks (synchronisation reseau)

> **OBLIGATOIRE** apres chaque `terraform apply` qui recree le reseau.
> Les IDs reseau changent a chaque destruction/recreation -- c'est la source principale de problemes (LB en Pending).

### 2.1 Recuperer les IDs

```bash
# Depuis le dossier terraform/
NETWORK_ID=$(terraform output -raw k8s_network_id)
SUBNET_ID=$(terraform output -raw k8s_subnet_id)

# Floating network (Ext-Net) -- stable, rarement change
source ../openrc.sh
FLOATING_NET_ID=$(openstack network show Ext-Net -f value -c id)

echo "network-id=$NETWORK_ID"
echo "subnet-id=$SUBNET_ID"
echo "floating-network-id=$FLOATING_NET_ID"
```

### 2.2 Creer et renseigner cloud-config-secret.yaml

Ce fichier contient les credentials OpenStack et les IDs reseau : il n'est **pas versionne** (seul le `.sample` l'est).

Creer depuis le modele :

```bash
cp kustomize/prod/cloud-controller-manager/resources/cloud-config-secret.yaml.sample \
   kustomize/prod/cloud-controller-manager/resources/cloud-config-secret.yaml
```

Puis editer `kustomize/prod/cloud-controller-manager/resources/cloud-config-secret.yaml` et renseigner les valeurs :

```yaml
stringData:
  cloud.conf: |
    [Global]
    auth-url=https://auth.cloud.ovh.net/v3
    username=<OS_USERNAME>
    password=<OS_PASSWORD>
    region=<REGION>
    tenant-id=<TENANT_ID>
    domain-name=Default

    [LoadBalancer]
    subnet-id=<SUBNET_ID>
    network-id=<NETWORK_ID>
    member-subnet-id=<SUBNET_ID>
    floating-network-id=<FLOATING_NET_ID>

    [BlockStorage]
    ignore-volume-az=true
```

**Mapping des placeholders :**

| Placeholder | Source |
|-------------|--------|
| `<OS_USERNAME>` | `openrc.sh` -> `OS_USERNAME` |
| `<OS_PASSWORD>` | Mot de passe OpenStack |
| `<REGION>` | `openrc.sh` -> `OS_REGION_NAME` |
| `<TENANT_ID>` | `openrc.sh` -> `OS_TENANT_ID` |
| `<NETWORK_ID>` | `terraform output k8s_network_id` |
| `<SUBNET_ID>` | `terraform output k8s_subnet_id` |
| `<FLOATING_NET_ID>` | `openstack network show Ext-Net -f value -c id` |

> **Important :** `floating-network-id` dans la section `[LoadBalancer]` est ce qui donne une IP publique au Load Balancer Octavia. Sans cette ligne, le LB obtient uniquement un VIP prive.

---

## Phase 3 -- Ansible (deploiement applicatif)

### 3.1 Structure Kustomize

```
kustomize/
├── base
│   ├── cert-manager
│   │   ├── helm-values
│   │   │   └── cert-manager-values.yaml
│   │   ├── kustomization.yaml
│   │   └── resources
│   │       ├── ca-issuer.yaml
│   │       ├── namespace.yaml
│   │       ├── root-ca.yaml
│   │       └── selfsigned-issuer.yaml
│   ├── cinder
│   │   └── helm-values
│   │       └── cinder-values.yaml
│   ├── cloud-controller-manager
│   │   └── helm-values
│   │       └── cloud-controller-manager-values.yaml
│   ├── odoo
│   │   └── helm-values
│   │       └── odoo-values.yaml
│   └── traefik
│       ├── helm-values
│       │   └── traefik-values.yaml
│       ├── kustomization.yaml
│       └── resources
│           └── namespace.yaml
└── prod
    ├── cert-manager
    │   └── kustomization.yaml
    ├── cinder
    │   ├── kustomization.yaml
    │   └── resources
    │       └── storageclass.yaml
    ├── cloud-controller-manager
    │   ├── kustomization.yaml
    │   └── resources
    │       ├── cloud-config-secret.yaml
    │       └── cloud-config-secret.yaml.sample
    ├── odoo
    │   ├── kustomization.yaml
    │   └── resources
    │       ├── postgres-secret.yaml
    │       ├── postgres-service.yaml
    │       └── postgres-statefulset.yaml
    └── traefik
        └── kustomization.yaml

```


### 3.2 Le playbook Ansible

Fichier : `ansible/playbooks/kustomize.yml`

**Fonctionnement :**
1. Boucle sur les 4 premiers services (CCM, Cinder, cert-manager, Traefik) :
   - `kustomize build --enable-helm --load-restrictor=LoadRestrictionsNone <overlay>` | `kubectl apply -f -`
   - Avec 5 retries (delai 5s) pour gerer les CRDs non encore disponibles
2. Deploie Odoo avec le **cycle d'initialisation** :
   - `sed` active `odoo.init.enabled: true` dans les values
   - Apply kustomize Odoo (cree le Job d'init + la DB)
   - `kubectl wait --for=condition=complete job --all -n default --timeout=300s`
   - `sed` remet `odoo.init.enabled: false`
   - Redeploy Odoo en mode normal

### 3.3 Execution

```bash
# Depuis la racine du projet
ansible-playbook ansible/playbooks/kustomize.yml
```

**Flags optionnels :**

```bash
# Deployer un seul composant (debug)
ansible-playbook ansible/playbooks/kustomize.yml -e deploy_only=traefik

# Forcer la re-initialisation d'Odoo (DB existante = idempotent)
ansible-playbook ansible/playbooks/kustomize.yml -e odoo_init=true
```

> **Note :** Le playbook utilise `connection: local` -- pas besoin d'inventaire.
> Il reference le kubeconfig genere par Terraform via le chemin relatif `../../terraform/kubeconfig`.

### 3.4 Ce qui est deploye

**Cloud Controller Manager :**
- Secret `cloud-config` (credentials OpenStack + IDs reseau)
- Helm release `openstack-ccm` (tourne sur le control plane, tolere les taints)
- Gere le provisionnement des Load Balancers Octavia

**Cinder CSI :**
- StorageClass `csi-cinder-high-speed` (default, type high-speed, Retain, WaitForFirstConsumer)
- Helm release `cinder-csi` (DaemonSet sur tous les noeuds)
- Permet le provisionnement dynamique de volumes block OVH

**cert-manager :**
- Namespace `cert-manager`
- CRDs (ClusterIssuer, Certificate, etc.)
- ClusterIssuer `selfsigned-bootstrap` -> Certificate `root-ca` -> ClusterIssuer `ca-issuer`
- Chaine de confiance interne auto-signee

**Traefik :**
- Namespace `traefik`
- Deployment 2 replicas, IngressClass par defaut
- Service type LoadBalancer (provisionne par CCM -> IP publique via floating-network-id)
- Dashboard active

**Odoo :**
- Secret `odoo-postgresql-secret` (mot de passe DB)
- StatefulSet `odoo-postgresql` (PostgreSQL 16, PVC 8Gi Cinder)
- Service `odoo-postgresql` (ClusterIP 5432)
- Helm release `odoo` (Deployment 1 replica + nginx proxy sidecar)
- Ingress `odoo.mspr2` (TLS via ca-issuer, entrypoint websecure)
- Job `odoo-init` (modules base,web) execute une seule fois

---

## Post-deploiement et acces

### 5.1 Recuperer l'IP du Load Balancer

```bash
kubectl get svc -n traefik
```

**Sortie attendue :**

```
NAME      TYPE           CLUSTER-IP      EXTERNAL-IP    PORT(S)                      AGE
traefik   LoadBalancer   10.x.x.x       <LB_FIP>       80:3xxxx/TCP,443:3xxxx/TCP   5m
```

> Si `EXTERNAL-IP` reste `<pending>` plus de 5 minutes, verifier que `cloud-config-secret.yaml` contient les bons IDs reseau (cf. Phase 2).

### 5.2 Configurer le DNS local

```bash
# Ajouter dans /etc/hosts
echo "<LB_FIP> odoo.mspr2" | sudo tee -a /etc/hosts
```

### 5.3 Acceder a Odoo

```bash
# Test en CLI
curl -kI https://odoo.mspr2
```

Puis ouvrir dans un navigateur : **https://odoo.mspr2**

> Accepter le certificat auto-signe (CA interne `prod-cluster-ca`).

---

## Verification et depannage

### Checklist sante

```bash
export KUBECONFIG=terraform/kubeconfig

# Noeuds
kubectl get nodes -o wide                    # 3 Ready

# StorageClass
kubectl get sc                               # csi-cinder-high-speed (default)

# Issuers
kubectl get clusterissuer                    # ca-issuer + selfsigned-bootstrap = True

# Certificats
kubectl get certificate -A                   # root-ca = True

# Pods (tous Running sauf init = Completed)
kubectl get pods -A

# Services
kubectl get svc -n traefik                   # EXTERNAL-IP presente
kubectl get svc -n default                   # odoo-postgresql ClusterIP

# Ingress
kubectl get ingress -n default               # odoo.mspr2
```

### Problemes connus

| Symptome | Cause | Solution |
|----------|-------|----------|
| LB `EXTERNAL-IP` = `<pending>` | IDs reseau incorrects dans cloud-config | Refaire Phase 2, `kubectl delete secret cloud-config -n kube-system`, re-apply, restart CCM |
| LB a une IP privee (10.x.x.x) | `floating-network-id` manquant | Ajouter dans `[LoadBalancer]`, re-apply secret, restart CCM |
| Annotations LB obsoletes sur le Service | `kubectl apply` ne supprime pas les annotations existantes | `kubectl annotate svc traefik -n traefik <annotation>-` (tiret final = suppression) |
| `kubectl wait job` timeout (>300s) | Pull image `odoo:18.0` (~700MB) lent au 1er deploiement | Augmenter `--timeout=600s` dans le playbook (l.43) |
| Init job ne se relance pas au redeploy | L'ancien Job `Complete` existe encore | `kubectl delete job odoo-init -n default` avant re-run |
| Volume Cinder orphelin apres delete PVC | ReclaimPolicy = Retain | `kubectl delete pv <pv-name>` + `openstack volume delete <vol-id>` |
| Odoo renvoie 502 au demarrage | PostgreSQL pas encore ready | Attendre 30-60s, les probes vont converger |
| `odoo-values.yaml` reste `init.enabled: true` | Playbook interrompu entre le sed enable et disable | Remettre manuellement `enabled: false` |

### Logs utiles

```bash
# Cloud Controller Manager
kubectl logs -n kube-system -l app.kubernetes.io/name=openstack-cloud-controller-manager --tail=50

# Cinder CSI
kubectl logs -n kube-system -l app=openstack-cinder-csi --tail=50

# Traefik
kubectl logs -n traefik -l app.kubernetes.io/name=traefik --tail=50

# Odoo
kubectl logs -n default -l app.kubernetes.io/name=odoo -c odoo-service --tail=50

# PostgreSQL
kubectl logs -n default odoo-postgresql-0 --tail=50

# Init Job
kubectl logs -n default -l job-name=odoo-init --tail=100
```

---

## Teardown

### Suppression du cluster

```bash
cd terraform
source ../openrc.sh
terraform destroy
```

### Nettoyage des volumes Cinder orphelins (ReclaimPolicy = Retain)

```bash
# Lister les volumes
openstack volume list --status available

# Supprimer chaque volume orphelin
openstack volume delete <VOLUME_ID>
```

> **Attention :** `terraform destroy` ne supprime pas les volumes Cinder crees dynamiquement par le CSI.
> Toujours verifier et nettoyer manuellement apres un destroy.

### Nettoyage des PV Kubernetes (si cluster encore actif)

```bash
# Lister les PV Released (orphelins)
kubectl get pv | grep Released

# Supprimer
kubectl delete pv <PV_NAME>
```

---

## Valeurs actuelles (reference)

> Ces valeurs correspondent au deploiement actuel. A adapter si l'infra est recreee.

| Element | Valeur |
|---------|--------|
| Region OVH | GRA9 |
| Flavor CP | d2-4 |
| Flavor Worker | d2-2 |
| Talos version | v1.13.3 |
| Talos schematic | `376567988ad370138ad8b2698212367b8edcb69b5fd68c80be1f2ec7d603b4ba` |
| Kubernetes version | v1.36.1 |
| Cluster name | talos-ovh |
| Ext-Net name | Ext-Net |
| OS_USERNAME | `user-T8uZJPSkEV28` |
| OS_TENANT_ID | `c9c96e2a203d4c5aa6ebec129f44af3e` |
| k8s_network_id | `65784c3a-47ef-46c4-9168-74a2596fa6ce` |
| k8s_subnet_id | `31d11826-e0ad-421a-966b-ac4d45254998` |
| Ext-Net (floating-network-id) | `b2c02fdc-ffdf-40f6-9722-533bd7058c06` |
| Control Plane FIP (API) | `79.137.120.183` |
| Traefik LB FIP (HTTP/S) | `79.137.26.127` |
| Domaine Odoo | `odoo.mspr2` |
| Mot de passe PostgreSQL | `changeme123!` |
