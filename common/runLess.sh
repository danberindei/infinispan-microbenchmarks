#!/usr/bin/env bash
set -e

PREFIX=Enum
TEST="EnumReference.*"

PERFASM_OPTS="-XX:+UnlockDiagnosticVMOptions -XX:-TieredCompilation -XX:PrintAssemblyOptions=intel"
JITWATCH_OPTS="-XX:+UnlockDiagnosticVMOptions -XX:-TieredCompilation -XX:+TraceClassLoading -XX:+LogCompilation -XX:+PrintInlining -XX:+PrintAssembly -XX:PrintAssemblyOptions=intel"
JFR_OPTIONS="-XX:+UnlockDiagnosticVMOptions -XX:+DebugNonSafepoints -XX:FlightRecorderOptions=stackdepth=128"

mvn clean package -Dversion.infinispan=9.0.0-SNAPSHOT

i=1
while [[ -f $PREFIX-$i-throughput.log ]]; do
  i=$((i + 1))
done

echo Results will be in $PREFIX-$i-throughput.log
pushd $HOME/Work/infinispan
git log -3 | git name-rev --stdin >$i-throughput.log
popd

# straight results
taskset -c 4-7 $JAVA_HOME/bin/java -jar target/benchmarks.jar -f 3 $TEST >>$PREFIX-$i-throughput.log
# perfnorm output
#taskset -c 4-7 $JAVA_HOME/bin/java -jar target/benchmarks.jar -f 1 -prof perfnorm $TEST >>$PREFIX-$i-perfnorm-gc.log
# gc output
#taskset -c 4-7 $JAVA_HOME/bin/java -jar target/benchmarks.jar -f 1 -prof gc $TEST >>$PREFIX-$i-perfnorm-gc.log
# perfasm output
taskset -c 4-7 $JAVA_HOME/bin/java -jar target/benchmarks.jar -jvmArgsPrepend "$PERFASM_OPTS" -f 1 -prof perfasm:hotThreshold=0.05 $TEST &>$PREFIX-$i-perfasm.log
# jitwatch output
#taskset -c 4-7 $JAVA_HOME/bin/java -jar target/benchmarks.jar -jvmArgsPrepend "$JITWATCH_OPTS" -f 1 $TEST
#mv $(ls -t hotspot_pid*.log | head -1) $PREFIX-$i-jitwatch.log
# flight recorder + flamegraph output
#taskset -c 4-7 $JAVA_HOME/bin/java -jar target/benchmarks.jar -jvmArgsPrepend "$JFR_OPTIONS" -prof net.nicoulaj.jmh.profilers.FlightRecorderProfiler -f 1 $TEST
#JFR_BASENAME=$PREFIX-$i-flightrecorder
#mv $(ls -t hotspot-pid*.jfr | head -1) $JFR_BASENAME.jfr
#~/Work/jfr-flame-graph/run.sh -f $JFR_BASENAME.jfr -o >(sed -r -e 's/([^a-zA-Z]|^)([a-z])[a-z]+\./\1\2./g' -e 's/(\.[a-z])[a-z]+\./\1./g' >$JFR_BASENAME.txt)
#~/Work/FlameGraph/flamegraph.pl <$JFR_BASENAME.txt >$JFR_BASENAME.svg
#rm $JFR_BASENAME.txt
