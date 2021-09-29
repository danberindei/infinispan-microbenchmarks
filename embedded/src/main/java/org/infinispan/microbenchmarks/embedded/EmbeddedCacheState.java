package org.infinispan.microbenchmarks.embedded;

import java.io.IOException;
import java.util.HashMap;
import java.util.Map;

import org.infinispan.Cache;
import org.infinispan.configuration.parsing.ConfigurationBuilderHolder;
import org.infinispan.configuration.parsing.ParserRegistry;
import org.infinispan.context.Flag;
import org.infinispan.distribution.LocalizedCacheTopology;
import org.infinispan.manager.DefaultCacheManager;
import org.infinispan.remoting.transport.Address;
import org.infinispan.remoting.transport.jgroups.JGroupsTransport;
import org.infinispan.util.logging.Log;
import org.infinispan.util.logging.LogFactory;
import org.openjdk.jmh.annotations.Param;
import org.openjdk.jmh.annotations.Scope;
import org.openjdk.jmh.annotations.Setup;
import org.openjdk.jmh.annotations.State;
import org.openjdk.jmh.annotations.TearDown;

@State(Scope.Benchmark)
public class EmbeddedCacheState {
   private static final Log log = LogFactory.getLog(EmbeddedCacheState.class);

   @Param("4")
   int clusterSize;
   @Param("missing")
   private String jgroupsConfig;
   @Param("missing")
   private String infinispanConfig;
   private String replCacheName = "repl-sync";
   private String distCacheName = "dist-sync";

   DefaultCacheManager[] managers;
   Cache[] replCaches;
   Cache[] distCaches;
   Map<Address, Cache> distCacheMap;

   @Setup
   public void setup(KeySource keySource) throws IOException {
      System.setProperty("jgroups.stack.file", jgroupsConfig);
      Thread.setDefaultUncaughtExceptionHandler((t, e) -> {
         log.fatalf(e, "(%s:) Unhandled exception", t);
      });
      managers = new DefaultCacheManager[clusterSize];
      distCaches = new Cache[clusterSize];
      replCaches = new Cache[clusterSize];
      distCacheMap = new HashMap<>();
      for (int i = 0; i < clusterSize; i++) {
         ConfigurationBuilderHolder holder = new ParserRegistry().parseFile(infinispanConfig);
         holder.getGlobalConfigurationBuilder().transport()
               .nodeName("Node" + (char) ('A' + i))
               .addProperty(JGroupsTransport.CONFIGURATION_FILE, jgroupsConfig);
         managers[i] = new DefaultCacheManager(holder, true);
         replCaches[i] = managers[i].getCache(replCacheName).getAdvancedCache().withFlags(Flag.IGNORE_RETURN_VALUES);
         distCaches[i] = managers[i].getCache(distCacheName).getAdvancedCache().withFlags(Flag.IGNORE_RETURN_VALUES);
         distCacheMap.put(managers[i].getAddress(), distCaches[i]);
      }

//      System.out.println("Running with Infinispan " + Version.getVersion() + ", " + org.jgroups.Version.printDescription());
      System.out.println("Running with " + org.jgroups.Version.printDescription());
      log.infof("Started cluster with CH %s", replCaches[0].getAdvancedCache().getDistributionManager().getCacheTopology().getReadConsistentHash());
      keySource.populateCache((key, value) -> replCaches[0].put(key, value));
      keySource.populateCache((key, value) -> distCaches[0].put(key, value));
   }

   @TearDown
   public void tearDown() {
      for (int i = 0; i < clusterSize; i++) {
         managers[i].stop();
      }
   }

   public Cache getReplCache(long threadId) {
      return replCaches[(int) (threadId % clusterSize)];
   }

   public Cache getDistCache(long threadId) {
      return distCaches[(int) (threadId % clusterSize)];
   }

   public Cache getPrimaryCache(Object key) {
      LocalizedCacheTopology cacheTopology = distCaches[0].getAdvancedCache().getDistributionManager().getCacheTopology();
      return distCacheMap.get(cacheTopology.getDistribution(key).primary());
   }
}
