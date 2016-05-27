package org.infinispan.microbenchmarks.local;

import org.infinispan.Cache;
import org.infinispan.configuration.parsing.ConfigurationBuilderHolder;
import org.infinispan.configuration.parsing.ParserRegistry;
import org.infinispan.context.Flag;
import org.infinispan.manager.DefaultCacheManager;
import org.infinispan.remoting.transport.jgroups.JGroupsTransport;
import org.infinispan.util.logging.Log;
import org.infinispan.util.logging.LogFactory;
import org.openjdk.jmh.annotations.Param;
import org.openjdk.jmh.annotations.Scope;
import org.openjdk.jmh.annotations.Setup;
import org.openjdk.jmh.annotations.State;
import org.openjdk.jmh.annotations.TearDown;

import java.io.IOException;

@State(Scope.Benchmark)
public class ReplCacheState {
   private static final Log log = LogFactory.getLog(ReplCacheState.class);

   @Param("4")
   int clusterSize;
   @Param("../config/stack-tcp.xml")
   private String jgroupsConfig;
   @Param("../config/infinispan-sync.xml")
   private String infinispanConfig;
   private String cacheName = "repl-sync";

   DefaultCacheManager[] managers;
   Cache cache;

   @Setup
   public void setup(KeySource keySource) throws IOException {
      Thread.setDefaultUncaughtExceptionHandler((t, e) -> {
         log.fatalf(e, "(%s:) Unhandled exception", t);
      });
      managers = new DefaultCacheManager[clusterSize];
      for (int i = 0; i < clusterSize; i++) {
         ConfigurationBuilderHolder holder = new ParserRegistry().parseFile(infinispanConfig);
         holder.getGlobalConfigurationBuilder().transport()
               .addProperty(JGroupsTransport.CONFIGURATION_FILE, jgroupsConfig);
         managers[i] = new DefaultCacheManager(holder, true);
         managers[i].getCache(cacheName);
      }

      cache = managers[0].getCache(cacheName).getAdvancedCache().withFlags(Flag.IGNORE_RETURN_VALUES);
      log.infof("Started cluster with CH %s", cache.getAdvancedCache().getDistributionManager().getConsistentHash());
      keySource.populateCache(cache);
   }

   @TearDown
   public void tearDown() {
      for (int i = 0; i < clusterSize; i++) {
         managers[i].stop();
      }
   }

   public Cache getCache() {
      return cache;
   }
}
