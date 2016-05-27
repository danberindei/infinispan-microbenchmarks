package org.infinispan.microbenchmarks.local;

import org.infinispan.Cache;
import org.infinispan.configuration.parsing.ConfigurationBuilderHolder;
import org.infinispan.configuration.parsing.ParserRegistry;
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
public class DistCacheState {
   private static final Log log = LogFactory.getLog(DistCacheState.class);

   @Param("4")
   int clusterSize;
   @Param("../config/stack-tcp.xml")
   private String jgroupsConfig;
   @Param("../config/infinispan-sync.xml")
   private String infinispanConfig;
   private String cacheName = "dist-sync";

   DefaultCacheManager[] managers;
   Cache[] caches;

   @Setup
   public void setup(KeySource keySource) throws IOException {
      managers = new DefaultCacheManager[clusterSize];
      caches = new Cache[clusterSize];
      for (int i = 0; i < clusterSize; i++) {
         ConfigurationBuilderHolder holder = new ParserRegistry().parseFile(infinispanConfig);
         holder.getGlobalConfigurationBuilder().transport()
               .addProperty(JGroupsTransport.CONFIGURATION_FILE, jgroupsConfig);
         managers[i] = new DefaultCacheManager(holder, true);
         caches[i] = managers[i].getCache(cacheName);
      }

      log.infof("Started cluster with CH %s", caches[0].getAdvancedCache().getDistributionManager().getConsistentHash());
      keySource.populateCache(caches[0]);
   }

   @TearDown
   public void tearDown() {
      for (int i = 0; i < clusterSize; i++) {
         managers[i].stop();
      }
   }

   public Cache getCache(long threadId) {
      return caches[(int) (threadId % clusterSize)];
   }
}
