### Introducing pods
#### Why not just container?
When app consists of multiple process. They will communicate through:
- Inter-Process Communication(IPC)
- Locally stored files
Either way, It will require them to be on a same machine.<br><br>

You may think it makes sense then to run multiple processes in a single container, but you shoudln't do that because:
- Otherwise it's your responsibility to take care of **running processes**, and their **logs**.

#### Understanding Pods
Because you're not supposed to group multiple processes into a single container, it's obvious you need another *higher-level construct* that will:
- Allow you to bind containers
- Manage them as a single unit by providing them with the same environment.
<br>

The question is, however, how *isolated* are containers in a Pod? Simply put, you want them to share *CERTAIN* resources but *NOT ALL*.
- K8S achieves this goal by configuring to have all containers in a pod share the same set of Linux namespaces instead of each container having its own set.
- They share:
    - Network namespace : Therefore, **IP** and **port** spaces. 
        - In fact, containers of different pods can never run into port conflicts.
        
        **Flat Network**
        - All pods in a K8S cluster reside in a single flat, shared, network address space, meaning every Pod can access every other pod at the other Pod's IP address.
        - No NAT(Network Address Translation) gateways exist between them. 
    - UTS namespace : Unix Time Sharing that allows a single system to have different host and domain name to different process
    - IPC namespace
- They DON'T share:
    - filesystem
        - This could be changed when we use *volume* though.
<br>

#### Check your understanding: Do you think a multi-tier application consisting of frontend application server and backend database should be configured as a single Pod?
You CAN do that but it's not the best way because:
- Each differnt application requires different computational resources. Separating them ***improves the utilization of your infrastructure***.
- A pod is a basic unit of ***scaling***. A lot of time, frontend servers are stateless whereas databases are stateful; therefore harder to scale out. 

#### Then when to use multiple containers in a pod?
- When the application consists of one main process and other complementary processes.
- For example, web server that takes files from a directory and additional container(*sidecar container*) that downloads the file periodically.
- Other examples would include log rotators and collectors, data processors and others.

### Creating Pods from YAML or *kubectl run* command
Defining K8S objects from YAML files makes it possible to store them in a *version control system*, with all the benefits it brings. So, this is a recommended way.<br>

#### Examing a YAML descriptor from an existing pod
```sh
kubectl get po kubia-27sbq -o yaml
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    component: kubia
  name: kubia-27sbq
spec:
  containers:
  - image: saka1023/kubia
    name: kubia
    ports:
    - containerPort: 8080
      protocol: TCP
```
Bear in mind that it was rather huge verbosity - I omitted quite a lot.<br>
But don't worry, things I've written above are indeed the main parts. There are three important part as follows:
- ***metadata*** : includes the name, namespace, labels.
- ***spec*** : include containers, volumes, and others.
- ***status*** : this contains the current information about the running pod. You'll never need to provide this manually.

#### Creating a simple YAML descriptor for a pod
*kubia-manual.yaml*
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: kubia-manual
spec:
  containers:
    - image: saka1023/kubia
      name: kubia
      ports:
        - containerPort: 8080
```

apply above file:<br>
```sh
kubectl apply -f kubia-manual.yaml
pod/kubia-manual created

kubectl get po
NAME           READY   STATUS    RESTARTS   AGE
kubia-27sbq    1/1     Running   0          23h
kubia-manual   1/1     Running   0          3m12s
```

### Using kubectl explain to discover possible API object fields
When preparing a manifest, you can either turn to Kuberenetes documentation or use:<br>
***kubectl explain*** <br>
For example, 
```sh
kubectl exaplain deployments
KIND:     Deployment
VERSION:  apps/v1

FIELDS:
  apiVersion
  kind
  metadata
  spec
  status
```
<br>
For more information,
```sh
kubectl explain deployments.spec
....
FIELDS:
  minReadySeconds 
  paused
  replicas
  ....
```

### Retrieving the whole definition of a running POD or other object
After creating object, you can list all them up by:
```sh
kubectl get all
NAME                READY   STATUS    RESTARTS   AGE
pod/rc-prac-8j78z   1/1     Running   0          4d20h
```
<br>
Then you can ask K8S for the full YAML of the object by:
```sh
kubectl get po rc-prac-8j78z -o yaml
```

### Retrieving a POD's log
To see your pod's log:
```sh
kubectl logs pod/rc-prac-8j78z
Received request from ::ffff:127.0.0.1
Received request from ::ffff:127.0.0.1
Received request from ::ffff:127.0.0.1
```
***Where does the log from?*** <br>
-- Well, it's actually from the image we created. 
```js
...
var handler = function(request,response){
    console.log("Received request from " + request.connection.remoteAddress);
    response.writeHead(200);
    response.end("You've hit "+os.hostname()+"\n")
};
...
```
Container logs are automatically rotated daily and every time the log file reaches 10MB in size.

### Sending requests to the pod
Previously we used *kubectl expose* command to create a service<br>
But service itself deserves a whole chapter so we're going to have other ways of<br>
connecting to a pod for *testing* and *debugging* purposes.<br>
<br>
Let's list up the pods first and get some detail of one of the pods:
```sh
kubectl get pods
NAME            READY   STATUS    RESTARTS   AGE
rc-prac-8j78z   1/1     Running   0          4d21h
rc-prac-kv2pg   1/1     Running   0          4d21h
rc-prac-shzkr   1/1     Running   0          4d21h

kubectl describe po rc-prac-8j78z
...
...
IP:     172.17.0.4
```
By now, you should know that each of these pods has their own ip and the same port.<br>
if you curl one of them by it will just hang as follows:
```sh
curl 172.17.0.4:8080

```
If you use *port-forward* however, it'll work like a charm.
```sh
kubectl port-forward rc-prac-8j78z 8888:8080
Forwarding from 127.0.0.1:8888 -> 8080
Forwarding from [::1]:8888 -> 8080

#different terminal
curl localhost:8888
You've hit rc-prac-8j78z
```

## Organizing pods with labels
When the number of pods increases, the need for categorizing them into subsets<br>
becomes more and more evident. Organizing pods and all other K8S obejcts is done through ***labels***<br><br>
Simply put, it's an arbitrary key-value pair you attach to a resource and utilized<br>
when selecting resources using ***label selectors.*** A resource can have more than one label.<br><br>

Let's label pods with the following two:
- app : which specifies which app, component, microservice the pod belongs to.
- rel : short for release, which shows if application is a stable, beta, or canary.
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: kubia-manual-v2
  labels:
    app: api
    rel: beta
spec:
  containers:
    - image: saka1023/k8s
      name: migo
      ports:
        - containerPort: 8080
```

Let's create pod:
```sh
kubectl apply -f pod_with_labels.yaml
```

To see labels attached to pods:
```sh
kubectl get po --show-labels
NAME              READY   STATUS    RESTARTS   AGE     LABELS
kubia-manual-v2   1/1     Running   0          3m16s   app=api,rel=beta
```

If interested only in certain labels:
```sh
kubectl get po -L app,rel
NAME              READY   STATUS    RESTARTS   AGE     APP   REL
kubia-manual-v2   1/1     Running   0          4m51s   api   beta
```

### Modifying labels of existing pods
```sh
kubectl label po kubia-manual-v2 rel=alpha --overwrite
pod/kubia-manual-v2 labeled
```

## Listing subsets of pods through label selectors
Obviosly, if not for selectors, labels are useless. Selectors allow you to select<br>
a subset of pods tagged with certain labels and perfrom an operation on those pods.<br>
A label selector can select resources based on whether the resource
- Contains a label with a ***certain key***
- Contains a label with a certain ***key and value***
- Contains a label with a certain ***key but with a value not equal*** to the one you specify 

Hands on practice:
```sh
# key value pair
kubectl get po -l rel=alpha
NAME              READY   STATUS    RESTARTS   AGE
kubia-manual-v2   1/1     Running   0          12m

# only key
kubectl get po -l rel
NAME              READY   STATUS    RESTARTS   AGE
kubia-manual-v2   1/1     Running   0          12m

# not having the specified key
kubectl get po -l '!rel'
NAME            READY   STATUS    RESTARTS   AGE
rc-prac-8j78z   1/1     Running   0          4d21h
rc-prac-kv2pg   1/1     Running   0          4d21h
rc-prac-shzkr   1/1     Running   0          4d21h

# certain key with the value not matched
kubectl get po -l rel!=beta
NAME              READY   STATUS    RESTARTS   AGE
kubia-manual-v2   1/1     Running   0          15m
rc-prac-8j78z     1/1     Running   0          4d21h
rc-prac-kv2pg     1/1     Running   0          4d21h
rc-prac-shzkr     1/1     Running   0          4d21h

# in
kubectl get po -l 'rel in (alpha,beta)' 
NAME              READY   STATUS    RESTARTS   AGE
kubia-manual-v2   1/1     Running   0          16m

# not in 
kubectl get po -l 'rel notin (alpha,beta)'
NAME            READY   STATUS    RESTARTS   AGE
rc-prac-8j78z   1/1     Running   0          4d21h
rc-prac-kv2pg   1/1     Running   0          4d21h
rc-prac-shzkr   1/1     Running   0          4d21h
```

## Using labels and selectors to constrain pod scheduling
Normally, we don't contrain pods from scheduling randomly.<br>
Certain cases exist, however, where you want to have at least a little say in where<br>
a pod should be scheduled. For example: 
- when your hardware infra isn't homogenous.
- when you need to schedule pods performing intensive GPU-based computation only to nodes that provide the required GPU acceleration.
How it's done? It's through ***node labels***.

### Using labels for categorizing worker nodes.
Labels can be attached to any K8S object including nodes. When ops team adds a new node,<br>
they usually categorize the node by attaching labels specifying the type of hardware.<br>
You can do the simiar things by:
```sh
kubectl label node minikube-worker gpu=true
```

### Scheduling pods to specific nodes
The following menifest will give you a sense. 
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: gpu-intenstive
spec:
  nodeSelector:
    gpu: "true"
  containers:
    - image: saka1023/k8s
      name: migo
```      

## Using namespaces to group resources
Each obejct can have multiple labels. It means those groups of objects can overlap.<br>
Working with the cluster, if you don't specify a lable selector, you'll always see all objects.<br>
But what about times when you want to split objects into separate, non-overlapping groups?<br>
You may want to only operate inside one group at a time. For this, K8S groups objects into namespaces. <br>
However, don't mistake this for Lunux namespaces. Kubernetes namespaces provide a scope for objects names.<br>

### Discovering other namespaces and their pods
First, let's list all namespaces in your cluster:
```sh
kubectl get ns
NAME                   STATUS   AGE
default                Active   8d
kube-public            Active   8d
kube-system            Active   8d
```
Up to this point, you've operated only in the ***default*** namespace. <br>
But as you can see from the list, ***kube-public*** and ***kube-system*** also exist.<br>
Let's look at tehe pods that belong to the ***kube-system***:
```sh
kubectl get po --namespace kube-system
NAME                               READY   STATUS    RESTARTS     AGE
coredns-64897985d-vfq8f            1/1     Running   0            8d
etcd-minikube                      1/1     Running   0            8d
kube-apiserver-minikube            1/1     Running   0            8d
...

```
***TIP*** You can also use *-n* instead of *--namespace* <br><br>

If several users or groups of users are using the same Kubernetes cluster, and they<br>
each manage their own distinct set of resources, they should each use their own namespace.<br>
This way, you get the following benefits: 
- No need to take any special care not to inadvertently modify or delete other users' resources. 
- You are able to allow only certain users to have access to particular resources. 
  - You will learn this in chapter 11 through 13.

### Creating a namespace
A namespace is a Kubernetes resource like any other, so you can create it by posting a YAML file: 
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: custom-namespace
```

Apply the above menifesto
```sh
kubectl apply -f custom-namespace.yaml
namespace "custom-namespace" created
```

### Managing objects in other namespaces
To create resources in the namespace you've created, either:
- add a ***namespace: custom-namespace*** entry to the ***metadata*** section or
- specify the namespace when creating the resource with the ***kubectl apply*** command.
```sh
kubectl apply -f menifesto.yaml -a custom-namespace
```

***TIP!***  To quickly switch to a different namespace, apply :
```sh
alias kcd='kubectl config set-context $(kubectl config current-context) --namespace'
```
Then you can switch between namespaces using ***kcd some-namespace***.<br>

## Stopping and removing pods
### Deleting a pod by name
```sh
kubectl delete po <pod_name>
```
By deleting a pod, you're instructing Kubernetes to send a *SIGTERM* signal to the process<br> and wait a certain number of seconds(30 by default) for it to shut down *gracefully*.<br>
If it doesn't shut down in time, the process is then killed through *SIGKILL*. 

### Deleting pods using label selectors
```sh
kubectl delete po -l key=value
```

### Deleting pods by deleting the whole namespace
If you delete a namespace, the pods within that namespace will be deleted too. 
```sh
kubectl delete ns custom-namespace
namespace "custom-namespace" deleted
```