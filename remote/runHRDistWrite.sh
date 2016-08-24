#!/usr/bin/env bash
set -e

PREFIX=HRDistWrite
TEST="HotRodDist.*testPut"

BENCHMARK_MODE=thrpt
BENCHMARK_TIME_UNITS=s
NUM_THREADS=40
KEY_SIZE=40
VALUE_SIZE=2000
WARMUP_SECONDS=40
INFINISPAN_CONFIG=../config/infinispan-sync.xml
JGROUPS_CONFIG=../config/default-jgroups-udp-sswt.xml


COMMON_OPTS="-XX:+UseConcMarkSweepGC -XX:+PrintGCDetails -XX:+PrintGCDateStamps -XX:+PrintGCApplicationStoppedTime -Xloggc:gc.log -Djava.net.preferIPv4Stack=true -Dorg.jboss.logging.provider=log4j2"
COMMON_OPTS="$COMMON_OPTS -Dlog4j.configurationFile=file:///home/dan/Work/infinispan-microbenchmarks/config/log4j2.xml"
#COMMON_OPTS="-XX:MaxInlineLevel=20"  #inlining helps a bit the async interceptors
THROUGHPUT_OPTS="-javaagent:/home/dan/Work/jHiccup/jHiccup.jar=\"-d $WARMUP_SECONDS -i 1000 -l hiccup.hlog\" -XX:+PrintGCDetails -XX:+PrintGCDateStamps -XX:+PrintGCApplicationStoppedTime"
#THROUGHPUT_OPTS="$THROUGHPUT_OPTS -Xdebug -Xrunjdwp:transport=dt_socket,server=y,suspend=y,address=5006"
PERFASM_OPTS="-XX:+UnlockDiagnosticVMOptions -XX:-TieredCompilation -XX:PrintAssemblyOptions=intel"
JITWATCH_OPTS="-XX:+UnlockDiagnosticVMOptions -XX:-TieredCompilation -XX:+TraceClassLoading -XX:+LogCompilation -XX:+PrintInlining -XX:+PrintAssembly -XX:PrintAssemblyOptions=intel"
JFR_OPTIONS="-XX:+UnlockDiagnosticVMOptions -XX:+DebugNonSafepoints"
JFR_PARENT_OPTIONS="-Djmh.jfr.stackdepth=128 -Djmh.jfr.settings=../config/allocation_profiling.jfc"
ALT_JFR_OPTIONS="-XX:+UnlockDiagnosticVMOptions -XX:+DebugNonSafepoints -XX:+UnlockCommercialFeatures -XX:+FlightRecorder -XX:FlightRecorderOptions=stackdepth=128,dumponexitpath=. -XX:StartFlightRecording=settings=../config/allocation_profiling.jfc,delay=${WARMUP_SECONDS}s,dumponexit=true"

CONST_PARAMS=""


function run_java() {
  taskset -c 4-7 $JAVA_HOME/bin/java "$@"
  #$JAVA_HOME/bin/java "$@"
}

function log_version() {
  echo Infinispan $INFINISPAN_VERSION
  echo JGroups $JGROUPS_VERSION
  echo Current infinispan working dir commits:
  echo $COMMITS
  echo
}

function run_build() {
PARAMS="-t $NUM_THREADS -w 5 -wi $((WARMUP_SECONDS / 5)) -r 5 -i 6 -bm $BENCHMARK_MODE -tu $BENCHMARK_TIME_UNITS -p infinispanConfig=$INFINISPAN_CONFIG -p jgroupsConfig=$JGROUPS_CONFIG"

if [[ "$INFINISPAN_COMMIT" != "" ]]; then
  pushd $INFINISPAN_HOME
  git checkout $INFINISPAN_COMMIT
  COMMITS=$(git log --pretty=format:"%H %s" -3 | git name-rev --stdin)
  mvn clean install -DskipTests -am -pl core
  popd
fi

mvn clean package -Dinfinispan.version=$INFINISPAN_VERSION -Djgroups.version=$JGROUPS_VERSION
i=1
while [[ -f $PREFIX-$i.log ]]; do
  i=$((i + 1))
done

log_version > $PREFIX-$i.log
echo Results will be in $PREFIX-$i.log

# straight results
run_java -jar target/benchmarks.jar -jvmArgsPrepend "$COMMON_OPTS $THROUGHPUT_OPTS" -f 3 $TEST $PARAMS >>$PREFIX-$i.log
mv gc.log $PREFIX-$i-gc.log
../../jHiccup/jHiccupLogProcessor -i hiccup.hlog -o hiccup
cat hiccup hiccup.hgrm >$PREFIX-$i-hiccup.log
rm hiccup.hlog hiccup hiccup.hgrm
# perfnorm output
run_java -jar target/benchmarks.jar -jvmArgsPrepend "$COMMON_OPTS" -f 1 -prof perfnorm $TEST $PARAMS >>$PREFIX-$i-perfnorm-gc.log
# gc output
run_java -jar target/benchmarks.jar -jvmArgsPrepend "$COMMON_OPTS" -f 1 -prof gc $TEST $PARAMS >>$PREFIX-$i-perfnorm-gc.log
# perfasm output
run_java -jar target/benchmarks.jar -jvmArgsPrepend "$COMMON_OPTS $PERFASM_OPTS" -f 1 -prof perfasm:hotThreshold=0.02 $TEST $PARAMS &>$PREFIX-$i-perfasm.log
# jitwatch output
#taskset -c 4-7 $JAVA_HOME/bin/java -jar target/benchmarks.jar -jvmArgsPrepend "$COMMON_OPTS $JITWATCH_OPTS" -f 1 $TEST $PARAMS
#mv $(ls -t hotspot_pid*.log | head -1) $PREFIX-$i-jitwatch.log
# flight recorder + flamegraph output
run_java $JFR_PARENT_OPTIONS -jar target/benchmarks.jar -jvmArgsPrepend "$COMMON_OPTS $JFR_OPTIONS" -prof net.nicoulaj.jmh.profilers.FlightRecorderProfiler -f 1 $TEST $PARAMS
#run_java $JFR_PARENT_OPTIONS -jar target/benchmarks.jar -jvmArgsPrepend "$COMMON_OPTS $ALT_JFR_OPTIONS" -f 1 $TEST $PARAMS
JFR_BASENAME=$PREFIX-$i-flightrecorder
mv $(ls -t hotspot-pid*.jfr | head -1) $JFR_BASENAME.jfr
~/Work/jfr-flame-graph/run.sh -f $JFR_BASENAME.jfr -o >(sed -r -e 's/([^a-zA-Z]|^)([a-z])[a-z]+\./\1\2./g' -e 's/(\.[a-z])[a-z]+\./\1./g' >$JFR_BASENAME.txt)
~/Work/FlameGraph/flamegraph.pl <$JFR_BASENAME.txt >$JFR_BASENAME.svg
rm $JFR_BASENAME.txt

echo Results are in $PREFIX-$i.log
tail -1 $PREFIX-$i.log

log_version >> $PREFIX-$i.log
}

INFINISPAN_HOME=/home/dan/Work/jdg

#INFINISPAN_VERSION=8.3.0.ER9-redhat-1
INFINISPAN_VERSION=8.3.0-redhat-SNAPSHOT
JGROUPS_VERSION=3.6.10.Final-redhat-1
INFINISPAN_CONFIG=../config/infinispan-synctx.xml
run_build

#INFINISPAN_VERSION=8.3.0.ER8-redhat-1
#JGROUPS_VERSION=3.6.10.Final-redhat-1
#INFINISPAN_CONFIG=../config/infinispan-synctx.xml
#run_build

INFINISPAN_VERSION=6.4.0.Final-redhat-4
JGROUPS_VERSION=3.6.4.Final
INFINISPAN_CONFIG=../config/infinispan6-synctx.xml
run_build
