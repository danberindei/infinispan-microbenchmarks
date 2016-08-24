package org.infinispan.microbenchmarks.remote;

/**
 * @author Dan Berindei
 * @since 9.0
 */
public class MemcachedDistCacheState extends MemcachedReplCacheState {
   public MemcachedDistCacheState() {
      super("dist-sync");
   }
}
