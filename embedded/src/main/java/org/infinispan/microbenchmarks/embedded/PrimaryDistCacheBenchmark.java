package org.infinispan.microbenchmarks.embedded;

import org.openjdk.jmh.annotations.Benchmark;
import org.openjdk.jmh.annotations.BenchmarkMode;
import org.openjdk.jmh.annotations.Fork;
import org.openjdk.jmh.annotations.Mode;
import org.openjdk.jmh.annotations.OutputTimeUnit;
import org.openjdk.jmh.annotations.Threads;
import org.openjdk.jmh.infra.Blackhole;

import java.util.concurrent.TimeUnit;

@Fork(jvmArgs = {"-Djava.net.preferIPv4Stack=true"})
@BenchmarkMode(Mode.SampleTime)
@OutputTimeUnit(TimeUnit.MILLISECONDS)
public class PrimaryDistCacheBenchmark {

   @Threads(400)
   @Benchmark
   public Object testGet(Blackhole blackhole, DistCacheState state, KeySource keySource) {
      String key = keySource.nextKey();
      return state.getPrimaryCache(key).get(key);
   }

   @Threads(400)
   @Benchmark
   public Object testPut(Blackhole blackhole, DistCacheState state, KeySource keySource) {
      String key = keySource.nextKey();
      return state.getPrimaryCache(key).put(key, keySource.nextValue());
   }
}
