wget https://download.docker.com/linux/ubuntu/dists/focal/pool/stable/amd64/containerd.io_1.4.9-1_amd64.deb
wget https://download.docker.com/linux/ubuntu/dists/focal/pool/stable/amd64/docker-ce_20.10.9~3-0~ubuntu-focal_amd64.deb
wget https://download.docker.com/linux/ubuntu/dists/focal/pool/stable/amd64/docker-ce-cli_20.10.9~3-0~ubuntu-focal_amd64.deb

sudo dpkg -i containerd.io_1.4.9-1_amd64.deb
sudo dpkg -i docker-cli-ce_20.10.9~3-0~ubuntu-focal_amd64.deb
sudo dpkg -i docker-ce_20.10.9~3-0~ubuntu-focal_amd64.deb

#since the group 'docker' has been already created, you wouldn't need to type execute the following command, but just in case.
sudo groupadd docker 
#Add your user to the docker group
sudo usermod -aG docker $(whoami)