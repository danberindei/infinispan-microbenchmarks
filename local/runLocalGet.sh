#!/usr/bin/env bash
set -e

PREFIX=Local
TEST="Local.*testGet"
PARAMS="-wi 40"

COMMON_OPTS=
#COMMON_OPTS="-XX:MaxInlineLevel=20"  #inlining helps a bit the async interceptors
PERFASM_OPTS="-XX:+UnlockDiagnosticVMOptions -XX:-TieredCompilation -XX:PrintAssemblyOptions=intel"
JITWATCH_OPTS="-XX:+UnlockDiagnosticVMOptions -XX:-TieredCompilation -XX:+TraceClassLoading -XX:+LogCompilation -XX:+PrintInlining -XX:+PrintAssembly -XX:PrintAssemblyOptions=intel"
JFR_OPTIONS="-XX:+UnlockDiagnosticVMOptions -XX:+DebugNonSafepoints -XX:FlightRecorderOptions=stackdepth=128 -Djmh.jfr.stackdepth=stackdepth=128"

#INFINISPAN_VERSION=8.2.3-SNAPSHOT
#INFINISPAN_VERSION=9.0.0.Alpha1
INFINISPAN_VERSION=9.0.0-SNAPSHOT

mvn clean package -Dinfinispan.version=$INFINISPAN_VERSION
i=1
while [[ -f $PREFIX-$i-throughput.log ]]; do
  i=$((i + 1))
done

echo Results will be in $PREFIX-$i-throughput.log
pushd $HOME/Work/infinispan
COMMITS=$(git log --pretty=format:"%H %s" -3 | git name-rev --stdin)
popd

echo Infinispan $INFINISPAN_VERSION > $PREFIX-$i-throughput.log
echo Current infinispan working dir commits: >> $PREFIX-$i-throughput.log
echo $COMMITS >> $PREFIX-$i-throughput.log
echo >> $PREFIX-$i-throughput.log

# straight results
taskset -c 4-7 $JAVA_HOME/bin/java -jar target/benchmarks.jar -jvmArgsPrepend "$COMMON_OPTS" -f 3 $TEST $PARAMS >>$PREFIX-$i-throughput.log
# perfnorm output
#taskset -c 4-7 $JAVA_HOME/bin/java -jar target/benchmarks.jar -jvmArgsPrepend "$COMMON_OPTS" -f 1 -prof perfnorm $TEST $PARAMS >>$PREFIX-$i-perfnorm-gc.log
# gc output
#taskset -c 4-7 $JAVA_HOME/bin/java -jar target/benchmarks.jar -jvmArgsPrepend "$COMMON_OPTS" -f 1 -prof gc $TEST $PARAMS >>$PREFIX-$i-perfnorm-gc.log
# perfasm output
taskset -c 4-7 $JAVA_HOME/bin/java -jar target/benchmarks.jar -jvmArgsPrepend "$COMMON_OPTS $PERFASM_OPTS" -f 1 -prof perfasm:hotThreshold=0.02 $TEST $PARAMS &>$PREFIX-$i-perfasm.log
# jitwatch output
#taskset -c 4-7 $JAVA_HOME/bin/java -jar target/benchmarks.jar -jvmArgsPrepend "$COMMON_OPTS $JITWATCH_OPTS" -f 1 $TEST $PARAMS
#mv $(ls -t hotspot_pid*.log | head -1) $PREFIX-$i-jitwatch.log
# flight recorder + flamegraph output
taskset -c 4-7 $JAVA_HOME/bin/java -Djmh.jfr.stackdepth=128 -jar target/benchmarks.jar -jvmArgsPrepend "$COMMON_OPTS $JFR_OPTIONS" -prof net.nicoulaj.jmh.profilers.FlightRecorderProfiler -f 1 $TEST $PARAMS
JFR_BASENAME=$PREFIX-$i-flightrecorder
mv $(ls -t hotspot-pid*.jfr | head -1) $JFR_BASENAME.jfr
~/Work/jfr-flame-graph/run.sh -f $JFR_BASENAME.jfr -o >(sed -r -e 's/([^a-zA-Z]|^)([a-z])[a-z]+\./\1\2./g' -e 's/(\.[a-z])[a-z]+\./\1./g' >$JFR_BASENAME.txt)
~/Work/FlameGraph/flamegraph.pl <$JFR_BASENAME.txt >$JFR_BASENAME.svg
rm $JFR_BASENAME.txt

echo Results are in $PREFIX-$i-throughput.log
