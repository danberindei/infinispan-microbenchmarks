#!/usr/bin/env bash
set -e
set -o pipefail
set -o errtrace
set -o functrace

#BENCHMARK_MODE=thrpt
#BENCHMARK_TIME_UNITS=s
BENCHMARK_MODE=sample
BENCHMARK_TIME_UNITS=us
NUM_SEGMENTS=500
NUM_OWNERS=3
NUM_NODES=3
NUM_THREADS=1
WARMUP_SECONDS=10
TEST_SECONDS=10

PREFIX=SCHF; TEST="SyncConsistentHashFactoryBenchmark"

LOG_MAIN=0; LOG_HICCUP=0; LOG_PERFNORM=0; LOG_GC=0; LOG_JITWATCH=0; LOG_PERFASM=0; LOG_JFR=0
#LOG_MAIN=1
#LOG_HICCUP=1
#LOG_PERFNORM=1
#LOG_GC=1
#LOG_JITWATCH=1
LOG_PERFASM=1
#LOG_JFR=1

INFINISPAN_PREBUILT_VERSIONS=""
#INFINISPAN_PREBUILT_VERSIONS="8.3.0.Final-redhat-1"

WORK_DIR=$HOME/Work
INFINISPAN_HOME=$WORK_DIR/infinispan
#INFINISPAN_HOME=$WORK_DIR/jdg

INFINISPAN_COMMITS="ISPN-11679_SyncConsistentHashFactory"

FORCE_JGROUPS_VERSION=""
#FORCE_JGROUPS_VERSION="3.6.10.Final"

COMMON_OPTS="-XX:+UnlockDiagnosticVMOptions -XX:+DebugNonSafepoints -Xmx4g -XX:+PrintGCDetails -Xloggc:gc.log -Djava.net.preferIPv4Stack=true -Dorg.jboss.logging.provider=log4j2"
COMMON_OPTS="$COMMON_OPTS -Dlog4j.configurationFile=file:///$WORK_DIR/infinispan-microbenchmarks/config/log4j2.xml"
#COMMON_OPTS="-XX:MaxInlineLevel=20"  #inlining helps a bit the async interceptors
#THROUGHPUT_OPTS="-javaagent:/$WORK_DIR/jHiccup/jHiccup.jar=\"-d $WARMUP_SECONDS -i 1000 -l hiccup.hlog\" -XX:+PrintGCDetails"
THROUGHPUT_OPTS="-XX:+PrintGCDetails"
PERFASM_OPTS="-XX:PrintAssemblyOptions=intel"
JITWATCH_OPTS="-XX:+TraceClassLoading -XX:+LogCompilation -XX:+PrintInlining -XX:+PrintAssembly -XX:PrintAssemblyOptions=intel"
JFR_OPTIONS=""
JFR_PARENT_OPTIONS="-Djmh.jfr.stackdepth=128"
ALT_JFR_OPTIONS="-XX:+UnlockCommercialFeatures -XX:+FlightRecorder -XX:FlightRecorderOptions=stackdepth=128,dumponexitpath=. -XX:StartFlightRecording=settings=../config/allocation_profile.jfc,delay=${WARMUP_SECONDS}s,dumponexit=true"
#ALT_JFR_OPTIONS="-XX:+UnlockCommercialFeatures -XX:+FlightRecorder -XX:FlightRecorderOptions=stackdepth=128,dumponexitpath=. -XX:StartFlightRecording=settings=../config/exception_profile.jfc,delay=${WARMUP_SECONDS}s,dumponexit=true"

cpupower --cpu all frequency-info | grep "current policy" | grep "and 2.50 GHz" || exit 9

function run_java() {
#  $JAVA_HOME/bin/java "$@"
  taskset -c 4-7 $JAVA_HOME/bin/java "$@"
}

function log_version() {
  echo $(date)
  echo Infinispan $INFINISPAN_VERSION
  echo JGroups $JGROUPS_VERSION
  echo Current infinispan working dir commits:
  echo "$LAST_COMMITS"
  echo
}

function exit_on_error() {
  if [[ $? -ne 0 ]] ; then
    echo "Exiting because of an error in $1"
    exit 1
  fi
}

function run_build() {
PARAMS="-t $NUM_THREADS -w 5 -wi $((WARMUP_SECONDS / 5)) -r 5 -i $((TEST_SECONDS / 5)) -bm $BENCHMARK_MODE -tu $BENCHMARK_TIME_UNITS -p numSegments=$NUM_SEGMENTS -p numOwners=$NUM_OWNERS -p numNodes=$NUM_NODES"

mvn clean package -Dversion.infinispan=$INFINISPAN_VERSION -Dversion.jgroups=$JGROUPS_VERSION
exit_on_error mvn

BASENAME=$PREFIX-$(date +%Y%m%d-%H%M)-${SUFFIX//[^a-zA-Z0-9-_.]/_}
log_version > $BASENAME.log
echo Results will be in $BASENAME.log

# straight results
if [ "$LOG_MAIN" == "1" ] ; then
  run_java -jar target/benchmarks.jar -jvmArgsPrepend "$COMMON_OPTS $THROUGHPUT_OPTS" -f 3 $TEST $PARAMS >>$BASENAME.log 2>&1
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
   run_java -jar target/benchmarks.jar -jvmArgsPrepend "$COMMON_OPTS" -f 1 -prof perfnorm $TEST $PARAMS >>$BASENAME-perfnorm-gc.log 2>&1
fi
# gc output
if [ "$LOG_GC" == "1" ] ; then
   echo Collecting gc profiler logs
   run_java -jar target/benchmarks.jar -jvmArgsPrepend "$COMMON_OPTS" -f 1 -prof gc $TEST $PARAMS >>$BASENAME-perfnorm-gc.log 2>&1
fi
if [ "$LOG_PERFNORM" == "1" -o "$LOG_GC" == "1" ] ; then
  log_version >> $BASENAME-perfnorm-gc.log
fi

# perfasm output
if [ "$LOG_PERFASM" == "1" ] ; then
   echo Collecting perfasm profiler logs
   LD_LIBRARY_PATH=$HOME/Tools/java-disassembler \
   run_java -jar target/benchmarks.jar -jvmArgsPrepend "$COMMON_OPTS $PERFASM_OPTS" -f 1 -prof perfasm:hotThreshold=0.01 $TEST $PARAMS >>$BASENAME-perfasm.log 2>&1
   log_version >> $BASENAME-perfasm.log
fi

# jitwatch output
if [ "$LOG_JITWATCH" == "1" ] ; then
   echo Collecting jitwatch logs
   run_java -jar target/benchmarks.jar -jvmArgsPrepend "$COMMON_OPTS $JITWATCH_OPTS" -f 1 $TEST $PARAMS
   mv $(ls -t hotspot_pid*.log | head -1) $BASENAME-jitwatch.log
fi

# flight recorder + flamegraph output
if [ "$LOG_JFR" == "1" ] ; then
   echo Collecting JFR logs
   #run_java $JFR_PARENT_OPTIONS -jar target/benchmarks.jar -jvmArgsPrepend "$COMMON_OPTS $JFR_OPTIONS" -prof net.nicoulaj.jmh.profilers.FlightRecorderProfiler -f 1 $TEST $PARAMS
   run_java -jar target/benchmarks.jar -jvmArgsPrepend "$COMMON_OPTS $ALT_JFR_OPTIONS" -f 1 $TEST $PARAMS
   JFR_BASENAME=$BASENAME-flightrecorder
   I=0
   for f in $(ls  hotspot-pid*.jfr) ; do
      I=$((I + 1))
      mv $f $JFR_BASENAME$I.jfr
      ~/Work/jfr-flame-graph/run.sh -f $JFR_BASENAME$I.jfr -o >(sed -r -e 's/([^a-zA-Z]|^)([a-z])[a-z]+\./\1\2./g' -e 's/(\.[a-z])[a-z]+\./\1./g' >$JFR_BASENAME$I.stacks)
      ~/Work/FlameGraph/flamegraph.pl --width 1900 --colors hot --cp <$JFR_BASENAME$I.stacks >$JFR_BASENAME$I.svg
      rm $JFR_BASENAME$I.stacks
   done
   I=
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
  mvn clean
  mvn install -s maven-settings.xml -DskipTests -am -pl core
  INFINISPAN_VERSION=$(cat core/pom.xml | perl -ne 'if (/<version>(.*)<\/version>/) { print "$1\n" }' | head -1)
  if [ -z $FORCE_JGROUPS_VERSION ]; then
    JGROUPS_VERSION=$(cat build-configuration/pom.xml | perl -ne 'if (/<version.jgroups>(.*)<\/version.jgroups>/) { print "$1\n" }')
  else
    JGROUPS_VERSION=$FORCE_JGROUPS_VERSION
  fi
  LAST_COMMITS="$(git log --pretty=format:"%H %s" -3 | git name-rev --stdin)"
  popd

  run_build || echo "Failed to run test for $COMMIT"
  #rm -rf $BUILD_DIR
done

for INFINISPAN_VERSION in $INFINISPAN_PREBUILT_VERSIONS; do
  SUFFIX=$INFINISPAN_VERSION
  if [ -z $FORCE_JGROUPS_VERSION ]; then
    mvn compile -Dversion.infinispan=$INFINISPAN_VERSION
    JGROUPS_VERSION=$(cat ~/.m2/repository/org/infinispan/infinispan-bom/$INFINISPAN_VERSION/infinispan-bom-$INFINISPAN_VERSION.pom | perl -ne 'if (/<version.jgroups>(.*)<\/version.jgroups>/) { print "$1\n" }')
  else
    JGROUPS_VERSION=$FORCE_JGROUPS_VERSION
  fi
  LAST_COMMITS="Prebuilt $INFINISPAN_VERSION"

  run_build || echo "Failed to run test for $INFINISPAN_VERSION"
  rm -rf $BUILD_DIR
done

echo -e "\a"
echo -e "\a"
echo -e "\a"
