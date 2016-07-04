package org.infinispan.microbenchmarks.embedded;

import org.infinispan.Cache;
import org.infinispan.manager.DefaultCacheManager;
import org.infinispan.manager.EmbeddedCacheManager;
import org.infinispan.microbenchmarks.common.KeySource;
import org.openjdk.jmh.annotations.Scope;
import org.openjdk.jmh.annotations.Setup;
import org.openjdk.jmh.annotations.State;
import org.openjdk.jmh.annotations.TearDown;

@State(Scope.Benchmark)
public class LocalCacheState {

   EmbeddedCacheManager manager;
   Cache cache;

   @Setup
   public void setup(KeySource keySource) {
      manager = new DefaultCacheManager();
      cache = manager.getCache();

      keySource.populateCache((key, value) -> cache.put(key, value));
   }

   @TearDown
   public void tearDown() {
      manager.stop();
   }

   public Cache getCache() {
      return cache;
   }
}
