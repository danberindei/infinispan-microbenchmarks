#!/usr/bin/env bash
set -e
set -o pipefail
set -o errtrace
set -o functrace

BENCHMARK_MODE=thrpt
BENCHMARK_TIME_UNITS=s
#BENCHMARK_MODE=sample
#BENCHMARK_TIME_UNITS=ns
CORES=6-11
CLUSTER_SIZE=4
NUM_THREADS=16
KEY_SIZE=20
VALUE_SIZE=1000
NUM_KEYS=100000
FILL_RATIO=0.7
WARMUP_SECONDS=50
TEST_SECONDS=50

#PREFIX=HRDistRead-nt ; TEST="HotRodDist.*testGet"
#PREFIX=HRDistRead ; TEST="HotRodDist.*testGet"
PREFIX=HRDistWrite ; TEST="HotRodDist.*testPut"
#PREFIX=MDDistRead ; TEST="MemcachedDist.*testGet"
#PREFIX=MDDistWrite ; TEST="MemcachedDist.*testPut"

LOG_MAIN=0; LOG_HICCUP=0; LOG_PERFNORM=0; LOG_GC=0; LOG_JITWATCH=0; LOG_PERFASM=0; LOG_JFR=0; LOG_ASYNC=0
LOG_MAIN=1
#LOG_HICCUP=1
#LOG_PERFNORM=1
#LOG_GC=1
#LOG_JITWATCH=1
#LOG_PERFASM=1
#LOG_JFR=1
LOG_ASYNC=1

INFINISPAN_PREBUILT_VERSIONS=""
#INFINISPAN_PREBUILT_VERSIONS="8.4.2.Final-redhat-1"
#INFINISPAN_PREBUILT_VERSIONS="11.0.9.Final 9.4.21.Final 9.4.24.DevAsyncTouch 13.0.0.DevAsyncTouch"
#INFINISPAN_PREBUILT_VERSIONS="9.4.24.DevAsyncTouch 13.0.0.DevAsyncTouch"
#INFINISPAN_PREBUILT_VERSIONS="9.4.24.DevAsyncTouch2"
INFINISPAN_PREBUILT_VERSIONS="9.4.24.DevAsyncTouch2 9.4.24.DevAsyncTouch3"
#INFINISPAN_PREBUILT_VERSIONS="9.4.24.DevAsyncTouch3"

WORK_DIR=$HOME/Work
INFINISPAN_HOME=$WORK_DIR/infinispan
#INFINISPAN_HOME=$WORK_DIR/jdg


INFINISPAN_COMMITS=""
#INFINISPAN_COMMITS="master"

MAVEN_SETTINGS=$INFINISPAN_HOME/maven-settings.xml
MAVEN_REPO=$(cat $MAVEN_SETTINGS | perl -ne 'if (/<localRepository>(.*)<\/localRepository>/) { print "$1\n" }' | sed "s%\${user.home}%$HOME%")
if [ -z "$MAVEN_REPO" ]; then
  MAVEN_REPO=~/.m2/repository
fi

FORCE_JGROUPS_VERSION=""
#FORCE_JGROUPS_VERSION="4.0.21.Final"
#FORCE_JGROUPS_VERSION="4.2.12.Final"

#INFINISPAN_CONFIG="../config/infinispan-sync.xml"
#INFINISPAN_CONFIG="../config/infinispan-sync-passivation-maxidle-84.xml"
INFINISPAN_CONFIG="../config/infinispan-sync-passivation-maxidle-asynctouch-94.xml"
#INFINISPAN_CONFIG="../config/infinispan-sync-passivation-maxidle-94.xml"

#JGROUPS_CONFIG="default-configs/default-jgroups-tcp.xml"
JGROUPS_CONFIG="default-configs/default-jgroups-udp.xml"
#JGROUPS_CONFIG="../config/udp-transfer-queue-94.xml"

TEST_JAVA_HOME=/home/dan/.sdkman/candidates/java/8.0.275.hs-adpt
#TEST_JAVA_HOME=/home/dan/.sdkman/candidates/java/11.0.10.hs-adpt

ASYNC_PROFILER_PATH=/home/dan/Tools/async-profiler/build

COMMON_OPTS="-XX:+UnlockDiagnosticVMOptions -XX:+DebugNonSafepoints -Xmx4g -XX:+HeapDumpOnOutOfMemoryError -XX:+UseG1GC -Djava.net.preferIPv4Stack=true"
#COMMON_OPTS="-XX:+UnlockDiagnosticVMOptions -XX:+DebugNonSafepoints -Xmx4g -XX:+UseG1GC -Djava.net.preferIPv4Stack=true"
COMMON_OPTS="$COMMON_OPTS -Dlog4j.configurationFile=file:///$WORK_DIR/infinispan-microbenchmarks/config/log4j2.xml -Dorg.jboss.logging.provider=log4j2"
#COMMON_OPTS="-XX:MaxInlineLevel=20"  #inlining helps a bit the async interceptors
#THROUGHPUT_OPTS="-javaagent:/$WORK_DIR/jHiccup/jHiccup.jar=\"-d $WARMUP_SECONDS -i 1000 -l hiccup.hlog\" -XX:+PrintGCDetails -XX:+PrintGCDateStamps -XX:+PrintGCApplicationStoppedTime"
#THROUGHPUT_OPTS="-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5006"
THROUGHPUT_OPTS=""
PERFASM_OPTS="-XX:PrintAssemblyOptions=intel"
JITWATCH_OPTS="-XX:+TraceClassLoading -XX:+LogCompilation -XX:+PrintInlining -XX:+PrintAssembly -XX:PrintAssemblyOptions=intel"
JFR_OPTIONS=""
JFR_PARENT_OPTIONS="-Djmh.jfr.stackdepth=128"
ALT_JFR_OPTIONS="-XX:+FlightRecorder -XX:FlightRecorderOptions=stackdepth=128 -XX:StartFlightRecording=settings=profile.jfc,delay=${WARMUP_SECONDS}s,dumponexit=true"
#ALT_JFR_OPTIONS="-XX:+UnlockCommercialFeatures -XX:+FlightRecorder -XX:FlightRecorderOptions=stackdepth=128 -XX:StartFlightRecording=settings=../config/allocation_profile.jfc,delay=${WARMUP_SECONDS}s,dumponexit=true"
#ALT_JFR_OPTIONS="-XX:+UnlockCommercialFeatures -XX:+FlightRecorder -XX:FlightRecorderOptions=stackdepth=128,dumponexitpath=. -XX:StartFlightRecording=settings=../config/exception_profile.jfc,delay=${WARMUP_SECONDS}s,dumponexit=true"
#cpupower --cpu all frequency-info | grep "current policy" | grep "and 3.00 GHz" || exit 9

function run_java() {
#  $TEST_JAVA_HOME/bin/java "$@"
  taskset -c $CORES $TEST_JAVA_HOME/bin/java "$@"
}

function log_version() {
  echo $(date)
  echo Infinispan $INFINISPAN_VERSION
  echo JGroups $JGROUPS_VERSION
  echo Current infinispan working dir commits:
  echo $LAST_COMMITS
  echo
}

function exit_on_error() {
  if [[ $? -ne 0 ]] ; then
    echo "Exiting because of an error in $1"
    exit 1
  fi
}

function run_build() {
PARAMS="-t $NUM_THREADS -w 5 -wi $((WARMUP_SECONDS / 5)) -r 5 -i $((TEST_SECONDS / 5)) -bm $BENCHMARK_MODE -tu $BENCHMARK_TIME_UNITS -p infinispanConfig=$INFINISPAN_CONFIG -p jgroupsConfig=$JGROUPS_CONFIG -p clusterSize=$CLUSTER_SIZE -p initialFillRatio=$FILL_RATIO -p numKeys=${NUM_KEYS} -p keySize=${KEY_SIZE} -p valueSize=${VALUE_SIZE}"

mvn -s $MAVEN_SETTINGS clean package -Dversion.infinispan=$INFINISPAN_VERSION -Dversion.jgroups=$JGROUPS_VERSION | tee build.log | tail -20
exit_on_error mvn

BASENAME=$PREFIX-$(date +%Y%m%d-%H%M)-${SUFFIX//[^a-zA-Z0-9-_.]/_}
log_version > $BASENAME.log
echo Results will be in $BASENAME.log

# straight results
if [ "$LOG_MAIN" == "1" ] ; then
  run_java -jar target/benchmarks.jar -jvmArgsPrepend "$COMMON_OPTS $THROUGHPUT_OPTS" -f 3 "$TEST" $PARAMS >>$BASENAME.log
  log_version >> $BASENAME.log
fi

# jHiccup results
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
   GC_OPTS="-XX:+IgnoreUnrecognizedVMOptions -XX:+PrintGCDetails -XX:+PrintGCApplicationStoppedTime -Xloggc:gc.log -Xlog:gc*,safepoint:gc.log:time,uptime"
   echo Collecting gc profiler logs
   run_java -jar target/benchmarks.jar -jvmArgsPrepend "$COMMON_OPTS" -f 1 -prof gc $TEST $PARAMS >>$BASENAME-perfnorm-gc.log
fi
if [ "$LOG_PERFNORM" == "1" -o "$LOG_GC" == "1" ] ; then
  log_version >> $BASENAME-perfnorm-gc.log
fi

# perfasm output
if [ "$LOG_PERFASM" == "1" ] ; then
   echo Collecting perfasm profiler logs
   LD_LIBRARY_PATH=/home/dan/Work/hotspot/src/share/tools/hsdis/build/linux-amd64/ \
   run_java -jar target/benchmarks.jar -jvmArgsPrepend "$COMMON_OPTS $PERFASM_OPTS" -f 1 \
   -prof perfasm:hotThreshold=0.01 $TEST $PARAMS &>$BASENAME-perfasm.log
   log_version >> $BASENAME-perfasm.log
fi

# jitwatch output
if [ "$LOG_JITWATCH" == "1" ] ; then
   echo Collecting jitwatch logs
   run_java -jar target/benchmarks.jar -jvmArgsPrepend "$COMMON_OPTS $JITWATCH_OPTS" -f 1 $TEST $PARAMS
   mv $(ls -t hotspot_pid*.log | head -1) $BASENAME-jitwatch.log
   log_version >> $BASENAME-perfasm.log
fi

# flight recorder + flamegraph output
if [ "$LOG_JFR" == "1" ] ; then
   echo Collecting JFR logs
   #run_java $JFR_PARENT_OPTIONS -jar target/benchmarks.jar -jvmArgsPrepend "$COMMON_OPTS $JFR_OPTIONS" -prof net.nicoulaj.jmh.profilers.FlightRecorderProfiler -f 1 $TEST $PARAMS
   run_java -jar target/benchmarks.jar -jvmArgsPrepend "$COMMON_OPTS $ALT_JFR_OPTIONS" -f 1 $TEST $PARAMS
   JFR_BASENAME=$BASENAME-flightrecorder
   I=0
   for f in hotspot-pid*.jfr ; do
      I=$((I + 1))
      mv $f $JFR_BASENAME$I.jfr
      ~/Work/jfr-flame-graph/run.sh -f $JFR_BASENAME$I.jfr -o >(sed -r -e 's/([^a-zA-Z]|^)([a-z])[a-z]+\./\1\2./g' -e 's/(\.[a-z])[a-z]+\./\1./g' >$JFR_BASENAME$I.stacks)
      ~/Work/FlameGraph/flamegraph.pl --width 1900 --colors hot --cp <$JFR_BASENAME$I.stacks >$JFR_BASENAME$I.svg
      rm $JFR_BASENAME$I.stacks
   done
   I=
fi

# async-profiler
if [ "$LOG_ASYNC" == "1" ] ; then
  echo Collecting async-profiler info
  ASYNC_PROFILER_BASENAME=$BASENAME-async-profiler
#  ASYNC_PROFILER_OPTIONS="-agentpath:${ASYNC_PROFILER_PATH}/libasyncProfiler.so=start,file=${ASYNC_PROFILER_BASENAME}.folded,collapsed,event=wall,exclude=epoll_wait,exclude=__pthread*,exclude=*__libc_recv*,exclude=__GI___poll"
  ASYNC_PROFILER_OPTIONS="-agentpath:${ASYNC_PROFILER_PATH}/libasyncProfiler.so=start,file=${ASYNC_PROFILER_BASENAME}.folded,collapsed,event=cpu"
  run_java -jar target/benchmarks.jar -jvmArgsPrepend "$COMMON_OPTS $ASYNC_PROFILER_OPTIONS" -f 1 "$TEST" $PARAMS | tee "$ASYNC_PROFILER_BASENAME.log"
#  ASYNC_PROFILER_PARAMS="libPath=$ASYNC_PROFILER_PATH/libasyncProfiler.so;output=text;event=wall;verbose=true"
#  run_java -jar target/benchmarks.jar -jvmArgsPrepend "$COMMON_OPTS" -f 1 "$TEST" $PARAMS -prof "async:$ASYNC_PROFILER_PARAMS" | tee "$ASYNC_PROFILER_BASENAME.log"
  log_version >> "$ASYNC_PROFILER_BASENAME.log"
  java -cp ${ASYNC_PROFILER_PATH}/converter.jar FlameGraph "${ASYNC_PROFILER_BASENAME}.folded" "${ASYNC_PROFILER_BASENAME}.html"
fi

echo Results are in $BASENAME.log
tail -1 $BASENAME.log
}

# main
for COMMIT in $INFINISPAN_COMMITS; do
  SUFFIX=$COMMIT
  BUILD_DIR=/tmp/build-infinispan-microbenchmarks
  rm -rf $BUILD_DIR
  git clone -s $INFINISPAN_HOME $BUILD_DIR
  pushd $BUILD_DIR
  git checkout $COMMIT
  mvn clean
  mvn install -DskipTests -am -pl core
  INFINISPAN_VERSION=$(cat core/pom.xml | perl -ne 'if (/<version>(.*)<\/version>/) { print "$1\n" }' | head -1)
  if [ -z $FORCE_JGROUPS_VERSION ]; then
    if [[ -d build-configuration ]]; then
      JGROUPS_VERSION=$(cat build-configuration/pom.xml | perl -ne 'if (/<version.jgroups>(.*)<\/version.jgroups>/) { print "$1\n" }')
    elif [ -d bom ]; then
      JGROUPS_VERSION=$(cat bom/pom.xml | perl -ne 'if (/<version.jgroups>(.*)<\/version.jgroups>/) { print "$1\n" }')
    else
      exit_on_error jgroups_version
    fi
  else
    JGROUPS_VERSION=$FORCE_JGROUPS_VERSION
  fi
  LAST_COMMITS=$(git log --pretty=format:"%H %s" -3 | git name-rev --stdin)
  popd

  run_build || echo "Failed to run test for $COMMIT"
  #rm -rf $BUILD_DIR
done

for INFINISPAN_VERSION in $INFINISPAN_PREBUILT_VERSIONS; do
  SUFFIX=$INFINISPAN_VERSION
  if [ -z $FORCE_JGROUPS_VERSION ]; then
    mvn -s $MAVEN_SETTINGS compile -Dversion.infinispan=$INFINISPAN_VERSION
    if [[ -d $MAVEN_REPO/org/infinispan/infinispan-build-configuration-parent/$INFINISPAN_VERSION ]]; then
      JGROUPS_VERSION=$(cat $MAVEN_REPO/org/infinispan/infinispan-build-configuration-parent/$INFINISPAN_VERSION/infinispan-build-configuration-parent-$INFINISPAN_VERSION.pom | perl -ne 'if (/<version.jgroups>(.*)<\/version.jgroups>/) { print "$1\n" }')
    elif [ -d $MAVEN_REPO/org/infinispan/infinispan-bom/$INFINISPAN_VERSION ]; then
      JGROUPS_VERSION=$(cat $MAVEN_REPO/org/infinispan/infinispan-bom/$INFINISPAN_VERSION/infinispan-bom-$INFINISPAN_VERSION.pom | perl -ne 'if (/<version.jgroups>(.*)<\/version.jgroups>/) { print "$1\n" }')
    else
      exit_on_error jgroups_version
    fi
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
