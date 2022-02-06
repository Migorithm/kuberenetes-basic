# Services: enabling clients to discover and talk to pods
This chapter covers:
- Creating Service resources to expose a group of pods *at a single address*
- Discovering services in the cluster
- Exposing services to external clients
- Connecting to external services from inside the cluster
- Controlling whether a pod is ready to be part of the service or not
- Troubleshooting services

## Why and What Service?
Pods needs a way of finding other pods if they want to consume the services they provide. In non-Kubernetes world, where sysadmin would configure each client app by specifying the exact IP address or hostname of the server providing the service in the client's configuration files, doing the same wouldn't work in Kubernetes because:
- ***Pods are ephemeral***
- ***Kubernetes assigns an IP address to a pod after the pod has been scheduled to a node and before it's started***
- ***Horizontal scaling means multiple pods may provide the same service*** so clients shouldn't care how many pods are backing the service and their IPs.
<br>

For the above reasons, we need some resources that have ***single and constant point of entry*** to a group of pods providing the same service; hence the name ***Service***. To put it in another way, each Service has an IP address and port that never change while the Service exists.<br><br>

Let's take this example. You have frontend web server and backend database server. There may be multiple pods that act as frontend which clients shouldn't care about and only a single DB pod. <br>
In this particular situation, by creating a *Service for the frontend* pods and configuring it to be accessible from outside the cluster, you expose a single, constant IP address. Similarly, by also creating a *Service for backend* pod, you create stable address for the backend pod.

### Creating services
Again, a Service can be backed by more than one pod. *Connections to the service are load-balanced* across all the backing pods. But how exactly do you define which pods are part of the service and which aren't? The *Labels and Selectors* are used again as core mechanism. To test out service, let's create ReplcationController which run three instances of the pods again. 

```yaml
apiVersion: v1
kind: ReplicationController
metadata:
  name: migo-rc
spec:
  replica: 3
  selector:        
    app: migo-pod
  template:
    metadata:
      labels: 
        app: migo-pod
    spec:
      containers:
        - name: migo-con
          image: saka1023/k8s
          ports:
            - containerPort: 8080
```
```sh
kubectl apply -f "rc name"
```

Now, let's create a Service through a YAML descriptor.
*svc.yaml*
```yaml
apiVersion: v1
kind: Service
metadata:
  name: migo-svc
spec:
  ports:
    - port: 80          #The port this service will be available on
      targetPort: 8080  #The container port the service will forward to
  selector:
    app: migo-pod       #All pods with the app=migo-pod label will be part of this service
```
```sh
kubectl apply -f "svc.yaml"
```
<br>

Let's examine our new service:
```sh
kubectl get svc
NAME         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
kubernetes   ClusterIP   10.96.0.1       <none>        443/TCP   11d
migo-svc     ClusterIP   10.109.52.156   <none>        80/TCP    7s
```
The list shows that IP address assigned to the service is 10.109.52.156. Because this is the *ClusterIP*, it's only accessible from inside the cluster.<br><br>

*Testing the Service from within the cluster*<br>
You can send requests to your service in a few ways:
- Create a pod that sends the request to the service's clusterIP and log the response.
- You can ssh into one of the Kubenetes nodes and use the curl command
- You can execute the *curl* command inside one of your existing pods through the *kubectl exec* command.
Let's go for the last option.
```sh
kubectl get pods
NAME                              READY   STATUS    RESTARTS   AGE
migo-deployment-cc4c757f6-2mpxm   1/1     Running   0          14h
migo-deployment-cc4c757f6-fffcr   1/1     Running   0          14h
migo-deployment-cc4c757f6-kctlm   1/1     Running   0          14h  #take this one

kubectl exec migo-deployment-cc4c757f6-kctlm -- curl -s http://10.109.52.156
You've hit migo-deployment-cc4c757f6-fffcr
```
You will see, every time you execute the command, service redirects HTTP connection to a randomly selected pod.

### Configuring session affinity on the Service
If you want all requests made by a certain client to be redicted to the same pod every time, you can set the service's ***sessionAffinity*** property to ClientIP(default to None):
```yaml
apiVersion: v1
kind: Service
metadata:
  name: migo-svc
spec:
  sessionAffinity: ClientIP  #this makes traffic from same client go to the same pod
  ports:
    - port: 80
      targetPort: 8080
  selector:
    app: migo-pod
```
Kubernetes has no cookie-based session affinity option as it doesn't operate on HTTP level. Service instead deals with TCP and UDP packets and don't care about payload they carry.

### Exposing mutiple ports in the same service
Even if your pods listened on two ports - say 8080 for HTTP and 8443 for HTTPS, you don't need to create two different services in such cases. The spec for a multi-port Service is shown in the following listing:
```yaml
apiVersion: v1
kind: Service
metadata: 
  name: migo-svc-multiport
spec:
  ports:
    - name: http
      port: 80
      targetPort: 8080
    - name: https
      port: 443
      targetPort: 8443
  selector:
    app: migo-pod
```
As you can see, when creating Service with multiple ports, you MUST specify a name for each port. Plus, the label selector applies to the service as a whole - it can't be configured for each port individually. If you want different ports to map to different subsets of pods, you need to create two services.<br>

### using NAMED pods
You've referred to targetPort by its number, but you can also give a name to each pod's port and refer to it by name in the service spec. For example, suppose your pod defines names for its ports as shown in the following listing:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: migo-pod
  labels: 
    app: migo-pod
spec:
  containers:
    - name: migo-con
      image: saka1023/k8s
      ports:
        - name: http
          containerPort: 8080
        - name: https
          containerPort: 8443
```
And then you refer to named ports in a service
```yaml
apiVersion: v1
kind: Service
spec:
  ports:
    - name: http
      port: 80
      targetPort: http  #Port 80 is mapped to the container's port called 'http'
    - name: https
      port: 443
      targetPort: https #Port 443 is mapped to the container's port called 'https'
```
The biggest benefit of doing this is it enables you to change port numbers later without having to change the service spec. 
