#Pod info
kubectl get po kubia-27sbq -o yaml

#applying decriptor 
kubectl apply -f kubia-manual.yaml

#To see info
kubectl explain deployment.spec 