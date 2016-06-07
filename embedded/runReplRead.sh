#!/usr/bin/env bash
set -e

PREFIX=ReplRead
TEST="Repl.*testGet"
PARAMS="-t 160 -wi 40 -r 6 -i 10 -p jgroupsConfig=../config/default-jgroups-udp.xml -p cacheName=dist-sync"
#PARAMS="-wi 40 -r 10 -i 5 -p jgroupsConfig=../config/stack-udp-oob500.xml"

COMMON_OPTS="-XX:+UseG1GC -XX:+PrintGCDetails -XX:+PrintGCDateStamps -XX:+PrintGCApplicationStoppedTime -Xloggc:gc.log -Djava.net.preferIPv4Stack=true -Dorg.jboss.logging.provider=log4j2"
#COMMON_OPTS="-XX:MaxInlineLevel=20"  #inlining helps a bit the async interceptors
PERFASM_OPTS="-XX:+UnlockDiagnosticVMOptions -XX:-TieredCompilation -XX:PrintAssemblyOptions=intel"
JITWATCH_OPTS="-XX:+UnlockDiagnosticVMOptions -XX:-TieredCompilation -XX:+TraceClassLoading -XX:+LogCompilation -XX:+PrintInlining -XX:+PrintAssembly -XX:PrintAssemblyOptions=intel"
JFR_OPTIONS="-XX:+UnlockDiagnosticVMOptions -XX:+DebugNonSafepoints -XX:FlightRecorderOptions=stackdepth=128 -Djmh.jfr.stackdepth=stackdepth=128"

#INFINISPAN_VERSION=8.2.3-SNAPSHOT
#INFINISPAN_VERSION=9.0.0.Alpha1
#INFINISPAN_VERSION=9.0.0-SNAPSHOT
#INFINISPAN_VERSION=8.3.0.ER3-redhat-1
JGROUPS_VERSION=3.6.9.Final
#JGROUPS_VERSION=3.6.9.SerializationFix
#JGROUPS_VERSION=3.6.9.UfcFix
#JGROUPS_VERSION=3.6.10-SNAPSHOT
#JGROUPS_VERSION=4.0.0-SNAPSHOT

function run_java() {
  #taskset -c 4-7 $JAVA_HOME/bin/java "$@"
  $JAVA_HOME/bin/java "$@"
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

echo Infinispan $INFINISPAN_VERSION > $PREFIX-$i-throughput.log
echo JGroups $JGROUPS_VERSION >> $PREFIX-$i-throughput.log
echo Current infinispan working dir commits: >> $PREFIX-$i-throughput.log
echo $COMMITS >> $PREFIX-$i-throughput.log
echo >> $PREFIX-$i-throughput.log

# straight results
run_java -jar target/benchmarks.jar -jvmArgsPrepend "$COMMON_OPTS" -f 3 $TEST $PARAMS >>$PREFIX-$i-throughput.log
mv gc.log $PREFIX-$i-gc.log
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
run_java -Djmh.jfr.stackdepth=128 -jar target/benchmarks.jar -jvmArgsPrepend "$COMMON_OPTS $JFR_OPTIONS" -prof net.nicoulaj.jmh.profilers.FlightRecorderProfiler -f 1 $TEST $PARAMS
JFR_BASENAME=$PREFIX-$i-flightrecorder
mv $(ls -t hotspot-pid*.jfr | head -1) $JFR_BASENAME.jfr
~/Work/jfr-flame-graph/run.sh -f $JFR_BASENAME.jfr -o >(sed -r -e 's/([^a-zA-Z]|^)([a-z])[a-z]+\./\1\2./g' -e 's/(\.[a-z])[a-z]+\./\1./g' >$JFR_BASENAME.txt)
~/Work/FlameGraph/flamegraph.pl <$JFR_BASENAME.txt >$JFR_BASENAME.svg
rm $JFR_BASENAME.txt

echo Results are in $PREFIX-$i-throughput.log
tail -1 $PREFIX-$i-throughput.log
}

#INFINISPAN_VERSION=8.3.0.ER2-redhat-1
#run_build
#INFINISPAN_VERSION=8.3.0.ER3-redhat-1
#run_build
#INFINISPAN_VERSION=8.3.0.ER5-redhat-1
#run_build
#INFINISPAN_VERSION=8.3.0.ER6-redhat-1
#run_build

INFINISPAN_VERSION=9.0.0-SNAPSHOT
run_build
