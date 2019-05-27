# Master Node and infrastructure creation
Let's start by manually creating a master instance on Amazon.
I will use a t2.small with ubuntu.
On this machine we need to install ansible and some python libraries:
sudo apt update
sudo apt install ansible
pip install ...

Now we need the ansible playbooks to create two other machines
git clone ...

We can now use ansible to create 2 new machine, a c4.large as a client and an i3.large for the server. We will have automatic configuration for our users and install node exporter on all the nodes. Prometheus and grafana will be install and configured on the master node:
./launch-instance ...
./launch-instance ...

# MongoDB machine
Now we need to customize our server machine, we want to add another disk and configure them in a RAID0.
Let's add a disk from the AWS console and attach it to the machine.
Now create a RAID0:
lsblk
sudo mdadm -Cv /dev/md0 --level=0 -n 2 /dev/xvdf /dev/xvdg
sudo mkfs.xfs /dev/md0
sudo mkdir /mnt/mongo
sudo mount /dev/md0 /mnt/mongo

Now we need to install mongo:
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 9DA31620334BD75D9DCB49F368818C72E52529D4
echo "deb [ arch=amd64 ] https://repo.mongodb.org/apt/ubuntu bionic/mongodb-org/4.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.0.list
sudo apt-get update
sudo apt-get install -y mongodb-org
sudo vim /etc/mongod.conf
	dbPath: /mnt/mongo/mongodb
	logPath: /mnt/mongo/log/mongod.log
	bindIp: 0.0.0.0
cd /mnt/mongo
sudo mkdir mongodb
sudo mkdir log
sudo chown -R mongodb *
sudo service mongod start
sudo service mongod status

# Client machine
On the client machine we just need to install ycsb:
wget https://github.com/brianfrankcooper/YCSB/releases/download/0.15.0/ycsb-0.15.0.tar.gz
tar xvf ycsb-0.15.0.tar.gz
wget ... run_ycsb.py
vim run_ycsb.py
	insert mongodb server ip address
./run_ycsb.py


# Conclusion
All the setup for mongo and ycsb can (and should) be automated in ansible.
We can access grafana on master node at port 3000

