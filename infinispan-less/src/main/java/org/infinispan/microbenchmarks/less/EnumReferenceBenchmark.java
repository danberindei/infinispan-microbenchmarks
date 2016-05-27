package org.infinispan.microbenchmarks.less;

import org.openjdk.jmh.annotations.Benchmark;
import org.openjdk.jmh.annotations.Param;
import org.openjdk.jmh.annotations.Scope;
import org.openjdk.jmh.annotations.Setup;
import org.openjdk.jmh.annotations.State;
import org.openjdk.jmh.infra.Blackhole;

import java.util.concurrent.ThreadLocalRandom;

enum Color {
   RED(1),
   GREEN(2),
   BLUE(4);

   public final int value;

   Color(int value) {
      this.value = value;
   }
}

@State(Scope.Benchmark)
public class EnumReferenceBenchmark {
   @Param("10")
   int size;

   @Setup
   public void setup() {
   }

   @Benchmark
   public void testValue(Blackhole blackhole) {
      blackhole.consume((size & Color.RED.value) == 0);
   }

   @Benchmark
   public void testOrdinal(Blackhole blackhole) {
      blackhole.consume((size & (1 << Color.RED.ordinal())) == 0);
   }
}
