# ConfigMaps and Secrets: Configuring applications

Because almost all apps require configuration, which shouldn't be baked into the build app itself, let's see how to pass configuration options.

## Configuring containerized applications
- Command-line argument
- Setting custom environment variables for each container
    - for example, official MySQL container image uses an environment variable called **MYSQL_ROOT_PASSWORD**
- Mounting configuration files into containers through a special type of volume

Among them, using environment variable is a popular choice because you don't have to rebuild the image every time you  want to change the config.
Plus, as everyone with access to the image can see the config, it may cause some security issue unless otherwise taken care of.<br><br>

Kubernetes resource for storing configuration data is called a ConfigMap. Although most configuration options don't contain any sensitive information,
several can such as private encription keys, credentials. For that, Kubernetes offers another type of first-class object called a **Secret**.<br>


## Passing command-line arguments to containers 

### Defining the command and arguments in Docker
The whole commonad that gets executed in the container is composed of two parts: the ***command*** and the ***arguments***.

#### Understanding ENTRYPOINT and CMD
- **ENTRYPOINT** defines the executable invoked when the container is started.
- **CMD** specifies the arguments that get passed to the **ENTRYPOINT**
    - But you can still use the CMD to specify the command you want to execute. 

#### Understanding the difference between **SHELL** and **EXEC** forms
- shell form : for example, ENTRYPOINT node app.js
- exec form : for example, ENTRYPOINT ["node", "app.js"]

The difference is whether the specified command is invoked inside a shell or not. While **exec** form runs the process directly, shell form runs shell process first and the process of your interest will be started from that shell process which is unnecessary.

#### Making the internal configurable in your fotune image
Let's modify your fortune script and image so the delay interval in the loop is configurable. You'll add an **INTERVAL** variable and initialize it with the value of the first command-line argument. <br>

***fortuneloop.sh***:
```sh
#!/bin/bash
trap "exit" SIGINT
INTERVAL=$1
echo Configured to generate new fortune every $INTERVAL seconds
mkdir -p /var/htdocs
while : 
do 
    echo $(date) Writing fortune to /var/htdocs/index.html
    /usr/games/fortune > /var/htdocs/index.html
    sleep $INTERVAL
done
```
<br>

**Dockerfile**
```Dockerfile
FROM ubuntu:latest
RUN apt-get update ; apt-get -y install fortune
ADD fortuneloo.sh /bin/fortuneloop.sh
ENTRYPOINT ["/bin/fortuneloop.sh"]
CMD ["10"]  #default argument 
```
<br>

Let's push the image.
```sh
docker build -t saka1023/fortune:args .
docker push saka1023/fortune:args

#test it
docker run -it saka1023/fortune:args

docker run -it saka1023/fortune:args 15 #pass in command-line argument that will overwrite CMD argument
```

### Overriding the command and arguments in Kubernetes
You can choose to override not only **CMD** but also **ENTRYPOINT** in Kubernetes.<br> 
To do that, you set the properties *command* and *args* in the container specification.<br>

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: migo-pod
spec:
  containers:
    - image: some/image
      command: ["/bin/command"] #exec form
      args: ["arg1","arg2","arg3"]
```
But also note that command and args fields can't be updated after the pod is created.

#### Running the fortune pod with a custom interval
fortune-pod-args.yaml
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: fortune2s
spec:
  containers:
    - image: saka1023/fortune:args
      args: ["2"]
      name: html-generator
      volumeMouns:
        - name: html
          mountPath: /var/htdocs
```
If you have several arguments, you can also use different notation like 

    args:
      - foo
      - bar
      - "15"

While you don't need to enclose string values in question marks but you must enclose numbers(which makes it look more of strings, paradoxically)

## Setting Environemnt variables for a container
K8s allows you to specify a custom list of environment variables for each container of a pod. Although it would be useful to also define environment variables at the pod level, **no such option currently exsists.** Note that list of environment variables also cannot be updated after the pod is created.

#### Making the interval in your fortune image configurable through an environment variable
fortuneloop.sh:
```sh
#!/bin/bash
trap "exit" SIGINT
#INTERVAL=$1 Comment this out 
echo Configured to generate new fortune every $INTERVAL seconds
mkdir -p /var/htdocs
while : 
do 
    echo $(date) Writing fortune to /var/htdocs/index.html
    /usr/games/fortune > /var/htdocs/index.html
    sleep $INTERVAL
done
#----------------

docker build -t saka1023/fortune:env .
docker push saka1023/fortune:env
```

If the app was written in Java, you'd use **System.getenv("INTERVAL")**, whereas in Node.JS, you'd use **process.env.INTERVAL** and in Python you'd use **os.getenv("INTERVAL")**.

### Specifying environment variables in a container definition
fortune-pod-env.yaml:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: env-prac
spec:
  containers:
    - image: saka1023/fortune:env
      env: 
        - name: INTERVAL
          value: "30"
      name: html-generator
```

### Referring to other environment variables in a variable's value
You can also reference previously defined environment variables by using the **$(VAR)** syntax.
```yaml
      env:
        - name: FIRST_VAR
          value: "foo"
        - name: SECOND_VAR
          value: "$(FIRST_VAR)bar"
```
In this case, the SECOND_VAR's value will be "foobar".

### Understanding the drawback of hardcoding environment variables
Having values effectively hardcoded in the pod definition means you need to have separate pod definitions for your production and your development pods. 
To reuse one pod in multiple environments, it makes sense to decouple the configuration from the pod descriptor. you can do that by using:
- ***ConfigMap*** resource
- ***valueFrom*** (instead of value as in environmental variable)