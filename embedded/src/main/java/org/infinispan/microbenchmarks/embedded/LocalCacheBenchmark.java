package org.infinispan.microbenchmarks.embedded;

import org.openjdk.jmh.annotations.Benchmark;
import org.openjdk.jmh.infra.Blackhole;

public class LocalCacheBenchmark {

   @Benchmark
   public Object testGet(Blackhole blackhole, LocalCacheState state, KeySource keySource) {
      return state.getCache().get(keySource.nextKey());
   }
}
