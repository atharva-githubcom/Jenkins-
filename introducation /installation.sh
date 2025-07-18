There are three basic requirements for this challenge:

Deploy a server running the latest version of Ubuntu Server.
Install NGINX as a proxy to Jenkins.
Install and configure Jenkins.
Use a public cloud service
If at all possible, use a public cloud service for this challenge.

Suggestions:

Amazon Web Services
Google Cloud Platform
Microsoft Azure
Oracle Cloud
Linode
Digital Ocean
In later lessons, we’ll be implementing continuous integration from a code repo and your Jenkins server needs to be publicly accessible to allow a webhook to trigger jobs.

Use locally available resources
If you aren't able to deploy Jenkins on a public cloud platform, please use the local system that you have available to you.

Jenkins runs on Windows, Mac OS, and Linux so you can install Jenkins just about anywhere.

PLEASE NOTE: local installations will not be able to receive webhooks to trigger jobs.

However, You can still follow along with Jenkins installed on your local system.

The Solution uses Amazon Web Services
The solution demonstrated in the course uses the Amazon web services public Cloud platform. Prerequisites to the solution include:

Create a key pair for SSH connections
Create an EC2 instance using a Ubuntu AMI
Create an elastic IP for persistent DNS assignment
Exercise files are available for this challenge.
There's a script that will update the Ubuntu OS, install NGINX, and install Jenkins. So you won’t have to do an installation from scratch.

jenkins-server-automated-installation.sh
The script also installs the suggested plugins and skips the installation wizard.

The script should work on any cloud platform as long as you use the Ubuntu Server operating system.

If you're following along and installing on a different operating system particularly Windows or Mac OS, review the course “Learning Jenkins” for detailed instructions on installing Jenkins on those platforms.

This challenge should take about 15 minutes to complete


scipt

#!/bin/bash
# vi: ft=bash

echo "# $(date) Installation is starting."

# Uncomment the following line if you are using this script
# as user data for an EC2 instance on AWS.
# Output from the installation will be written to /var/log/user-data.log
#exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "# $(date) Install jenkins key and package configuration..."
curl -fsSL https://pkg.jenkins.io/debian/jenkins.io-2023.key | tee \
    /usr/share/keyrings/jenkins-keyring.asc > /dev/null

echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
    https://pkg.jenkins.io/debian binary/ | tee \
    /etc/apt/sources.list.d/jenkins.list > /dev/null

# install java, nginx, and jenkins
echo "# $(date) Install Java 21, NGINX, and Jenkins..."
apt update
apt-get -y upgrade

apt-get -y install \
    openjdk-21-jdk \
    nginx \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    python3-pip \
    python3-venv

apt-get -y install jenkins

# configure jenkins
echo "# $(date) Configure Jenkins..."

## skip the installation wizard at startup
echo "# $(date) Skip the installation wizard on first boot..."
echo "JAVA_ARGS=\"-Djenkins.install.runSetupWizard=false\"" >> /etc/default/jenkins

## download the list of plugins
echo "# $(date) Download the list of plugins..."
wget https://raw.githubusercontent.com/jenkinsci/jenkins/master/core/src/main/resources/jenkins/install/platform-plugins.json

## get the suggested plugins
echo "# $(date) Use the keyword 'suggest' to find the suggested plugins in the list..."
grep suggest platform-plugins.json | cut -d\" -f 4 | grep -v name | tee suggested-plugins.txt

## download the plugin installation tool
plugin_manager_version=2.13.2
echo "# $(date) Download the plugin installation tool version ${plugin_manager_version}..."
wget https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/${plugin_manager_version}/jenkins-plugin-manager-${plugin_manager_version}.jar

## run the plugin installation tool
echo "# $(date) Run the plugin installation tool..."
/usr/bin/java -jar ./jenkins-plugin-manager-${plugin_manager_version}.jar \
	--verbose \
    --skip-failed-plugins \
    --plugin-download-directory=/var/lib/jenkins/plugins \
    --plugin-file=./suggested-plugins.txt | tee /var/log/plugin-installation.log

## because the plugin installation tool runs as root, ownership on
## the plugin dir needs to be changed back to jenkins:jenkins
## otherwise, jenkins won't be able to install the plugins
echo "# $(date) Update the permissions on the plugins directory..."
chown -R jenkins:jenkins /var/lib/jenkins/plugins

# configure nginx
echo "# $(date) Configure NGINX..."
unlink /etc/nginx/sites-enabled/default

tee /etc/nginx/conf.d/jenkins.conf <<EOF
upstream jenkins {
    server 127.0.0.1:8080;
}

server {
    listen 80 default_server;
    listen [::]:80  default_server;
    location / {
        proxy_pass http://jenkins;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

echo "# $(date) Reload NGINX to pick up the new configuration..."
systemctl reload nginx

# install docker
echo "# $(date) Install docker..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt update
apt-get -y install docker-ce docker-ce-cli containerd.io
docker run hello-world

systemctl enable docker.service
systemctl enable containerd.service

usermod -aG docker ubuntu
usermod -aG docker jenkins

echo "# $(date) Restart Jenkins..."
systemctl restart jenkins

echo "# $(date) Copy the initial admin password to the root user's home directory..."
cp /var/lib/jenkins/secrets/initialAdminPassword ~

clear
echo "Installation is complete."

echo "# Open the URL for this server in a browser and log in with the following credentials:"
echo
echo
echo "    Username: admin"
echo "    Password: $(cat /var/lib/jenkins/secrets/initialAdminPassword)"
echo
echo

