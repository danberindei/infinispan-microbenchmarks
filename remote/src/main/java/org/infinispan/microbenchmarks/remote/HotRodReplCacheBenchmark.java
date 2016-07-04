package org.infinispan.microbenchmarks.remote;

import org.infinispan.microbenchmarks.common.KeySource;
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
public class HotRodReplCacheBenchmark {

   @Benchmark
   public Object testGet(Blackhole blackhole, HotRodCacheState state, KeySource keySource) {
      return state.getReplCache(Thread.currentThread().getId()).get(keySource.nextKey());
   }

   @Benchmark
   public Object testPut(Blackhole blackhole, HotRodCacheState state, KeySource keySource) {
      return state.getReplCache(Thread.currentThread().getId()).put(keySource.nextKey(), keySource.nextValue());
   }
}
