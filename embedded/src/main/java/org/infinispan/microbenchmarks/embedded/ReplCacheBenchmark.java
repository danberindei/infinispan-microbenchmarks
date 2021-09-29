package org.infinispan.microbenchmarks.embedded;

import java.util.concurrent.TimeUnit;

import org.infinispan.Cache;
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
public class ReplCacheBenchmark {

   @Benchmark
   public Object testGet(Blackhole blackhole, EmbeddedCacheState state, KeySource keySource) {
      return state.getReplCache(Thread.currentThread().getId()).get(keySource.nextKey());
   }

   @Benchmark
   public Object testPut(Blackhole blackhole, EmbeddedCacheState state, KeySource keySource) {
      return state.getReplCache(Thread.currentThread().getId()).put(keySource.nextKey(), keySource.nextValue());
   }

   @Benchmark
   public void testTxGet(Blackhole blackhole, EmbeddedCacheState state, KeySource keySource)
         throws Exception {
      Cache cache = state.getReplCache(Thread.currentThread().getId());
      cache.getAdvancedCache().getTransactionManager().begin();
      try {
         blackhole.consume(cache.get(keySource.nextKey()));
      } finally {
         cache.getAdvancedCache().getTransactionManager().commit();
      }
   }

   @Benchmark
   public void testTxPut(Blackhole blackhole, EmbeddedCacheState state, KeySource keySource)
         throws Exception {
      Cache cache = state.getReplCache(Thread.currentThread().getId());
      cache.getAdvancedCache().getTransactionManager().begin();
      try {
         blackhole.consume(cache.put(keySource.nextKey(), keySource.nextValue()));
      } finally {
         cache.getAdvancedCache().getTransactionManager().commit();
      }
   }

   public static void main(String[] args) throws RunnerException {
      // org.infinispan.microbenchmarks.embedded.ReplCacheBenchmark.testGet -w 5 -wi 1 -r 5 -i 6 -bm thrpt
      // -p clusterSize=4 -p infinispanConfig=../config/infinispan-sync.xml -p initialFillRatio=0.5
      // -p jgroupsConfig=default-configs/default-jgroups-tcp.xml -p keySize=20 -p numKeys=1000 -p valueSize=200
      Options opt = new OptionsBuilder()
            .include("ReplCacheBenchmark.testTxPut")
            .forks(0)
            .mode(Mode.Throughput)
            .timeUnit(TimeUnit.SECONDS)
            .warmupIterations(5)
            .warmupTime(TimeValue.seconds(6))
            .measurementIterations(1)
            .measurementTime(TimeValue.seconds(6))
            .threads(40)
            .param("clusterSize", "4")
            .param("infinispanConfig", "../config/infinispan-synctx.xml")
            .param("initialFillRatio", "1.0")
            .param("jgroupsConfig", "default-configs/default-jgroups-udp.xml")
            .param("keySize", "50")
            .param("numKeys", "5000")
            .param("valueSize", "10000")
            .build();

      new Runner(opt).run();
   }
}
