package org.infinispan.microbenchmarks.embedded;

import org.infinispan.Cache;
import org.openjdk.jmh.annotations.Param;
import org.openjdk.jmh.annotations.Scope;
import org.openjdk.jmh.annotations.Setup;
import org.openjdk.jmh.annotations.State;
import org.openjdk.jmh.annotations.TearDown;

import java.nio.charset.Charset;
import java.util.concurrent.ThreadLocalRandom;

@State(Scope.Benchmark)
public class KeySource {
   @Param("1000")
   int numKeys;
   @Param("20")
   int keySize;
   @Param("200")
   int valueSize;
   @Param("0.5")
   float initialFillRatio;

   String[] keys;
   String[] values;

   @Setup
   public void setup() {
      keys = new String[numKeys];
      values = new String[numKeys];

      byte[] keyBytes = new byte[keySize];
      byte[] valueBytes = new byte[valueSize];
      for (int i = 0; i < numKeys; i++) {
         keys[i] = randomString(keyBytes);
         values[i] = randomString(valueBytes);
      }
   }

   private String randomString(byte[] bytes) {
      ThreadLocalRandom.current().nextBytes(bytes);
      for (int i = 0; i < bytes.length; i++) {
         // Stick to US-ASCII
         bytes[i] = (byte) ((bytes[i] & 0x3F) + 0x20);
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

   public int getNumKeys() {
      return numKeys;
   }

   public void populateCache(Cache cache) {
      for (int i = 0; i < numKeys * initialFillRatio; i++) {
         cache.put(keys[i], values[i]);
      }
   }
}
