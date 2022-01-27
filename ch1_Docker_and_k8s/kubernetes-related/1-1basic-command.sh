# To boot up minikube
minikube start --nodes 2 -p multinode-demo

# set cluster context
kubectl config set-cluster multinode-demo

# See nodes
kubectl get nodes


#run your app on kubernetes
kubectl run kubia --image=saka1023/kubia --port=8080


#To apply ReplicationController yaml, 
kubectl apply -f 1-2rc.yaml

#To expose the above resource outside
minikube tunnel #-- This will be running a process, creating network route on the host to the service CIDR
kubectl expose rc rc_name --type=LoadBalancer --name kubia-http

#To see current External-IP
kubectl get svc
"NAME         TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)          AGE
 kubia-http   LoadBalancer   10.110.225.11   10.110.225.11   8080:32212/TCP   11s"

#To see if it works
curl <external_ip>:8080
# -> You've hit kubia-2v4zs


#horizontal scaling
kubectl scale rc kubia --replicas=3

#hit service ip again
curl 10.110.225.11:8080
# You've hit kubia-2v4zs
curl 10.110.225.11:8080
# You've hit kubia-2kvpf

#Q1 how to make it round-robin? -- Ingress