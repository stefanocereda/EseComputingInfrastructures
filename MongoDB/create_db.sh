MONGODB_SERVER_IP=[server ip]
RECORDCOUNT=3000000  # number of records
WORKLOAD=a  # workload type
LOAD_THREADS=16  # number of threads used to create data 
cd ycsb-0.17.0

echo Creating DB with $RECORDCOUNT records...
./bin/ycsb load mongodb-async -s -P workloads/workload$WORKLOAD -threads $LOAD_THREADS  -p recordcount=$RECORDCOUNT -p mongodb.url=mongodb://$MONGODB_SERVER_IP:27017
