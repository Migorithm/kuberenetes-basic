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
