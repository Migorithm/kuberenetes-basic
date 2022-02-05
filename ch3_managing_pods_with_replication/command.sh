#Labeling
kubectl label pod "pod-name" label-key=value

#Check labels
kubectl get pods --show-labels

#Overwrite labels
kubectl label pod "pod-name" existing-key=different-value --overwrite

#Configuring kubectl edit to use the text editor you prefer
export KUBE_EDITOR="/usr/bin/vi"

#Prevent cascade effect on deleting controller
kubectl delete rc "rc_name" --cascade=false

#Show all pods including completed one in a namespace
kubectl get po --show-all #(or -a)