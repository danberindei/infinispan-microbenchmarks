package org.infinispan.microbenchmarks.local;

import org.openjdk.jmh.annotations.Benchmark;
import org.openjdk.jmh.annotations.Fork;
import org.openjdk.jmh.annotations.Setup;
import org.openjdk.jmh.infra.Blackhole;

public class LocalCacheBenchmark {

   @Benchmark
   public Object testGet(Blackhole blackhole, LocalCacheState state, KeySource keySource) {
      return state.getCache().get(keySource.nextKey());
   }
}
