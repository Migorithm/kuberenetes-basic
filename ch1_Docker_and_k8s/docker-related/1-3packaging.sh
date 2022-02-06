#build an image
docker build -t <image>:<tag> .
   # '.' refers to the build context

#Run the image
docker run -d -p 8080:8080  --name container_name image:tag
    # -- '-d' : detach
    # -- '-p' : port 
    # -- '--name' :container name

#check 
curl localhost:8080


#Q -- what does the following result mean?
#process check inside a container
docker exec -it first-trial bash -c "ps -ef"
UID          PID    PPID  C STIME TTY          TIME CMD
root           1       0  0 13:29 ?        00:00:00 node app.js

#process check
ps -ef | grep node
root     1342422 1342394  0 13:29 ?        00:00:00 node app.js


#Pushing the image to an image registry
    # -- you can push to private registry, Dockerhub or Quay.io
    # Dockerhub allows you to push an image only if 
    # your image's name start with your Dockerhub ID
#- retag
docker tag container_name Dockerhub_id/image

#- push -- this requires login 
docker login
docker push Dockerhub_id/image
