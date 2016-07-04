package org.infinispan.microbenchmarks.embedded;

import org.infinispan.Cache;
import org.infinispan.microbenchmarks.common.KeySource;
import org.openjdk.jmh.annotations.Benchmark;
import org.openjdk.jmh.annotations.BenchmarkMode;
import org.openjdk.jmh.annotations.Fork;
import org.openjdk.jmh.annotations.Mode;
import org.openjdk.jmh.annotations.OutputTimeUnit;
import org.openjdk.jmh.infra.Blackhole;

import javax.transaction.HeuristicMixedException;
import javax.transaction.HeuristicRollbackException;
import javax.transaction.NotSupportedException;
import javax.transaction.RollbackException;
import javax.transaction.SystemException;
import java.util.concurrent.TimeUnit;

@Fork(jvmArgs = {"-Djava.net.preferIPv4Stack=true"})
@BenchmarkMode(Mode.SampleTime)
@OutputTimeUnit(TimeUnit.MICROSECONDS)
public class ReplCacheBenchmark {

   @Benchmark
   public Object testGet(Blackhole blackhole, ReplCacheState state, KeySource keySource) {
      return state.getCache(Thread.currentThread().getId()).get(keySource.nextKey());
   }

   @Benchmark
   public Object testPut(Blackhole blackhole, ReplCacheState state, KeySource keySource) {
      return state.getCache(Thread.currentThread().getId()).put(keySource.nextKey(), keySource.nextValue());
   }

   @Benchmark
   public void testTxGet(Blackhole blackhole, ReplCacheState state, KeySource keySource)
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
   public void testTxPut(Blackhole blackhole, ReplCacheState state, KeySource keySource)
         throws SystemException, NotSupportedException, HeuristicRollbackException, HeuristicMixedException,
         RollbackException {
      Cache cache = state.getCache(Thread.currentThread().getId());
      cache.getAdvancedCache().getTransactionManager().begin();
      try {
         blackhole.consume(cache.put(keySource.nextKey(), keySource.nextValue()));
      } finally {
         cache.getAdvancedCache().getTransactionManager().commit();
      }
   }
}
