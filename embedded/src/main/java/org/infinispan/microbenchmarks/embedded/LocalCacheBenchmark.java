package org.infinispan.microbenchmarks.embedded;

import org.openjdk.jmh.annotations.Benchmark;
import org.openjdk.jmh.annotations.BenchmarkMode;
import org.openjdk.jmh.annotations.Mode;
import org.openjdk.jmh.annotations.OutputTimeUnit;
import org.openjdk.jmh.infra.Blackhole;

import java.util.concurrent.TimeUnit;

@BenchmarkMode(Mode.SampleTime)
@OutputTimeUnit(TimeUnit.MICROSECONDS)
public class LocalCacheBenchmark {

   @Benchmark
   public Object testGet(Blackhole blackhole, LocalCacheState state, KeySource keySource) {
      return state.getCache().get(keySource.nextKey());
   }

   @Benchmark
   public Object testPut(Blackhole blackhole, LocalCacheState state, KeySource keySource) {
      return state.getCache().put(keySource.nextKey(), keySource.nextValue());
   }
}
