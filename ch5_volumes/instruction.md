# Volumes: Attaching disk storage to containers
Every new container starts off with the exact set of files. Combine that with that fact that containers are ephemeral, you'll realize that the restarted container will not see anything that was written to the filesystem. You may not need the whole filesystem to be persisted, but you do want to perserve the directories that hold actual data.

## Introducing volumes
Kubernetes volumes are *a component of a pod* and are thus defined in the pod's specification<br><br>

Imagine you have the following containers:
- Webserver that serves HTML from /var/htdocs directory and stores log to /var/logs
- Agent process that creates HTML and store them in /var/html
- Log-processing container that takes logs from /var/logs directory.
Creating a pod with these three containers without them sharing disk storage doesn't make any sense. But if you somehow add two volumes to the pod and *mount* them at appropriate paths, you can create system that's much more than the sum of its parts.<br>
<img src="volume.png" width="300" height="300"> <br><br>
By mounting the same volume into two containers, they can operate on the same files. Let me explain how:
- First, the pod has a volume called *publicHtml* mounted in the WebServer container at /var/htdocs
- The same volume is mounted in the ContentAgent container, but at /var/html
- Similarly, pod also has a volume called *logVol* mounted at /var/logs in both WebServer and LogRotator containers.
<br>

But be careful; it's not enough to define a volume in the pod - you need to:
- define a *VolumeMount* inside the container's spec. 
- use appropriate type, which is in this case *emptyDir*. Other types are:
    - hostPath
    - gitRepo
    - nfs
    - persistentVolumeClaim
A volume is bound to the lifecycle of a pod and will stay in existence only while the pod exists except for persistent one. 

## Using volumes to share data between containers
### emptyDir volume

Hands down, this is the simplest volume and is especially useful for sharing files between containers running in the same pod. But it can also be used by a single container for when a container needs to write data to disk temporarily such as when performing sort operation on a large dataset, which can't fit into the available memory.
Let's revisit the previous example where a web server, a content agent, and a log rotator share volumes, but this time just with one volume instead of two. You'll use Nginx as the web server and the UNIX fortune command to generate the HTML content.<br><br>

***fortuneloop.sh***
```bash
#!/bin/bash
trap "exit" SIGINT
mkdir /var/htdocs
while :
do
    echo $(date) Writing fortune to /var/htdocs/index.html
    /usr/games/fortune > /var/htdocs/index.html
    sleep 10
done
```
***Dockerfile for the above script***
```Dockerfile
FROM ubuntu:latest
RUN apt-get update; apt-get -y install fortune
WORKDIR /usr/app
ADD ./fortuneloop.sh ./fortuneloop.sh
RUN chmod +x fortuneloop.sh
ENTRYPOINT ["/usr/app/fortuneloop.sh"]
```
***Push the image to Registry***
```sh
docker build -t saka1023/fortune .
docker push saka1023/fortune
```
<br>

Now that you have tww images required to run your pod, it's time to create the pod manifest.:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: fortune
spec:
  containers:
    - image: saka1023/fortune
      name: html-generator
      volumeMounts:
        - name: html
          mountPath: /var/htdocs            #The volume called html is mounted at /var/htdocs
    - image: nginx:alpine
      name: web-server
      volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html  #The same volume as above is mounted at /usr/share/nginx/html 
          readOnly: true                    #as read only
      ports:
        - containerPort: 80
          protocol: TCP
  volumes:                                  #A single emptyDir volume called html 
    - name: html
      emptyDir: {}
```
When the *html-generator* container starts, it starts writing the output of the *fortune* command to the /var/htdocs/index.html file every 10 seconds. As soon as the web-server container starts, it starts serving whatever HTML files are in the /usr/share/nginx/html directory(This is default directory). The end effect is a client sending an HTTP request to the pod on port 80 will receive the current fortune message as the response.<br><br>

*Seeing the pod in action*
```sh
#spin up the pod
kubectl apply -f "pod_descriptor.yaml"

#port-forward for simplicity
kubectl port-forward fortune 8080:80

#on different session, send a curl
curl http://localhost:8080
```
*emptyDir* you used was created on the actual disk. So its performance depends on the type of the node's disks. But you can tell K8S to create the *emptyDir*'s medium to Memory liek this:
```yaml
  volumes: 
    - name: html
      emptyDir:
        medium: Memory
```
An *emptyDir* is the simplest, but other types of volumes build upon it. 

### Using a Git repository as the starting point for a volume
A *gitRepo* volume is basically emptyDir volume that gets populated by cloning a Git repository and checking out a specific revision when the pod is starting up(but before its containers are created).<br>
<img src="git_repo.png"> <br>
Note that after *gitRepo* volume is created, it's not kept in sync with the repo it's referencing. The files in the volume will not be updated when you push additional commmits to the Git repository. However, if pods are managed by controller, updating it will result in a new pod being created based on the new copy.<br>

*gitrepo-volume-pod.yaml*
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: gitrepo-volume-pod
spec: 
  containers:
    - image: nginx:alpine
      name: web-server
      volumeMounts: 
        - name: html
          mountPath: /usr/share/nginx/html
          readOnly: true
      ports:
        - containerPort: 80
          protocol: TCP
  volumes:
    - name: html
      gitRepo:
        repository: "your_git_repo/migo-directory"
        revision: master    #The master branch will be checked out
        directory: .        #you want the repo to be cloned into the root dir of the volume
```
If you don't set the directory to '.',  the repository will clone into *migo-directory* subdirectory, which isn't what you want.<br>

#### Introducing sidecar containers
A sidecar container is a container that augments the operation of the main container of the pod. You basically add a sidecar to a pod so you can use an existing container image instead of cramming additional logic into the main app's code. To find an existing container image, which keeps a local directory synchronized with a Git repository, go to Docker Hub and search for ***"git sync"***<br>

#### Using a gitRepo volume with private Git repositories
There is one other reason for having to resort to Git sync sidecar containers; you can't use a *gitRepo* with a private Git repo. If you want to clone a private Git repo into your container, you should use a git-sync sidecar or a similar method instead of a *gitRepo* volume