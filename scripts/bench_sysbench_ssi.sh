#!/usr/bin
#psql -d sysbench -c 'select pg_reload_conf()';
#psql -d postgres -c 'drop database sysbench';
#psql -d postgres -c 'create database sysbench';

# For benchmarking of learned CC

usage() {
  echo "Usage: $0 -t <arg1> -s <arg2> -r <arg3> -w <arg4> -T <arg5> -a"
  echo "Options:"
}

N_THREAD=16
N_WRITE=5
N_READ=5
SKEWNESS=0.5
RUN_TIME=5
TABLES=1
TABLE_SIZE=10000

while getopts ":t:s:r:w:T:a" opt; do
  case $opt in
      a)
          LAUNCH=1
          ;;
      T)
          RUN_TIME=$OPTARG
          ;;
      t)
          N_THREAD=$OPTARG
          ;;
      s)
          SKEWNESS=$OPTARG
          ;;
      r)
          N_READ=$OPTARG
          ;;
      w)
          N_WRITE=$OPTARG
          ;;
      \?)
          echo "Invalid option: -$OPTARG" >&2
          usage
          ;;
      :)
          echo "Option -$OPTARG requires an argument." >&2
          usage
          ;;
  esac
done

DB_DRIVER="pgsql"
# fixed parameters.
HOST="localhost"
PORT="5432"
USER="hexiang"
DB_NAME="sysbench"

if [ -n "$LAUNCH" ]; then
  echo "Kill pending pg_service"
  pg_ctl stop -D $PGDATA -m fast
  echo "Restart pg_service"
  pg_ctl start -D $PGDATA > ./run_log.txt
fi

# For becnhmarking of SSI.
psql -d sysbench -c 'set default_transaction_isolation="serializable"';
psql -d sysbench -c 'set default_cc_strategy="ssi"';
psql -d sysbench -c 'select pg_reload_conf()';


COMMON_OPTIONS="/usr/local/share/sysbench/oltp_read_write.lua
  --db-driver=$DB_DRIVER
  --pgsql-host=$HOST
  --pgsql-port=$PORT
  --pgsql-user=$USER
  --pgsql-db=$DB_NAME
  --tables=$TABLES
  --table-size=$TABLE_SIZE"

sysbench $COMMON_OPTIONS prepare
sysbench $COMMON_OPTIONS prewarm

sysbench $COMMON_OPTIONS \
  --threads=$N_THREAD \
  --time=$RUN_TIME \
  --validate=false \
  --range_selects=off \
  --non_index_updates=$N_WRITE \
  --index_updates=0 \
  --delete_inserts=0 \
  --point_selects=$N_READ \
  --rand-type=zipfian \
  --rand-zipfian-exp=$SKEWNESS \
  run

#  --warmup-time=2 \

if [ -n "$LAUNCH" ]; then
  pg_ctl stop -D $PGDATA -m fast
fi