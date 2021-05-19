package org.infinispan.microbenchmarks.embedded;

import org.infinispan.Cache;
import org.infinispan.configuration.cache.ConfigurationBuilder;
import org.infinispan.configuration.cache.StorageType;
import org.infinispan.eviction.EvictionType;
import org.infinispan.manager.DefaultCacheManager;
import org.infinispan.manager.EmbeddedCacheManager;
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
      ConfigurationBuilder builder = new ConfigurationBuilder();
      builder.memory()
            .storageType(StorageType.OFF_HEAP)
//            .evictionType(EvictionType.COUNT)
//            .size(2000)
      ;
      manager = new DefaultCacheManager(builder.build());
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
