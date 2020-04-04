You can find all the material on my github repository:

https://github.com/stefanocereda/EseComputingInfrastructures/blob/master/MongoDB/README.md

https://github.com/stefanocereda/EseComputingInfrastructures/tree/master/ansible

# Infrastructure setup
## Master Node creation
Let's start by manually creating a master instance on Amazon.
We will use this machine to manage all our infrastructure and we do not need much resources, so we can use a t2.micro.
On this machine we need to install ansible and some python libraries:
```
ssh -i [your_private_key] ubuntu@[master_ip]
sudo apt update
sudo apt install -y ansible python-pip unzip
pip install boto boto3 botocore
cp [your_private_key] .ssh/id_rsa
chmod 400 .ssh/id_rsa
```

## Client and Server machines creation
Now we need the ansible playbooks to create two other machines
```
wget https://github.com/stefanocereda/EseComputingInfrastructures/archive/master.zip
unzip master.zip
cd EseComputingInfrastructures-master/ansible
export AWS_SECRET_ACCESS_KEY=[your aws secret access key]
export AWS_ACCESS_KEY_ID=[your aws access key id]
```

We can now use ansible to create 2 new machines, we will create 2 c4.large instances.
We will use ansible to automatically configure our user and install node exporter on both the machines. We will also install and configure prometheus and grafana on the master node.
```
ENV_NAME=client ./launch_instance.sh
ENV_NAME=server ./launch_instance.sh
ansible all -m ping # save the ip addresses

# In alternative, you can manually create the machines and then add the ip to hosts/inventory

ansible-playbook -v minimal.yml --extra-vars "variable_host=[client_ip]"
ansible-playbook -v common.yml --extra-vars "variable_host=[client_ip]"
ansible-playbook -v monitoring.yml --extra-vars "variable_host=[client_ip]"

ansible-playbook -v minimal.yml --extra-vars "variable_host=[server_ip]"
ansible-playbook -v common.yml --extra-vars "variable_host=[server_ip]"
ansible-playbook -v monitoring.yml --extra-vars "variable_host=[server_ip]"
```

## Client: YCSB setup
We can simply apply the ycsb role to install ycsb, it will also install java
```
ansible-playbook -v ycsb.yaml --extra-vars "variable_host=[client_ip]"
```

## Server: MongoDB setup
We could create a ycsb ansible playbook to automate the installation of MongoDB, but let's do it manually so to understand how we setup the disks.
So far we only have a single disk on this machine, we will let MongoDB use this (very slow) disk.
```
ssh [server_ip]
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 4B7C549A058F8B6B
echo "deb [ arch=amd64 ] https://repo.mongodb.org/apt/ubuntu bionic/mongodb-org/4.2 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.2.list
sudo apt-get update
sudo apt-get install -y mongodb-org
sudo sed -i 's/127.0.0.1/0.0.0.0/g' /etc/mongod.conf  # Open the DB to every ip
sudo service mongod start
sudo service mongod status
```

# Let's run some performance tests
## Is Lazowska right?
We can now use YCSB to inject some load into MongoDB and use the collected metrics to check some performance laws.
Let's start by actually creating our db with the create_db.sh script which should be run on the client machine.

Now we can find the maximum throughput of our database with the run_ycsb.sh script (up to line 10).
We obtain X_max = 4324

By using a target troughput lower than X_max and exploring different values we can validate the response time law.
Collect the data with the second section of run_ycsb.sh (up to line 16)

By playing with the number of users (third section of the script, up to line 22) we can validate the bounds on X and R.

Look at the mongo.ods file for the analysis (tldr: Lazowska is right)


## A longer test
Let's now run a longer test, to see whether we can keep up with the load.
Increase the duration to 1 hour and run again the test for max_x (last line of the script).

As the test proceeds we observe that, after a while (~ half an hour), the throughput will _drammatically_ drop.

We now look at the grafana dashboard:
 - http://polimi.dev.akamas.io:3000/d/yAuNZoQWk/node-exporter-server-metrics?orgId=1&from=1582105403442&to=1582107494689&var-node=172.31.36.162:9100 (login with user/user)
 - http://polimi.dev.akamas.io:3000/dashboard/snapshot/WN4m0GjljYtWUWh2EmACciOGfzQCWgfR?orgId=1
 
Looking at high iowait time and disk utilization, we can conclude that our bootleneck is the disk.
Looking at disk IOs and throughput, we find the culprit of throughput drop: we are running our DB on an Amazon instance with a burstable amount of IOPS, meaning that we can substain high IO rates for a certain amount of time, but then they will be reduced.

We thus conclude that we are being limited by our disk, and thus try to move the database to a faster instance.


## Adding a RAID-0
Let's create four other 10GB SSD disks on Amazon and attach them to our machine.
Use the disks to create a RAID-0 and format the disk with xfs, wich is the suggested filesystem for databases:

```
ssh [server_ip]
sudo service mongod stop
lsblk
sudo mdadm -Cv /dev/md0 --level=0 -n 4 /dev/nvme1n1 /dev/nvme2n1 /dev/nvme3n1 /dev/nvme4n1
sudo mkfs.xfs /dev/md0
sudo mkdir /mnt/mongo
sudo mount /dev/md0 /mnt/mongo
cd /mnt/mongo
sudo mkdir mongodb
sudo mkdir log
sudo chown -R mongodb *
sudo sed -i 's/\/var\/log\/mongodb\/mongod.log/\/mnt\/mongo\/log\/mongod.log/g' /etc/mongod.conf
sudo sed -i 's/\/var\/lib\/mongodb/\/mnt\/mongo\/mongodb/g' /etc/mongod.conf
sudo service mongod start
sudo service mongod status
```

## Repeating the long test
Recreate the dataset and launch again the long test. The database is effectively faster (X_max=7614)

- http://polimi.dev.akamas.io:3000/d/yAuNZoQWk/node-exporter-server-metrics?orgId=1&from=1582108899539&to=1582110448630&var-node=172.31.36.162:9100
- http://polimi.dev.akamas.io:3000/dashboard/snapshot/d6CbpbEjlG6ldArviFapqtUVetOS9bYE

## Changing the filesystem
We still are not happy with performance. We thus look at mongodb configuration suggestions:
https://docs.mongodb.com/manual/administration/production-notes/
Where we discover that:
> When running MongoDB in production on Linux, you should use Linux kernel version 2.6.36 or later, with either the XFS or EXT4 filesystem. If possible, use XFS as it generally performs better with MongoDB.

Let's see if they are right and move our database to an ext4 disk:
```
ssh [server_ip]
sudo service mongod stop
sudo umount /mnt/mongo
sudo mkfs.ext4 /dev/md0
sudo mkdir /mnt/mongo
sudo mount /dev/md0 /mnt/mongo
cd /mnt/mongo
sudo mkdir mongodb
sudo mkdir log
sudo chown -R mongodb *
sudo sed -i 's/\/var\/log\/mongodb\/mongod.log/\/mnt\/mongo\/log\/mongod.log/g' /etc/mongod.conf
sudo sed -i 's/\/var\/lib\/mongodb/\/mnt\/mongo\/mongodb/g' /etc/mongod.conf
sudo service mongod start
sudo service mongod status
```

Create again the database and run another long test.
The throughput increases to X_max = 8630

- http://polimi.dev.akamas.io:3000/d/yAuNZoQWk/node-exporter-server-metrics?orgId=1&from=1582117268593&to=1582119315053&var-node=172.31.36.162:9100
- http://polimi.dev.akamas.io:3000/dashboard/snapshot/ePD0yjXVwFgXHU3D1zfmqLbEPnADgsly

Ouch! MongoDB production notes are wrong! Or do the optimal configuration depends on you workload?
Let's find it out with https://www.akamas.io/
