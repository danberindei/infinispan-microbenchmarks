#!/usr/bin/env bash
set -e

PREFIX=DistRead
TEST="RandomDist.*testGet"

NUM_THREADS=10
WARMUP_SECONDS=40
JGROUPS_CONFIG=../config/default-jgroups-udp-sswt-oob1.xml


COMMON_OPTS="-XX:+UseG1GC -XX:+PrintGCDetails -XX:+PrintGCDateStamps -XX:+PrintGCApplicationStoppedTime -Xloggc:gc.log -Djava.net.preferIPv4Stack=true -Dorg.jboss.logging.provider=log4j2"
#COMMON_OPTS="-XX:MaxInlineLevel=20"  #inlining helps a bit the async interceptors
THROUGHPUT_OPTS="-javaagent:/home/dan/Work/jHiccup/jHiccup.jar=\"-d $WARMUP_SECONDS -i 1000 -l hiccup.hlog\" -XX:+PrintGCDetails -XX:+PrintGCDateStamps -XX:+PrintGCApplicationStoppedTime"
PERFASM_OPTS="-XX:+UnlockDiagnosticVMOptions -XX:-TieredCompilation -XX:PrintAssemblyOptions=intel"
JITWATCH_OPTS="-XX:+UnlockDiagnosticVMOptions -XX:-TieredCompilation -XX:+TraceClassLoading -XX:+LogCompilation -XX:+PrintInlining -XX:+PrintAssembly -XX:PrintAssemblyOptions=intel"
JFR_OPTIONS="-XX:+UnlockDiagnosticVMOptions -XX:+DebugNonSafepoints"
JFR_PARENT_OPTIONS="-Djmh.jfr.stackdepth=128 -Djmh.jfr.settings=../config/allocation_profiling.jfc"
ALT_JFR_OPTIONS="-XX:+UnlockDiagnosticVMOptions -XX:+DebugNonSafepoints -XX:+UnlockCommercialFeatures -XX:+FlightRecorder -XX:FlightRecorderOptions=stackdepth=128,dumponexitpath=. -XX:StartFlightRecording=settings=../config/allocation_profiling.jfc,delay=${WARMUP_SECONDS}s,dumponexit=true"

#INFINISPAN_VERSION=8.2.3-SNAPSHOT
#INFINISPAN_VERSION=9.0.0.Alpha1
#INFINISPAN_VERSION=9.0.0-SNAPSHOT
#INFINISPAN_VERSION=8.3.0.ER6-redhat-1
#JGROUPS_VERSION=3.6.9.Final
JGROUPS_VERSION=3.6.9.UfcFix
#JGROUPS_VERSION=3.6.10-SNAPSHOT
#JGROUPS_VERSION=4.0.0-SNAPSHOT

PARAMS="-t $NUM_THREADS -wi $WARMUP_SECONDS -r 8 -i 5 -p jgroupsConfig=$JGROUPS_CONFIG"


function run_java() {
  taskset -c 4-7 $JAVA_HOME/bin/java "$@"
  #$JAVA_HOME/bin/java "$@"
}

function run_build() {

mvn clean package -Dinfinispan.version=$INFINISPAN_VERSION -Djgroups.version=$JGROUPS_VERSION
i=1
while [[ -f $PREFIX-$i-throughput.log ]]; do
  i=$((i + 1))
done

echo Results will be in $PREFIX-$i-throughput.log
pushd $HOME/Work/infinispan
COMMITS=$(git log --pretty=format:"%H %s" -3 | git name-rev --stdin)
popd
pushd $HOME/Work/jdg
JDG_COMMITS=$(git log --pretty=format:"%H %s" -3 | git name-rev --stdin)
popd

echo Infinispan $INFINISPAN_VERSION > $PREFIX-$i-throughput.log
echo JGroups $JGROUPS_VERSION >> $PREFIX-$i-throughput.log
echo Current infinispan working dir commits: >> $PREFIX-$i-throughput.log
echo $COMMITS >> $PREFIX-$i-throughput.log
echo Current JDG working dir commits: >> $PREFIX-$i-throughput.log
echo $JDG_COMMITS >> $PREFIX-$i-throughput.log
echo >> $PREFIX-$i-throughput.log

# straight results
run_java -jar target/benchmarks.jar -jvmArgsPrepend "$COMMON_OPTS $THROUGHPUT_OPTS" -f 3 $TEST $PARAMS >>$PREFIX-$i-throughput.log
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
taskset -c 4-7 $JAVA_HOME/bin/java -jar target/benchmarks.jar -jvmArgsPrepend "$COMMON_OPTS $JITWATCH_OPTS" -f 1 $TEST $PARAMS
mv $(ls -t hotspot_pid*.log | head -1) $PREFIX-$i-jitwatch.log
# flight recorder + flamegraph output
#run_java $JFR_PARENT_OPTIONS -jar target/benchmarks.jar -jvmArgsPrepend "$COMMON_OPTS $JFR_OPTIONS" -prof net.nicoulaj.jmh.profilers.FlightRecorderProfiler -f 1 $TEST $PARAMS
run_java $JFR_PARENT_OPTIONS -jar target/benchmarks.jar -jvmArgsPrepend "$COMMON_OPTS $ALT_JFR_OPTIONS" -f 1 $TEST $PARAMS
JFR_BASENAME=$PREFIX-$i-flightrecorder
mv $(ls -t hotspot-pid*.jfr | head -1) $JFR_BASENAME.jfr
~/Work/jfr-flame-graph/run.sh -f $JFR_BASENAME.jfr -o >(sed -r -e 's/([^a-zA-Z]|^)([a-z])[a-z]+\./\1\2./g' -e 's/(\.[a-z])[a-z]+\./\1./g' >$JFR_BASENAME.txt)
~/Work/FlameGraph/flamegraph.pl <$JFR_BASENAME.txt >$JFR_BASENAME.svg
rm $JFR_BASENAME.txt

echo Results are in $PREFIX-$i-throughput.log
tail -1 $PREFIX-$i-throughput.log
}

#INFINISPAN_VERSION=9.0.0-SNAPSHOT
#JGROUPS_CONFIG=../config/default-jgroups-udp.xml run_build
#
#INFINISPAN_VERSION=8.3.0-redhat-SNAPSHOT
#JGROUPS_CONFIG=../config/default-jgroups-udp.xml run_build

INFINISPAN_VERSION=8.3.0-redhat-SNAPSHOT
run_build
#
#INFINISPAN_VERSION=8.3.0.ER6-redhat-1
#run_build
#INFINISPAN_VERSION=8.3.0.ER5-redhat-1
#run_build
#INFINISPAN_VERSION=8.3.0.ER3-redhat-1
#JGROUPS_VERSION=3.6.7.Final run_build
#INFINISPAN_VERSION=8.3.0.ER2-redhat-1
#JGROUPS_VERSION=3.6.7.Final run_build
#
#INFINISPAN_VERSION=6.4.0.Final-redhat-4
#JGROUPS_VERSION=3.6.3.Final PARAMS="$PARAMS -p infinispanConfig=../config/infinispan6-sync.xml" run_build
