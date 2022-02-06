# Replication nnd other controllers: deploying managed pods
This chapter covers:
- Keeping pods healthy
- Running multiple instances of the same pod
- Reschedulling pods after a node fails
- Scaling pods horizontally
- Running batch jobs
- Schedulling jobs to run periodically or once in the future
<br>
Pods represent the basic deployable unit in Kubernetes. But reality is you almost NEVER<br>create pods directly. Instead, you create other types of resources, such as:<br>

- Replication controllers
- Deployments

## Keeping pods healthy
One of the main benefits of using K8s is the ability to give it a list of containers and let it keep those containers running somewhere in the cluster. As soon as a pod is scheduled to a node, the ***Kubelet*** on that node will run its containers. So, even if the container's main process crashes, K8s will restart itt automatically.<br><br>

But sometimes apps stop working without their process crashing. For example, a Java app with a memory leak will start throwing OutOfMemory Errors but the JVM process will keep running. It would be great to have a way for an app to signal to K8s that it's no longer functioning properly. 

### Introducing Liveness probes
You can specify a liveness probe for each container in the pod's specification. K8s then periodically execute the probe and restart the container if the probe fails. K8S can probe container using one of the following mechanisms:
- HTTP GET probe
- TCP Socket probe
- Exec probe

### Creating an HTTP-based liveness probe
Let's add a liveness probe to your Node.js app. But because this Node.js app is too simple to ever fail, you'll need to make the app fail artificially.(Say, you make it return 500 Internal Server Error code after fifth one.)<br><br>
*app.js*
```js
const http = require('http');
const os = require('os');

console.log("Migo server starting...");

var requestCount = 0;

var handler = function(request, response) {
  console.log("Received request from " + request.connection.remoteAddress);
  requestCount++;
  if (requestCount > 5) {
    response.writeHead(500);
    response.end("I'm not well. Please restart me!");
    return;
  }
  response.writeHead(200);
  response.end("You've hit " + os.hostname() + "\n");
};

var www = http.createServer(handler);
www.listen(8080);
```
<br>

After pushing the docker image, let's create pod menifest that includes an HTTP GET liveness probe.
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: migo-liveness
spec:
  containers:
    - image: saka1023/liveprobe
      name: migo-liveness
      livenessProbe:
        httpGet:
          path: /        # The path to request in the HTTP request
          port: 8080     # The network port the probe should connect to 
```

### Seeing a liveness probe in action
Around a minute after pod's creation, the container will be restarted as follows. 
```sh
NAME            READY   STATUS    RESTARTS      AGE
migo-liveness   1/1     Running   1 (82s ago)   3m12s
```
***TIPS!*** - You can see why the container had to be restarted by looking at *kubectl describe*
```sh
kubectl describe po migo-liveness
...
    Last State:     Terminated
      Reason:       Error
      Exit Code:    137     
      Started:      Sat, 05 Feb 2022 09:23:11 +0000
      Finished:     Sat, 05 Feb 2022 09:24:58 +0000
...
# 137 is a sum of two numbers. 128 + x where x is the signal number. In this example,
# x equals 9, which is the number of the SIGKILL signal. 

    Restart Count:  4
    Liveness:       http-get http://:8080/ delay=0s timeout=1s period=10s 
    #success=1 #failure =3

# delay=0s part shows that the proving begins immediately after the container is started.
# timeout=1s means the container must return a response in 1sec
# period=10s means how frequently the container will be probed. In this example, every 10s
# failure=3 means the container is restarted after probe fails three consecutive times.
```

The parameters like the ones shown above can be customized as follows:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: migo-liveness
spec:
  containers:
    - image: saka1023/liveprobe
      name: migo-liveness
      livenessProbe:
        httpGet:
          path: /
          port: 8080
        period: 20s
        timeout: 5s
        initialDelaySeconds: 15 
        #Always remember to set an initial delay to account for your app's startup time.
```

### Creating effective liveness probes
For pods running in production, you should always define a liveness probe. Without one, K8s has no way of knowing whether your app is still alive or not. As long as the process is still running, K8s will consider the container to be healthy.<br><br>

Here are some pointers:
- Configure probe to perfrom requests on a specific ***URL path***(/health for example.) 
    - This path shouldn't require authentication; otherwise the probe will always fail.
- Keeping probes light 
    - The probe's CPU time is counted in the container's CPU time quota.
- For Java app, be sure to use HTTP GET liveness instead of Exec probe.
<br><br>

## Introducing ReplicationControllers
Going through liveness, you may wonder "what's gonna happen if node itself crashes?" - Well, kubelet on the worker node can't do that as node where kubelet reside already crashed. So, it's then the Control Plane that MUST create replacements for all the pods. To achieve this, you need to have pods managed by Controllers.<br><br>

***What they really do*** is make sure the actual number of pods of a "type" always matches the desired number. You might be wondering how there can be more than the desired number of replicas. This can happen for a few reasons:
- someone creates a pod of the same "type" manually.
- someone changes an existing pod's "type."
- someone decreases the desired number of pods, and so on. 
And as you may have noticed, "type" referrs to label.

### Three parts of ReplicationControllers
- label selector
- replica count
- pod template

### Understanding the effect of changing the controller's label selector or pod template
Changes to the label selector and pod template have no effect on ***existing pods***. It's just making the existing pods fall out of the scope of the Replication Controller.

### Creating Replication Controller
*migo-rc.yaml*
```yaml
apiVersion: v1
kind: ReplicationController
metadata:
  name: migo-rc
spec:
  replica: 1
  selector:         # The pod selector determining what pods the RC is operating on
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
kubectl apply -f migo-rc.yaml
```

### Moving pods in and out of the scope of Replication Controller
Pods created by a ReplicationController aren't tied to the RC anyway. At any moment, RC manages pods that match its label selector. By changing pod's labels, it can be removed from or added to the scope of RC. If you change a Pod's labels, the pod becomes like any other manually created pod. But keep in mind thata when you changed the pod's labels, the RC will notice one pod is missing and spin up a new pod to replace it.<br><br>

If you modify the label selector instead of pod's label, it would make all the pods fall out of the scope, resulting in three new pods.<br>
Kubenetes allows you to change ReplcationController's label selector, but that's not the case for the other resources that will be covered in the second half of this chapter.


### Deleting replication controller
When you delete a RC through *kubetl delete*, the pods are also deleted. But as Pods itself are not an integral part of ReplicationController, you can delete only the RC and leave the pods running. This may be useful when replacing Controller with another one.
```sh
kubectl delete rc "rc_name" --cascade=false
```

## Using ReplicaSet instaed of ReplicationControllers
Intially, RC were the only K8S component for replicating pods and rescheduling them. Later, ***ReplicaSet*** was introduced. That said, you should always create ReplicaSets instead of ReplicationControllers from now on. Let's see how thery differ from RC.<br><br>

ReplicaSet behaves exactly like RC but it has more ***expressive pod selectors***. Whereas RC's lebel selector ONLY allows matching pods that include a certain label, a ReplicaSet's selector ALSO allows:
- matching pods that lack a certain label
- pods that include a certain label key, regardless of its value.
- Pods that inclaude a key that matches either A or B

```yaml
apiVersion: apps/v1
kind: ReplicaSet  
metadata: 
  name: migo-rs
spec:
  replicas: 1
  selector:
    matchLabels:       # This is only difference. 
      app: migo-pod    # There are a lot more ways to define selectors.
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

### Using the ReplicaSet's more expresseive label selectors
The main improvement of ReplicaSets over ReplicationControllers are their more expressive label selectors. Now, let's rewrite the selector to use the more powerful matchExpressions property, as shown in the following listing.
```yaml
apiVersion: apps/v1
kind: ReplicaSet  
metadata: 
  name: migo-rs
spec:
  replicas: 1
  selector:
    matchExpressions:      
      - key: app
        operator: In
        values:
          - kubia  
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
In this example, each expression must contain a key, operator, and possibly(depending on the operator) a list of values. There are four valid operators:
- In
- NotIn
- Exists
- DoesNotExist
If you specify multiple expressions, all those expressions must evaluate to true for the selector to match a pod.

## Running exactly one pod on each node with DaemonSets
Certain cases exist when you want a pod to run on each and every node in the cluster, especially infrastructure-related pods that perform system-level operations. For example:
- Log collector
- Resource monitor
- Kubernetes' own kube-proxy process
Outside of Kubernetes, such processes would usually be started through system init scripts or the systemd daemon. On Kubernetes nodes, you can still use *systemd* to run your system processes, but then you can't take advantage of all the features Kubernetes provides.

### Using Daemonset
To run a pod on all cluster nodes, you create a DaemonSet object which is much like RC or RS except DaemonSet already have a target node specified and skip the Kubernetes Scheduler. Plus, DaemonSet has no notion of a desired replica count. If a node goes down, DaemonSet doesn't cause the pod to be created else where. Instead, when a pod is added to the cluster, it deploys a new pod instance to it. By default, it deploys pods to all nodes. But if you select node by ***nodeSelector*** property in the pod template, you can restrict nodes to which DS deploys the pods.

### Creating DaemonSet YAML definition
You'll create a DaemonSet that runs a mock ssd-monitor process that prints "SSD OK" every 5 seconds. For this, we will use the following dockerfile.
```Dockerfile
FROM busybox
ENTRYPOINT while true; do echo 'SSD OK'; sleep 5; done
```
<br>

And the DaemonSet menifest
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: ssd-monitor
spec:
  selector:
    matchLabels:
      app: ssd-monitor
  template:
    matadata:
      labels: ssd-monitor
    spec:
      nodeSelector:
        disk: ssd    # this will select nodes with the 'disk=ssd' label
      containers:
        - name: main
          image: saka1023/ssd-monitor
```

Don't forget to label your nodes with the *disk=ssd* label by the following command:
```sh
#Get node info
kubectl get node

#Label the noded
kubectl label node minikube disk=ssd

#Apply DaemonSet
kubectl apply -f "DaemonSet-menifest.yaml"
```

## Running pods that perform a single completable task
Up to now, we've talked only about pods that need to run continuously. But, cases exist where you only want to run a task that terminates after completing its work. 

### Introducing the job resource
K8S includes support for this through the ***Job*** resource which allows you to run a pod whose container isn't restarted when the process running inside finishes successfully.<br><br>
In the event of a node failure, the pods will be rescheduled to other nodes. In the event of a failure of the process itself(when the process returns an error exit code), the Job can be configured to either restart or not.<br><br>

An example of a job would be if you had data stored somewhere and you needed to transfrom and export it somewhere. You're going to emulate this by running a container image built on top of *busybox* image, which invokes the sleep command for two minutes as follows. 
```Dockerfile
FROM busybox
ENTRYPOINT echo "$(date) Batch job starting"; sleep 120; echo "$(date) Finished succesfully"
```

### Creating a Job Resource
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: batch-job
spec:
  template:
    metadata:
      labels:
        app: batch-job   #You're not specifying a pods selector(it will be created based on the labels in the pod template)
  spec:
    restartPolicy: OnFailure  #Jobs can't use the default restart policy which is Always.
    containers:
      - image: saka1023/batch-job
        name: main
```
As described in comment, Job pods can't use the default *restartPolicy* which defaults to *Always* because they're not meant to run indefinitely. Therefore, you need to explicitly set the restart policy to either ***OnFailure*** or ***Never***.<br><br>

Let's have fun with it!
```sh
#apply
kubectl apply -f "job.yaml"

#get jobs info
kubectl get jobs
```
After two minutes have passed, the pod will no longer show up. By default, completed pods aren't shown when you list pods, unless you use the --show-all(or -a) switch.

### Running multiple pod instances ina Job
Jobs can be configured to create more than one pod instance and run them either in parallel or sequentailly. It's done by setting ***completions*** and ***parallelism*** properties in Job spec.<br><br>

*Running Job Pods sequentially* - If you need to run jobs multiple times, back to back.
```yaml
apiVersion: batch/v1
kind: Job
metadata: 
  name: multi-completion-batch
spec:
  completions: 5 # Setting completions to 5 makes this job run five pods sequentially
  template:
  ...
``` 
<br>

*Running Job Pods in parallel* 
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: multi-completion-batch
spec:
  completions: 5
  parallelism: 2 #Up to two pods can run in parallel
  template:
  ...
```
<br>

*Scaling a Job* - You can change *parallelism* property while Job is running:
```sh
kubectl scale job multi-completion-batch --replicas 3
```

### Limiting the time allowed for a Job pod to complete
How long should the Job wait for a pod to finish? A Pod's time can be limited by setting ***activeDeadlineSeconds*** in the pod spec. If pod runs longer than that, the system will try to terminate it and will mark the Job as failed. Plus, you can also configure how many times a Job can be retried before it's marked as failed by specifying ***spec.backoffLimit***. If not specified, it *defaults to 6*.

## Scheduling Jobs to run periodically or once in the future.
Many batch jobs need to be run at a specific time in the future or repeatedly in the specified interval. Similar to Linux's CronJob, this job is configured by creating a CronJob resource. 

### Creating a CronJob
Imagine you need to run the batch job from your previous example every 15 minutes. The following menifest will create a resource that caters to your need. 
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: batch-job-every-fifteen-minutes
spec:
  schedule: "0,15,30,45 * * * *" 
  jobTemplate:
    spec:
      template:
        metadata:
          labels:
            app: periodic-batch-job
        spec:
          restartPolicy: OnFailure
          containers:
            - name: main
              image: saka1023/batch-job
```
*Configuring the schedule*
- minute
- hour
- day of month 
- month
- day of week
<br>
"0,30 * 1 * *" - Running every 30minutes on the first day of the month.<br>
"0 3 * * 0" - Running 3AM every Sunday.(the last zero stands for Sunday)<br>

If you specify ***spec.startingDeadlineSeconds***, it can set deadline. 
