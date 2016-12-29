#!/usr/bin/env bash
set -e

BENCHMARK_MODE=thrpt
BENCHMARK_TIME_UNITS=s
#BENCHMARK_MODE=sample
#BENCHMARK_TIME_UNITS=ns
NUM_THREADS=80
KEY_SIZE=20
#VALUE_SIZE=2000
VALUE_SIZE=10000
WARMUP_SECONDS=40

#PREFIX=LocalRead ; TEST="Local.*testGet"
#PREFIX=LocalWrite ; TEST="Local.*testPut"
#PREFIX=ReplRead ; TEST="Repl.*testGet"
#PREFIX=ReplWrite ; TEST="Repl.*testPut"
PREFIX=ETxReplRead ; TEST="Repl.*testTxGet"
#PREFIX=PrimaryDistRead ; TEST="PrimaryDist.*testGet"
#PREFIX=PrimaryDistWrite ; TEST="PrimaryDistC.*testPut"
#PREFIX=RandomDistRead ; TEST="RandomDist.*testGet"
#PREFIX=RandomDistWrite ; TEST="RandomDistC.*testPut"
#PREFIX=MH3 ; TEST="MurmurHash3Benchmark.testHash"

LOG_MAIN=1; LOG_HICCUP=0; LOG_PERFNORM=0; LOG_GC=0; LOG_JITWATCH=0; LOG_PERFASM=1; LOG_JFR=1
#LOG_MAIN=0; LOG_HICCUP=0; LOG_PERFNORM=0; LOG_GC=0; LOG_JITWATCH=1; LOG_PERFASM=0; LOG_JFR=0
#LOG_MAIN=0; LOG_HICCUP=0; LOG_PERFNORM=0; LOG_GC=0; LOG_JITWATCH=0; LOG_PERFASM=1; LOG_JFR=0

#INFINISPAN_PREBUILT_VERSIONS=""
INFINISPAN_PREBUILT_VERSIONS="8.3.0.Final-redhat-1"

WORK_DIR=$HOME/Work
INFINISPAN_HOME=$WORK_DIR/infinispan
#INFINISPAN_HOME=$WORK_DIR/jdg

INFINISPAN_COMMITS=""
#INFINISPAN_COMMITS="t_async_api_change_experiments"
#INFINISPAN_COMMITS="jdg-7.1.x"

FORCE_JGROUPS_VERSION=""
#FORCE_JGROUPS_VERSION="3.6.10.Final"

INFINISPAN_CONFIG="../config/infinispan-synctx.xml"
#JGROUPS_CONFIG="../config/jgroups-tcp-ufc.xml"
JGROUPS_CONFIG="default-configs/default-jgroups-udp.xml"

COMMON_OPTS="-XX:+UnlockDiagnosticVMOptions -XX:+DebugNonSafepoints -Xmx4g -XX:+UseConcMarkSweepGC -XX:+PrintGCDetails -XX:+PrintGCDateStamps -XX:+PrintGCApplicationStoppedTime -Xloggc:gc.log -Djava.net.preferIPv4Stack=true -Dorg.jboss.logging.provider=log4j2"
COMMON_OPTS="$COMMON_OPTS -Dlog4j.configurationFile=file:///$WORK_DIR/infinispan-microbenchmarks/config/log4j2.xml"
#COMMON_OPTS="-XX:MaxInlineLevel=20"  #inlining helps a bit the async interceptors
#THROUGHPUT_OPTS="-javaagent:/$WORK_DIR/jHiccup/jHiccup.jar=\"-d $WARMUP_SECONDS -i 1000 -l hiccup.hlog\" -XX:+PrintGCDetails -XX:+PrintGCDateStamps -XX:+PrintGCApplicationStoppedTime"
THROUGHPUT_OPTS="-XX:+PrintGCDetails -XX:+PrintGCDateStamps -XX:+PrintGCApplicationStoppedTime"
PERFASM_OPTS="-XX:PrintAssemblyOptions=intel"
JITWATCH_OPTS="-XX:+TraceClassLoading -XX:+LogCompilation -XX:+PrintInlining -XX:+PrintAssembly -XX:PrintAssemblyOptions=intel"
JFR_OPTIONS=""
JFR_PARENT_OPTIONS="-Djmh.jfr.stackdepth=128"
ALT_JFR_OPTIONS="-XX:+UnlockCommercialFeatures -XX:+FlightRecorder -XX:FlightRecorderOptions=stackdepth=128,dumponexitpath=. -XX:StartFlightRecording=settings=../config/allocation_profile.jfc,delay=${WARMUP_SECONDS}s,dumponexit=true"
#ALT_JFR_OPTIONS="-XX:+UnlockCommercialFeatures -XX:+FlightRecorder -XX:FlightRecorderOptions=stackdepth=128,dumponexitpath=. -XX:StartFlightRecording=settings=../config/exception_profile.jfc,delay=${WARMUP_SECONDS}s,dumponexit=true"

cpupower --cpu all frequency-info | grep "current policy" | grep "and 3.00 GHz" || exit 9

function run_java() {
#  $JAVA_HOME/bin/java "$@"
  taskset -c 4-7 $JAVA_HOME/bin/java "$@"
}

function log_version() {
  echo $(date)
  echo Infinispan $INFINISPAN_VERSION
  echo JGroups $JGROUPS_VERSION
  echo Current infinispan working dir commits:
  echo $LAST_COMMITS
  echo
}

function run_build() {
PARAMS="-t $NUM_THREADS -w 5 -wi $((WARMUP_SECONDS / 5)) -r 5 -i 6 -bm $BENCHMARK_MODE -tu $BENCHMARK_TIME_UNITS -p infinispanConfig=$INFINISPAN_CONFIG -p jgroupsConfig=$JGROUPS_CONFIG"

mvn clean package -Dversion.infinispan=$INFINISPAN_VERSION -Dversion.jgroups=$JGROUPS_VERSION
#i=$(cat .current-index)
#while [[ -f $PREFIX-$i.log ]]; do
#  i=$((i + 1))
#done
#echo $i >.current-index

BASENAME=$PREFIX-$(date +%Y%m%d-%H%M)-${SUFFIX//[^a-zA-Z0-9-_.]/_}
log_version > $BASENAME.log
echo Results will be in $BASENAME.log

# straight results
if [ "$LOG_MAIN" == "1" ] ; then
  run_java -jar target/benchmarks.jar -jvmArgsPrepend "$COMMON_OPTS $THROUGHPUT_OPTS" -f 3 $TEST $PARAMS >>$BASENAME.log
  log_version >> $BASENAME.log
fi
if [ "$LOG_HICCUP" == "1" ] ; then
   echo Collecting hiccup logs
   mv gc.log $BASENAME-gc.log
   ../../jHiccup/jHiccupLogProcessor -i hiccup.hlog -o hiccup
   cat hiccup hiccup.hgrm >$BASENAME-hiccup.log
   rm hiccup.hlog hiccup hiccup.hgrm
   log_version >> $BASENAME-hiccup.log
fi

# perfnorm output
if [ "$LOG_PERFNORM" == "1" ] ; then
   echo Collecting perfnorm profiler logs
   run_java -jar target/benchmarks.jar -jvmArgsPrepend "$COMMON_OPTS" -f 1 -prof perfnorm $TEST $PARAMS >>$BASENAME-perfnorm-gc.log
fi
# gc output
if [ "$LOG_GC" == "1" ] ; then
   echo Collecting gc profiler logs
   run_java -jar target/benchmarks.jar -jvmArgsPrepend "$COMMON_OPTS" -f 1 -prof gc $TEST $PARAMS >>$BASENAME-perfnorm-gc.log
fi
if [ "$LOG_PERFNORM" == "1" -o "$LOG_GC" == "1" ] ; then
  log_version >> $BASENAME-perfnorm-gc.log
fi

# perfasm output
if [ "$LOG_PERFASM" == "1" ] ; then
   echo Collecting perfasm profiler logs
   run_java -jar target/benchmarks.jar -jvmArgsPrepend "$COMMON_OPTS $PERFASM_OPTS" -f 1 -prof perfasm:hotThreshold=0.02 $TEST $PARAMS &>$BASENAME-perfasm.log
   log_version >> $BASENAME-perfasm.log
fi

# jitwatch output
if [ "$LOG_JITWATCH" == "1" ] ; then
   echo Collecting jitwatch logs
   taskset -c 4-7 $JAVA_HOME/bin/java -jar target/benchmarks.jar -jvmArgsPrepend "$COMMON_OPTS $JITWATCH_OPTS" -f 1 $TEST $PARAMS
   mv $(ls -t hotspot_pid*.log | head -1) $BASENAME-jitwatch.log
fi

# flight recorder + flamegraph output
if [ "$LOG_JFR" == "1" ] ; then
   echo Collecting JFR logs
   #run_java $JFR_PARENT_OPTIONS -jar target/benchmarks.jar -jvmArgsPrepend "$COMMON_OPTS $JFR_OPTIONS" -prof net.nicoulaj.jmh.profilers.FlightRecorderProfiler -f 1 $TEST $PARAMS
   run_java -jar target/benchmarks.jar -jvmArgsPrepend "$COMMON_OPTS $ALT_JFR_OPTIONS" -f 1 $TEST $PARAMS
   JFR_BASENAME=$BASENAME-flightrecorder
   mv $(ls -t hotspot-pid*.jfr | head -1) $JFR_BASENAME.jfr
   ~/Work/jfr-flame-graph/run.sh -f $JFR_BASENAME.jfr -o >(sed -r -e 's/([^a-zA-Z]|^)([a-z])[a-z]+\./\1\2./g' -e 's/(\.[a-z])[a-z]+\./\1./g' >$JFR_BASENAME.stacks)
   ~/Work/FlameGraph/flamegraph.pl --width 1900 --colors hot --cp <$JFR_BASENAME.stacks >$JFR_BASENAME.svg
   rm $JFR_BASENAME.stacks
fi

echo Results are in $BASENAME.log
tail -1 $BASENAME.log
}

# main
for COMMIT in $INFINISPAN_COMMITS; do
  SUFFIX=$COMMIT
  BUILD_DIR=$WORK_DIR/tmpbuild/infinispan-microbenchmarks
  rm -rf $BUILD_DIR
  git clone -s $INFINISPAN_HOME $BUILD_DIR
  pushd $BUILD_DIR
  git checkout $COMMIT
  mvn clean install -DskipTests -am -pl core
  INFINISPAN_VERSION=$(cat core/pom.xml | perl -ne 'if (/<version>(.*)<\/version>/) { print "$1\n" }')
  if [ -z $FORCE_JGROUPS_VERSION ]; then
    JGROUPS_VERSION=$(cat bom/pom.xml | perl -ne 'if (/<version.jgroups>(.*)<\/version.jgroups>/) { print "$1\n" }')
  else
    JGROUPS_VERSION=$FORCE_JGROUPS_VERSION
  fi
  LAST_COMMITS=$(git log --pretty=format:"%H %s" -3 | git name-rev --stdin)
  popd

  run_build || echo "Failed to run test for $COMMIT"
  rm -rf $BUILD_DIR
done

for INFINISPAN_VERSION in $INFINISPAN_PREBUILT_VERSIONS; do
  SUFFIX=$INFINISPAN_VERSION
  if [ -z $FORCE_JGROUPS_VERSION ]; then
    JGROUPS_VERSION=$(cat ~/.m2/repository/org/infinispan/infinispan-bom/$INFINISPAN_VERSION/infinispan-bom-$INFINISPAN_VERSION.pom | perl -ne 'if (/<version.jgroups>(.*)<\/version.jgroups>/) { print "$1\n" }')
  else
    JGROUPS_VERSION=$FORCE_JGROUPS_VERSION
  fi
  LAST_COMMITS="Prebuilt $INFINISPAN_VERSION"

  run_build || echo "Failed to run test for $INFINISPAN_VERSION"
  rm -rf $BUILD_DIR
done
