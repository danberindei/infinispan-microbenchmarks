package org.infinispan.microbenchmarks.embedded;

import org.openjdk.jmh.annotations.Benchmark;
import org.openjdk.jmh.annotations.BenchmarkMode;
import org.openjdk.jmh.annotations.Fork;
import org.openjdk.jmh.annotations.Mode;
import org.openjdk.jmh.annotations.OutputTimeUnit;
import org.openjdk.jmh.infra.Blackhole;

import java.util.concurrent.TimeUnit;

@Fork(jvmArgs = {"-Djava.net.preferIPv4Stack=true"})
@BenchmarkMode(Mode.SampleTime)
@OutputTimeUnit(TimeUnit.MICROSECONDS)
public class PrimaryDistCacheBenchmark {

   @Benchmark
   public Object testGet(Blackhole blackhole, EmbeddedCacheState state, KeySource keySource) {
      String key = keySource.nextKey();
      return state.getPrimaryCache(key).get(key);
   }

   @Benchmark
   public Object testPut(Blackhole blackhole, EmbeddedCacheState state, KeySource keySource) {
      String key = keySource.nextKey();
      return state.getPrimaryCache(key).put(key, keySource.nextValue());
   }
}
