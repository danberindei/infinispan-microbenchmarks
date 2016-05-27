package org.infinispan.microbenchmarks.local;

import org.openjdk.jmh.annotations.Benchmark;
import org.openjdk.jmh.annotations.Fork;
import org.openjdk.jmh.annotations.Threads;
import org.openjdk.jmh.infra.Blackhole;

@Fork(jvmArgs = {"-Djava.net.preferIPv4Stack=true"})
public class DistCacheBenchmark {

   @Benchmark
   public Object testGet(Blackhole blackhole, DistCacheState state, KeySource keySource) {
      return state.getCache(Thread.currentThread().getId()).get(keySource.nextKey());
   }
}
