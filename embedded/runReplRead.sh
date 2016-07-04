#!/usr/bin/env bash
set -e

PREFIX=ReplRead
TEST="Repl.*testGet"

BENCHMARK_MODE=thrpt
BENCHMARK_TIME_UNITS=s
NUM_THREADS=400
KEY_SIZE=20
VALUE_SIZE=2000
WARMUP_SECONDS=40


function run_java() {
  taskset -c 2-7 $JAVA_HOME/bin/java "$@"
  #taskset -c 4-7 $JAVA_HOME/bin/java "$@"
  #$JAVA_HOME/bin/java "$@"
}

function log_version() {
  echo Infinispan $INFINISPAN_VERSION
  echo JGroups $JGROUPS_VERSION
  echo Current infinispan working dir commits:

  if [[ "$INFINISPAN_COMMIT" != "" ]]; then
    COMMITS=$(git -C $INFINISPAN_HOME log --pretty=format:"%H %s" -3 $INFINISPAN_COMMIT | git name-rev --stdin)
    mvn clean install -DskipTests -am -pl core
  else
    COMMITS=$(git -C $INFINISPAN_HOME log --pretty=format:"%H %s" -3 | git name-rev --stdin)
  fi

  echo $COMMITS
  echo
}

function run_build() {
PARAMS="-t $NUM_THREADS -wi $WARMUP_SECONDS -r 6 -i 5 -bm $BENCHMARK_MODE -tu $BENCHMARK_TIME_UNITS -p infinispanConfig=$INFINISPAN_CONFIG -p jgroupsConfig=$JGROUPS_CONFIG"

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
#run_java -jar target/benchmarks.jar -jvmArgsPrepend "$COMMON_OPTS" -f 1 -prof perfnorm $TEST $PARAMS >>$PREFIX-$i-perfnorm-gc.log
# gc output
#run_java -jar target/benchmarks.jar -jvmArgsPrepend "$COMMON_OPTS" -f 1 -prof gc $TEST $PARAMS >>$PREFIX-$i-perfnorm-gc.log
# perfasm output
run_java -jar target/benchmarks.jar -jvmArgsPrepend "$COMMON_OPTS $PERFASM_OPTS" -f 1 -prof perfasm:hotThreshold=0.02 $TEST $PARAMS &>$PREFIX-$i-perfasm.log
# jitwatch output
#taskset -c 4-7 $JAVA_HOME/bin/java -jar target/benchmarks.jar -jvmArgsPrepend "$COMMON_OPTS $JITWATCH_OPTS" -f 1 $TEST $PARAMS
#mv $(ls -t hotspot_pid*.log | head -1) $PREFIX-$i-jitwatch.log
# flight recorder + flamegraph output
run_java $JFR_PARENT_OPTIONS -jar target/benchmarks.jar -jvmArgsPrepend "$COMMON_OPTS $JFR_OPTIONS" -prof net.nicoulaj.jmh.profilers.FlightRecorderProfiler -f 1 $TEST $PARAMS
#run_java -jar target/benchmarks.jar -jvmArgsPrepend "$COMMON_OPTS $ALT_JFR_OPTIONS" -f 1 $TEST $PARAMS
JFR_BASENAME=$PREFIX-$i-flightrecorder
mv $(ls -t hotspot-pid*.jfr | head -1) $JFR_BASENAME.jfr
~/Work/jfr-flame-graph/run.sh -f $JFR_BASENAME.jfr -o >(sed -r -e 's/([^a-zA-Z]|^)([a-z])[a-z]+\./\1\2./g' -e 's/(\.[a-z])[a-z]+\./\1./g' >$JFR_BASENAME.stacks)
~/Work/FlameGraph/flamegraph.pl --width 1900 --colors hot --cp <$JFR_BASENAME.stacks >$JFR_BASENAME.svg
rm $JFR_BASENAME.stacks

echo Results are in $PREFIX-$i.log
tail -1 $PREFIX-$i.log

log_version >> $PREFIX-$i.log
}

COMMON_OPTS="-XX:+UnlockDiagnosticVMOptions -XX:+DebugNonSafepoints -Xmx4g -XX:+UseConcMarkSweepGC -XX:+PrintGCDetails -XX:+PrintGCDateStamps -XX:+PrintGCApplicationStoppedTime -Xloggc:gc.log -Djava.net.preferIPv4Stack=true -Dorg.jboss.logging.provider=log4j2"
COMMON_OPTS="$COMMON_OPTS -Dlog4j.configurationFile=file:///home/dan/Work/infinispan-microbenchmarks/config/log4j2.xml"
#COMMON_OPTS="-XX:MaxInlineLevel=20"  #inlining helps a bit the async interceptors
THROUGHPUT_OPTS="-javaagent:/home/dan/Work/jHiccup/jHiccup.jar=\"-d $WARMUP_SECONDS -i 1000 -l hiccup.hlog\" -XX:+PrintGCDetails -XX:+PrintGCDateStamps -XX:+PrintGCApplicationStoppedTime"
PERFASM_OPTS="-XX:PrintAssemblyOptions=intel"
JITWATCH_OPTS="-XX:+TraceClassLoading -XX:+LogCompilation -XX:+PrintInlining -XX:+PrintAssembly -XX:PrintAssemblyOptions=intel"
JFR_OPTIONS=""
JFR_PARENT_OPTIONS="-Djmh.jfr.stackdepth=128 -Djmh.jfr.settings=../config/exception_profile.jfc"
#ALT_JFR_OPTIONS="-XX:+UnlockCommercialFeatures -XX:+FlightRecorder -XX:FlightRecorderOptions=stackdepth=128,dumponexitpath=. -XX:StartFlightRecording=settings=../config/allocation_profiling.jfc,delay=${WARMUP_SECONDS}s,dumponexit=true"
ALT_JFR_OPTIONS="-XX:+UnlockCommercialFeatures -XX:+FlightRecorder -XX:FlightRecorderOptions=stackdepth=128,dumponexitpath=. -XX:StartFlightRecording=settings=../config/exception_profile.jfc,delay=${WARMUP_SECONDS}s,dumponexit=true"

INFINISPAN_HOME=/home/dan/Work/jdg

#for tag in $(git -C $INFINISPAN_HOME tag | grep JDG_7.0.0.ER)
#do
#  git -C $INFINISPAN_HOME checkout $tag
#  INFINISPAN_VERSION=8.3.0${tag/JDG_7.0.0/}-redhat-1
#  JGROUPS_VERSION=$(cat $INFINISPAN_HOME/bom/pom.xml | perl -ne 'if (/version.jgroups>(.*)<\/version.jgroups/) { print "$1\n" }')
#  run_build || echo Failed to run test for $tag
#done

#for tag in $(git -C $INFINISPAN_HOME tag | grep "^9")
#do
#  git -C $INFINISPAN_HOME checkout $tag
#  INFINISPAN_VERSION=$tag
#  JGROUPS_VERSION=$(cat $INFINISPAN_HOME/bom/pom.xml | perl -ne 'if (/version.jgroups>(.*)<\/version.jgroups/) { print "$1\n" }')
#  run_build || echo Failed to run test for $tag
#done

JGROUPS_CONFIG=../config/default-jgroups-udp-sswt-lowcredits.xml
INFINISPAN_CONFIG=../config/infinispan-sync.xml
#INFINISPAN_VERSION=8.3.0.ER8-redhat-1
INFINISPAN_VERSION=8.3.0-redhat-SNAPSHOT
#JGROUPS_VERSION=3.6.9.Final-revert-receive
JGROUPS_VERSION=3.6.10.Final-revert-receive-fc
run_build

JGROUPS_CONFIG=../config/default-jgroups-udp-sswt-lowcredits.xml
INFINISPAN_CONFIG=../config/infinispan6-sync.xml
INFINISPAN_VERSION=6.4.0.Final-redhat-4
JGROUPS_VERSION=3.6.4.Final
run_build
