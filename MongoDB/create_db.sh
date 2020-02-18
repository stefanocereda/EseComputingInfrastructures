MONGODB_SERVER_IP=[server ip]
RECORDCOUNT=3000000  # number of records
WORKLOAD=a  # workload type
LOAD_THREADS=16  # number of threads to use to create data 

echo Creating DB with $RECORDCOUNT records...

cd ycsb-0.17.0
./bin/ycsb load mongodb-async -s -P workloads/workload$WORKLOAD -threads $LOAD_THREADS  -p recordcount=$RECORDCOUNT -p mongodb.url=mongodb://$MONGODB_SERVER_IP:27017
