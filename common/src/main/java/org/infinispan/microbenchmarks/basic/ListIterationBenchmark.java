package org.infinispan.microbenchmarks.basic;

import org.openjdk.jmh.annotations.Benchmark;
import org.openjdk.jmh.annotations.Scope;
import org.openjdk.jmh.annotations.Setup;
import org.openjdk.jmh.annotations.State;
import org.openjdk.jmh.infra.Blackhole;

@State(Scope.Benchmark)
public class ListIterationBenchmark {
   private Node list;

   @Setup
   public void setup() {
      list = new Node(1, new Node(2, new Node(3, null)));
   }

   @Benchmark
   public void testIteration1(Blackhole blackhole) {
      Iterator iterator = new Iterator(list);
      while (iterator.hasNext()) {
         int value = iterator.next();
         blackhole.consume(value);
      }
   }

   @Benchmark
   public void testIteration2(Blackhole blackhole) {
      Iterator iterator = new Iterator(list);
      while (iterator.hasNext()) {
         iterator.next();
         blackhole.consume(iterator);
      }
   }

   private static class Node {
      public Node(int value, Node next) {
         this.value = value;
         this.next = next;
      }

      public final int value;
      public final Node next;
   }

   private static class Iterator {
      private Node nextNode;

      public Iterator(Node nextNode) {
         this.nextNode = nextNode;
      }

      public boolean hasNext() {
         return nextNode != null;
      }

      public int next() {
         int value = nextNode.value;
         nextNode = nextNode.next;
         return value;
      }
   }
}
