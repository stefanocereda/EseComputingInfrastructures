MONGODB_SERVER_IP=localhost
RECORDCOUNT=3000000
WORKLOAD=a
LOAD_THREADS=16
RUN_THREADS=16
DURATION=300


echo Creating DB with $RECORDCOUNT records...
./ycsb-0.15.0/bin/ycsb load mongodb-async -s -P workloads/workload$WORKLOAD -threads $LOAD_THREADS  -p recordcount=$RECORDCOUNT -p mongodb.url=mongodb://$MONGODB_SERVER_IP:27017

echo Running test for X_max
./ycsb-0.15.0/bin/ycsb run mongodb-async -s -P workloads/workload$WORKLOAD -threads $RUN_THREADS  -p recordcount=$RECORDCOUNT -p operationcount=0 -p maxexecutiontime=$DURATION -p mongodb.url=mongodb://$MONGODB_SERVER_IP:27017

for TGT_X in 100 200 300 500 1000 2000 3000; do
        echo Running test for X=$TGT_X
        ./ycsb-0.15.0/bin/ycsb run mongodb-async -s -P workloads/workload$WORKLOAD -threads $RUN_THREADS  -p recordcount=$RECORDCOUNT -p operationcount=0 -p maxexecutiontime=$DURATION -target $TGT_X -p mongodb.url=mongodb://$MONGODB_SERVER_IP:27017
done

for N in 1 2 3 4 5 10 20 30 50 100; do
        echo Running test for N=$N
        ./ycsb-0.15.0/bin/ycsb run mongodb-async -s -P workloads/workload$WORKLOAD -threads $N  -p recordcount=$RECORDCOUNT -p operationcount=0 -p maxexecutiontime=$DURATION -target -p mongodb.url=mongodb://$MONGODB_SERVER_IP:27017
done

