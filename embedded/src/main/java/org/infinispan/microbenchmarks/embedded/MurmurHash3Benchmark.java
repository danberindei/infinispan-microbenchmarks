package org.infinispan.microbenchmarks.embedded;

import java.util.concurrent.TimeUnit;

import org.infinispan.commons.hash.MurmurHash3;
import org.infinispan.microbenchmarks.common.KeySource;
import org.openjdk.jmh.annotations.Benchmark;
import org.openjdk.jmh.annotations.BenchmarkMode;
import org.openjdk.jmh.annotations.Fork;
import org.openjdk.jmh.annotations.Mode;
import org.openjdk.jmh.annotations.OutputTimeUnit;
import org.openjdk.jmh.infra.Blackhole;
import org.openjdk.jmh.runner.Runner;
import org.openjdk.jmh.runner.RunnerException;
import org.openjdk.jmh.runner.options.Options;
import org.openjdk.jmh.runner.options.OptionsBuilder;
import org.openjdk.jmh.runner.options.TimeValue;

@Fork(jvmArgs = {"-Djava.net.preferIPv4Stack=true"})
@BenchmarkMode(Mode.SampleTime)
@OutputTimeUnit(TimeUnit.MICROSECONDS)
public class MurmurHash3Benchmark {
   @Benchmark
   public int testHash(Blackhole blackhole, KeySource keySource) {
      return MurmurHash3.getInstance().hash(keySource.nextKey());
   }

   public static void main(String[] args) throws RunnerException {
      // org.infinispan.microbenchmarks.embedded.ReplCacheBenchmark.testGet -w 5 -wi 1 -r 5 -i 6 -bm thrpt
      // -p clusterSize=4 -p infinispanConfig=../config/infinispan-sync.xml -p initialFillRatio=0.5
      // -p jgroupsConfig=default-configs/default-jgroups-tcp.xml -p keySize=20 -p numKeys=1000 -p valueSize=200
      Options opt = new OptionsBuilder()
            .include("MurmurHash3Benchmark.testHash")
            .forks(0)
            .mode(Mode.Throughput)
            .warmupIterations(5)
            .warmupTime(TimeValue.seconds(1))
            .measurementIterations(5)
            .measurementTime(TimeValue.seconds(6))
            .param("keySize", "20")
            .param("numKeys", "10000")
            .build();

      new Runner(opt).run();
   }}
