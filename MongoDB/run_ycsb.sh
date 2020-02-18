MONGODB_SERVER_IP=[server ip]
RECORDCOUNT=3000000  # number of records
WORKLOAD=a  # workload type
RUN_THREADS=16  # number of threads to use (= number of users N)
DURATION=30  # duration of test in seconds
cd ycsb-0.17.0

# MAX X
echo Running test for X_max
./bin/ycsb run mongodb-async -s -P workloads/workload$WORKLOAD -threads $RUN_THREADS  -p recordcount=$RECORDCOUNT -p operationcount=$RECORDCOUNT -p maxexecutiontime=$DURATION -p mongodb.url=mongodb://$MONGODB_SERVER_IP:27017

# RESPONSE TIME
for TGT_X in 100 200 300 500 1000 2000 3000 5000; do
        echo Running test for X=$TGT_X
        ./bin/ycsb run mongodb-async -s -P workloads/workload$WORKLOAD -threads $RUN_THREADS  -p recordcount=$RECORDCOUNT -p operationcount=$RECORDCOUNT -p maxexecutiontime=$DURATION -target $TGT_X -p mongodb.url=mongodb://$MONGODB_SERVER_IP:27017
done


for N in 1 2 3 4 5 10 20 30 50 100; do
        echo Running test for N=$N
        ./0/bin/ycsb run mongodb-async -s -P workloads/workload$WORKLOAD -threads $N  -p recordcount=$RECORDCOUNT -p operationcount=0 -p maxexecutiontime=$DURATION -target -p mongodb.url=mongodb://$MONGODB_SERVER_IP:27017
done

