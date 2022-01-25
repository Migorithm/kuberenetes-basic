#Note that Docker or containerd must be preinstalled
$ curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube_latest_amd64.deb
$ sudo dpkg -i minikube_latest_amd64.deb


#Spinning up Multi-node clusters using minikube
$ minikube start
# -p, --profile='minikube': 
#  The name of the minikube VM being used. 
#  This can be set to allow having multiple instances of minikube independently.

#auto completion
echo 'alias kubectl="minikube kubectl --"'>>~/.bashrc
echo 'source <(kubectl completion bash)' >>~/.bashrc