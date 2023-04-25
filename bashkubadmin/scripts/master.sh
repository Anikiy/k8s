#!/bin/bash
#
# Настройка Node Master

set -euxo pipefail

# Если вам нужен публичный доступ к серверу API с использованием общедоступного IP-адреса сервера, измените PUBLIC_IP_ACCESS на true.
PUBLIC_IP_ACCESS="false"
NODENAME=$(hostname -s)
POD_CIDR="192.168.0.0/16"

# Pull образа

sudo kubeadm config images pull

# Инициализирует kubeadm на основе PUBLIC_IP_ACCESS="false"

if [[ "$PUBLIC_IP_ACCESS" == "false" ]]; then
    
    MASTER_PRIVATE_IP=$(ip addr show eth0 | awk '/inet / {print $2}' | cut -d/ -f1)
    sudo kubeadm init --apiserver-advertise-address="$MASTER_PRIVATE_IP" --apiserver-cert-extra-sans="$MASTER_PRIVATE_IP" --pod-network-cidr="$POD_CIDR" --node-name "$NODENAME" --ignore-preflight-errors Swap
# --ignore-preflight-errors Swap можно убрать, так как work node отключили swap

# Инициализирует kubeadm на основе PUBLIC_IP_ACCESS="true"

elif [[ "$PUBLIC_IP_ACCESS" == "true" ]]; then

    MASTER_PUBLIC_IP=$(curl ifconfig.me && echo "")
    sudo kubeadm init --control-plane-endpoint="$MASTER_PUBLIC_IP" --apiserver-cert-extra-sans="$MASTER_PUBLIC_IP" --pod-network-cidr="$POD_CIDR" --node-name "$NODENAME" --ignore-preflight-errors Swap

else
    echo "Error: MASTER_PUBLIC_IP has an invalid value: $PUBLIC_IP_ACCESS"
    exit 1
fi

# ВСПОМНИТЕ О КОМАНДЕ С ТОКЕН для присоединения через TLS сертификаты между master-node и work-node
# Заново создать токен: kubeadm token create --print-join-command

# Настройка базового конфига Node Master

mkdir -p "$HOME"/.kube
sudo cp -i /etc/kubernetes/admin.conf "$HOME"/.kube/config
sudo chown "$(id -u)":"$(id -g)" "$HOME"/.kube/config

# Устанавливает сетевой плагин Claico  

curl https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/calico.yaml -O

kubectl apply -f calico.yaml

# Для проверки состояние работоспособности компонентов кластера: kubectl get --raw='/readyz?verbose'
# Для получения информации о кластере: kubectl cluster-info 
# Добавлен ли узел, "none" для work-node, : kubectl get nodes 
