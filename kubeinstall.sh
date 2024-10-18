get_latest_release() {
  curl --silent "https://api.github.com/repos/$1/$2/releases/latest" \
    | grep '"tag_name":' \
    | sed -E 's/.*"([^"]+)".*/\1/'
}

install_cni () {

CNI_VERS=$(get_latest_release containernetworking plugins) # v1.5.0
PKG_ARCH="$(dpkg --print-architecture)"
CNI_PKG="cni-plugins-linux-$PKG_ARCH-$CNI_VERS.tgz"
CNI_URL_PATH="releases/download/$CNI_VERS/$CNI_PKG"
CNI_URL="https://github.com/containernetworking/plugins/$CNI_URL_PATH"

# download
curl -fLo $CNI_PKG $CNI_URL

# install
sudo mkdir -p /opt/cni/bin
sudo tar Cxzvf /opt/cni/bin $CNI_PKG
}

install_runc () {

RUNC_VER=$(get_latest_release opencontainers runc) # v1.1.12
PKG_ARCH="$(dpkg --print-architecture)"
RUNC_URL_PATH="releases/download/$RUNC_VER/runc.$PKG_ARCH"
RUNC_URL="https://github.com/opencontainers/runc/$RUNC_URL_PATH"

# download
curl -fSLo runc.$PKG_ARCH $RUNC_URL

# install
sudo install -m 755 runc.$PKG_ARCH /usr/local/sbin/runc

}



install_containerd () {
# variables used to compose URLS (avoid vertical scrollbars)
CONTAINERD_VER=$(get_latest_release containerd containerd) # v1.7.17
PKG_ARCH="$(dpkg --print-architecture)"
CONTAINERD_PKG="containerd-${CONTAINERD_VER#v}-linux-$PKG_ARCH.tar.gz"
CONTAINERD_URL_PATH="releases/download/$v$CONTAINERD_VER/$CONTAINERD_PKG"
CONTAINERD_URL="https://github.com/containerd/containerd/$CONTAINERD_URL_PATH"

# download package
curl -fLo $CONTAINERD_PKG $CONTAINERD_URL
# Extract the binaries
sudo tar Cxzvf /usr/local $CONTAINERD_PKG

echo "Installing containerd configuration file"
sudo mkdir -p /etc/containerd/
 containerd config default > /etc/containerd/config.toml
wget https://raw.githubusercontent.com/containerd/containerd/main/containerd.service -o /etc/systemd/system/containerd.service


}

install_kubeadm () {

# Install prerequisite packages
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

# Determine version of Kubernetes (instructions may vary)
# This is tested with v1.30.
K8S_VERS="v1.31"

# variables to make code readible
K8S_GPG_KEY_PATH="/etc/apt/keyrings/kubernetes-apt-keyring.gpg"
K8S_APT_REPO_URI="https://pkgs.k8s.io/core:/stable:/$K8S_VERS/deb/"

# Download signing key
[[ -d /etc/apt/keyrings ]]  || sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/$K8S_VERS/deb/Release.key \
 | sudo gpg --dearmor -o $K8S_GPG_KEY_PATH

# Add the appropriate Kubernetes apt repository

echo "deb [signed-by=$K8S_GPG_KEY_PATH] $K8S_APT_REPO_URI /" \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Update the apt package index, install kubelet, kubeadm and kubectl, and pin their version
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Enable the kubelet service before running kubeadm (optional)
sudo systemctl enable --now kubelet

}

install_k8s () {
sudo kubeadm config images pull
sudo kubeadm init --pod-network-cidr=10.244.0.0/16
 mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
        sudo chown $(id -u):$(id -g) $HOME/.kube/config

}

install_cilium_cli () {
  CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
cilium install --version 1.16.3

}

install_flanell () {
FLANNEL_VERS=$(get_latest_release flannel-io flannel) # v0.25.3
FLANNEL_URL_PATH="releases/download/$FLANNEL_VERS/kube-flannel.yml"
FLANNEL_URL="https://github.com/flannel-io/flannel/$FLANNEL_URL_PATH"

kubectl apply --filename $FLANNEL_URL
}


#install_containerd
#install_runc
#install_cni
#install_kubeadm
#install_k8s
install_cilium_cli
