You can find all the material on my github repository:

https://github.com/stefanocereda/EseComputingInfrastructures/blob/master/MongoDB/README.md

https://github.com/stefanocereda/EseComputingInfrastructures/tree/master/ansible


# Master Node
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

# Infrastructure setup
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

# YCSB setup
We can simply apply the ycsb role to install ycsb, it will also install java
```
ansible-playbook -v ycsb.yaml --extra-vars "variable_host=[client_ip]"
```

# MongoDB setup
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

# Is Lazowska right?
We can now use YCSB to inject some load into MongoDB and use the collected metrics to check some performance laws.
Let's start by actually creating our db with the create_db.sh scriptm which should be run on the cleint machine.

Now we can find the maximum throughput of our database with the run_ycsb.sh script (up to line 9).
We obtain X_max = 5456

By using a target troughput lower than X_max and exploring different values we can validate the response time law.
Collect the data with the second section of runc_ycsb.sh

By playing with the number of users (third section of the script) we can validate the bounds on X and R.

Look at the .ods file for the analysis.


# First performance test
Let's go on the client machine and create the database, then load the server to find out the maximum throughput.
```
ssh [client_ip]
export MONGODB_SERVER_IP=[server_ip]
export RECORDCOUNT=3000000  # dimension of dataset
export WORKLOAD=a  # balance between read and update queries
export LOAD_THREADS=16  # number of client to create db
export RUN_THREADS=16  # number of clients to run perf test
export DURATION=600  # test duration in seconds

echo Creating DB with $RECORDCOUNT records...
./ycsb-0.15.0/bin/ycsb load mongodb-async -s -P ycsb-0.15.0/workloads/workload$WORKLOAD -threads $LOAD_THREADS  -p recordcount=$RECORDCOUNT -p mongodb.url=mongodb://$MONGODB_SERVER_IP:27017

echo Testing X_max with $RUN_THREADS users
./ycsb-0.15.0/bin/ycsb run mongodb-async -s -P ycsb-0.15.0/workloads/workload$WORKLOAD -threads $RUN_THREADS -p recordcount=$RECORDCOUNT -p operationcount=0 -p maxexecutiontime=$DURATION -p mongodb.url=mongodb://$MONGODB_SERVER_IP:27017
```
We obtain as final values:
X: 4223
R_read: 3763
R_upd: 3805

As the test proceeds (you can try to increase the duration) we will observe two interesting things:
- initially the throughput will increase, this is because our database is populating its cache, increasing performance
- after a while (~ half an hour, increase the test duration to see this), the throughput will _drammatically_ drop, that's because we are runnigng our DB on an Amazon instance with a burstable amount of IOPS, meaning that we can substain high IO rates for a certain amount of time, but then they will be reduced.

We can now go to our grafana dashboard on the master node (https://52.214.146.80 login with user/user in my case, run test starts at 18.10) and look at the `Node Exporter Full` dashboard, where we can observe a lot of IO wait in the cpu time.

We thus think that we are being limited by ourd disk, and thus try to move the database to a faster instance.


# Adding a RAID-0
Let's create four other 10GB SSD disks on Amazon and attach them to our machine.
Use the disks to create a RAID-0:

```
ssh [server_ip]
sudo service mongod stop
lsblk
sudo mdadm -Cv /dev/md0 --level=0 -n 4 /dev/xvdf /dev/xvdg /dev/xvdh /dev/xvdi
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

# Second performance test
We now need to recreate the dataset and run again the test for maximum throughput
```
[on client machine]
echo Creating DB with $RECORDCOUNT records...
./ycsb-0.15.0/bin/ycsb load mongodb-async -s -P ycsb-0.15.0/workloads/workload$WORKLOAD -threads $LOAD_THREADS  -p recordcount=$RECORDCOUNT -p mongodb.url=mongodb://$MONGODB_SERVER_IP:27017
# started at 18.25 on grafana

echo Testing X_max with $RUN_THREADS users
./ycsb-0.15.0/bin/ycsb run mongodb-async -s -P ycsb-0.15.0/workloads/workload$WORKLOAD -threads $RUN_THREADS -p recordcount=$RECORDCOUNT -p operationcount=0 -p maxexecutiontime=$DURATION -p mongodb.url=mongodb://$MONGODB_SERVER_IP:27017
# started at 18.29 on grafana
```
We obtain as final values:
X: 3610
R_read: 4401
R_upd: 4453

Unexpectedly, our database is even slower!
You have access to all the system metrics on grafana:
http://52.214.146.80/d/WoUJ8eWWk/node-exporter-full?orgId=1&from=1558974570410&to=1558975208671&var-job=node_exporter&var-node=34.243.140.15&var-port=9100

*CAN YOU SPOT THE BOTTLENECK?*


