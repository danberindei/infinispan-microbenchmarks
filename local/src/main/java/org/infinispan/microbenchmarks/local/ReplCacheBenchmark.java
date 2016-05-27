package org.infinispan.microbenchmarks.local;

import org.openjdk.jmh.annotations.Benchmark;
import org.openjdk.jmh.annotations.BenchmarkMode;
import org.openjdk.jmh.annotations.Fork;
import org.openjdk.jmh.annotations.Group;
import org.openjdk.jmh.annotations.GroupThreads;
import org.openjdk.jmh.annotations.Mode;
import org.openjdk.jmh.annotations.OutputTimeUnit;
import org.openjdk.jmh.annotations.Threads;
import org.openjdk.jmh.infra.Blackhole;

import java.util.concurrent.TimeUnit;

@Fork(jvmArgs = {"-Djava.net.preferIPv4Stack=true"})
@BenchmarkMode(Mode.SampleTime)
@OutputTimeUnit(TimeUnit.MILLISECONDS)
public class ReplCacheBenchmark {

   @Threads(400)
   @Benchmark
   public Object testGet(Blackhole blackhole, ReplCacheState state, KeySource keySource) {
      return state.getCache().get(keySource.nextKey());
   }

   @Threads(400)
   @Benchmark
   public Object testPut(Blackhole blackhole, ReplCacheState state, KeySource keySource) {
      return state.getCache().put(keySource.nextKey(), keySource.nextValue());
   }
}
