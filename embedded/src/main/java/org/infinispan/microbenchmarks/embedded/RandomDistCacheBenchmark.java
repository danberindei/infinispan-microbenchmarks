package org.infinispan.microbenchmarks.embedded;

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

import javax.transaction.HeuristicMixedException;
import javax.transaction.HeuristicRollbackException;
import javax.transaction.NotSupportedException;
import javax.transaction.RollbackException;
import javax.transaction.SystemException;
import java.util.concurrent.TimeUnit;

@Fork(jvmArgs = {"-Djava.net.preferIPv4Stack=true"})
@BenchmarkMode(Mode.SampleTime)
@OutputTimeUnit(TimeUnit.MICROSECONDS)
public class RandomDistCacheBenchmark {

   @Benchmark
   public Object testGet(Blackhole blackhole, DistCacheState state, KeySource keySource) {
      return state.getCache(Thread.currentThread().getId()).get(keySource.nextKey());
   }

   @Benchmark
   public Object testPut(Blackhole blackhole, DistCacheState state, KeySource keySource) {
      return state.getWriteCache(Thread.currentThread().getId()).put(keySource.nextKey(), keySource.nextValue());
   }


   @Benchmark
   public void testTxGet(Blackhole blackhole, DistCacheState state, KeySource keySource)
         throws SystemException, NotSupportedException, HeuristicRollbackException, HeuristicMixedException,
         RollbackException {
      Cache cache = state.getCache(Thread.currentThread().getId());
      cache.getAdvancedCache().getTransactionManager().begin();
      try {
         blackhole.consume(cache.get(keySource.nextKey()));
      } finally {
         cache.getAdvancedCache().getTransactionManager().commit();
      }
   }

   @Benchmark
   public void testTxPut(Blackhole blackhole, DistCacheState state, KeySource keySource)
         throws SystemException, NotSupportedException, HeuristicRollbackException, HeuristicMixedException,
         RollbackException {
      Cache cache = state.getWriteCache(Thread.currentThread().getId());
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
            .include("RandomDistCacheBenchmark.testPut")
            .forks(0)
            .mode(Mode.Throughput)
            .warmupIterations(5)
            .warmupTime(TimeValue.seconds(1))
            .measurementIterations(5)
            .measurementTime(TimeValue.seconds(6))
            .param("clusterSize", "4")
            .param("infinispanConfig", "../config/infinispan-sync.xml")
            .param("initialFillRatio", "0.5")
            .param("jgroupsConfig", "default-configs/default-jgroups-udp.xml")
            .param("keySize", "20")
            .param("numKeys", "1000")
            .param("valueSize", "200")
            .build();

      new Runner(opt).run();
   }
}
