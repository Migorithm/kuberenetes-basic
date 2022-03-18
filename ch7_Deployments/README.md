## Deployments: updating applications declaratively
Eventually, you're going to want to update your app. This chapter covers how to update apps running in a Kubernetes cluster and how Kubernetes helps you move toward a true zero-downtime update process. Deployments enable declarative application updates. 

### Updating applications running in pods
The following is how a basic application works in K8s.<br>
<img src="basic_outline.png"><br>

Initially, the pods run the first version(v1) of your application. And imagine now you developed a newer version tagged as v2.<br>
Because you can't change an existing pod's image after the pod is creted, you need to remove the old pods and replace them.<br>
For that, you have two ways:
- Delete all existing pods first and then start the new ones
- Start new ones and once they're up, delete the old ones. 
<br>

The first option will obviously lead to a short period of down-time. But at the same time, the second option requires your app<br>
to handle running two versions of the app, resulting in quite a lot of overhead.<br><br>

#### Deleting old pods and replacing them with new ones
<img src="modifying_tags.png"><br><br>

You can easiliy replace old one with new one by modifying the pod template so it refers to version *v2*.<br>
This is the easiest if you wan accept the short downtime.

#### Spinning up new pods and then deleting the old ones
<img src="switing_from_old_to_new.png"><br><br>

Pods are fronted by a Service. It's possible to have the Service front only the initial version.<br>
You first bring up the pods running the new version and then you can change the Service's label selector.<br>
This is called a ***blue-green deployment.***

    You can change a Service's pod selector with the "kubectl set selector"


#### Rolling update using two ReplicationControllers(Deprecated completely)
<img src="rolling_update_with_two_rc.png"><br><br>


#### Running the app and exposing it through a service using a single YAML file
kubia-rc-and-service-v1.yaml
```yaml
apiVersion: v1
kind: ReplicationController
metadata:
  name: migo-v1
spec:
  replicas: 3
  templates:
    metadata:
      name: migo
      labels:
        app: migo
    spec:
      containers:
        - image: saka1023/node_app:v1
          name: migo-con
---
apiVersion: v1
kind: Service
metadata:
  name: migo
spec:
  type: LoadBalancer
  selector:
    app: migo
  ports:
    - port: 80
      targetPort: 8080
```
Go ahead and post the YAML to k8s. Note that if you use LoadBalancer in Minikube, use "minikube tunnel" command.<br>

Now you'll create version 2 of the app. For that, all you need to do is change the response to say, "This is v2".

```js
const http = require("http");
const os = require("os");
console.log("Kubia server starting...");

var handler = function(request,response){
    console.log("Received request from "+ request.connection.remoteAddress);
    response.writeHead(200);
    response.end("This is v2 running in pod "+ os.hostname() + "\n")
}

var www = http.createServer(handler);
www.listen(8080);
```

#### Understanding why kubectl rolling-update is now obsolete
Most importantly, it's kubectl *client*, NOT *master* who performs all the update steps which causes a problem.<br><br>

Why is it such a bad thing? 
- What if you lost network connectivity while kubectl was performing the update?
  - Then the update process would be interrupted mid-way, resulting in Pods and ReplicationControllers being in intermediate state. 
- It is imperative as opposed to declarative
  - You never tell Kubernetes to add an additional pod or remove an excess one - you change the number of desired replicas and that's it. 
  - Similarly, you will want to change the image tag.

And these are what drove the introduction of a new resource called **Deployment.**


### Using Deployment for updating apps declaratively
When you create a Deployment, a ReplicaSet resource is created underneath so when using a Deployment, the actual pods are created and managed by the Deployment's ReplicaSets, NOT by Deployment directly.<br><br>

You want to use Deployment when you need to update app as without them ReplicationController should be added and coordinate at least two controllers to dance around each other without stepping on each other's toes -- which is error prone.<br><br>

Using a Deployment instaed makes things much easier. In fact, it's not the Deployment resource itself but the controller process running in the Kubernetes control plane who does the work though. 

#### Creating a Deployment
Similar to Replication controller, it is composed of label selector, a desired replica count, and a pod template. Plus, it also contains a filed which specifies a deployment strategy in case of the update.<br><br>

**Creating a Deployment Manifest**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: migo-deployment
spec:
  replicas: 3
  selector:       # required
    matchLabels:  # different from RC
      app: migo
  template: 
    metadata:
      name: migo-pod
      labels:
        app: migo
    spec:
      containers:
      - image: saka1023/node_app:v1
        name: migo-con
```

```sh
kubectl apply -f <deployment_manifest.yaml> --record
```
Be sure to include the --record command-line option when creating it. This records the command in the revision history, which will be useful later. 

##### Displaying the status of the deployment rollout
```sh
kubectl rollout status deployment migo-deployment

deployment "migo-deployment" successfully rolled out
```

##### Understanding how Deployments create ReplicaSets which then create the Pods
Take note of the names of the following pods:
```sh
kubectl get pods

NAME                               READY   STATUS    RESTARTS   AGE
migo-deployment-8694db8849-6vqf2   1/1     Running   0          3m39s
migo-deployment-8694db8849-p6gvm   1/1     Running   0          3m39s
migo-deployment-8694db8849-sfvrn   1/1     Running   0          3m39s
```

When you create pods through RC, their names were composed of the name of the RC plus a randomly generated string.<br>
And the three pods above created by Deployment include an additional numeric value in the middle.<br><br>

The number corresponds to the hashed value of the pod template in the Deployment and the ReplicaSet managing these Pods.<br>
So by now, you should be able to search for ReplicaSet behind it.<br>
```sh
kubectl get rs

NAME                         DESIRED   CURRENT   READY   AGE
migo-deployment-8694db8849   3         3         3       7m6s
```

And there you go, the name is matched to the name of the pods. As you will see later, a Deployment creates multiple ReplicaSets - one for each version of the pod.

