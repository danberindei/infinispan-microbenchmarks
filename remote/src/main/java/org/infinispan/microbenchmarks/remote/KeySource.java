package org.infinispan.microbenchmarks.remote;

import java.nio.charset.Charset;
import java.util.concurrent.ThreadLocalRandom;
import java.util.function.BiConsumer;

import org.openjdk.jmh.annotations.Param;
import org.openjdk.jmh.annotations.Scope;
import org.openjdk.jmh.annotations.Setup;
import org.openjdk.jmh.annotations.State;
import org.openjdk.jmh.annotations.TearDown;

@State(Scope.Benchmark)
public class KeySource {
   @Param("1000")
   int numKeys;
   @Param("20")
   int keySize;
   @Param("1000")
   int valueSize;
   @Param("1.0")
   float initialFillRatio;

   String[] keys;
   String[] values;
   byte[][] byteArrayValues;

   @Setup
   public void setup() {
      keys = new String[numKeys];
      values = new String[numKeys];
      byteArrayValues = new byte[numKeys][];

      byte[] keyBytes = new byte[keySize];
      byte[] valueBytes = new byte[valueSize];
      for (int i = 0; i < numKeys; i++) {
         keys[i] = randomString(keyBytes);
         values[i] = randomString(valueBytes);
         byteArrayValues[i] = values[i].getBytes();
      }
   }

   private String randomString(byte[] bytes) {
      ThreadLocalRandom.current().nextBytes(bytes);
      for (int i = 0; i < bytes.length; i++) {
         // Stick to US-ASCII
         bytes[i] = (byte) ((bytes[i] & 0x3F) + 0x40);
      }
      return new String(bytes, Charset.forName("US-ASCII"));
   }

   @TearDown
   public void tearDown() {
   }

   public String nextKey() {
      return keys[ThreadLocalRandom.current().nextInt(numKeys)];
   }

   public String nextValue() {
      return values[ThreadLocalRandom.current().nextInt(numKeys)];
   }

   public byte[] nextByteArrayValue() {
      return byteArrayValues[ThreadLocalRandom.current().nextInt(numKeys)];
   }

   public int getNumKeys() {
      return numKeys;
   }

   public void populateCache(BiConsumer<String, String> writer) {
      for (int i = 0; i < numKeys * initialFillRatio; i++) {
         writer.accept(keys[i], values[i]);
      }
   }
}
