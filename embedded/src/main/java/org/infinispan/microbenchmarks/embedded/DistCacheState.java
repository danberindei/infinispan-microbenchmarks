package org.infinispan.microbenchmarks.embedded;

import org.infinispan.Cache;
import org.infinispan.configuration.parsing.ConfigurationBuilderHolder;
import org.infinispan.configuration.parsing.ParserRegistry;
import org.infinispan.context.Flag;
import org.infinispan.manager.DefaultCacheManager;
import org.infinispan.microbenchmarks.common.KeySource;
import org.infinispan.remoting.transport.Address;
import org.infinispan.remoting.transport.jgroups.JGroupsTransport;
import org.infinispan.util.logging.Log;
import org.infinispan.util.logging.LogFactory;
import org.openjdk.jmh.annotations.Param;
import org.openjdk.jmh.annotations.Scope;
import org.openjdk.jmh.annotations.Setup;
import org.openjdk.jmh.annotations.State;
import org.openjdk.jmh.annotations.TearDown;

import java.io.IOException;
import java.util.HashMap;
import java.util.Map;

@State(Scope.Benchmark)
public class DistCacheState {
   private static final Log log = LogFactory.getLog(DistCacheState.class);

   @Param("4")
   int clusterSize;
   @Param("missing")
   private String jgroupsConfig;
   @Param("missing")
   private String infinispanConfig;
   private String cacheName = "dist-sync";

   DefaultCacheManager[] managers;
   Cache[] caches;
   Cache[] writeCaches;
   Map<Address, Cache> cachesMap;
   Map<Address, Cache> writeCachesMap;


   @Setup
   public void setup(KeySource keySource) throws IOException {
      Thread.setDefaultUncaughtExceptionHandler((t, e) -> {
         log.fatalf(e, "(%s:) Unhandled exception", t);
      });
      managers = new DefaultCacheManager[clusterSize];
      caches = new Cache[clusterSize];
      writeCaches = new Cache[clusterSize];
      cachesMap = new HashMap<>();
      writeCachesMap = new HashMap<>();
      for (int i = 0; i < clusterSize; i++) {
         ConfigurationBuilderHolder holder = new ParserRegistry().parseFile(infinispanConfig);
         String nodeName = "Node" + (char) ('A' + i);
         holder.getGlobalConfigurationBuilder().transport()
               .nodeName(nodeName)
               .addProperty(JGroupsTransport.CONFIGURATION_FILE, jgroupsConfig);
         log.infof("Starting node %s", nodeName);
         managers[i] = new DefaultCacheManager(holder, true);
         caches[i] = managers[i].getCache(cacheName);
         writeCaches[i] = caches[i].getAdvancedCache().withFlags(Flag.IGNORE_RETURN_VALUES);
         cachesMap.put(managers[i].getAddress(), caches[i]);
         writeCachesMap.put(managers[i].getAddress(), writeCaches[i]);
         log.infof("Started node %s", managers[i].getAddress());
      }

//      System.out.println("Running with Infinispan " + Version.getVersion() + ", " + org.jgroups.Version.printDescription());
      System.out.println("Running with " + org.jgroups.Version.printDescription());
      log.infof("Started cluster with CH %s", caches[0].getAdvancedCache().getDistributionManager().getConsistentHash());
      keySource.populateCache((key, value) -> caches[0].put(key, value));
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

   public Cache getPrimaryCache(Object key) {
      return cachesMap.get(caches[0].getAdvancedCache().getDistributionManager().getPrimaryLocation(key));
   }

   public Cache getWriteCache(long threadId) {
      return writeCaches[(int) (threadId % clusterSize)];
   }

   public Cache getPrimaryWriteCache(Object key) {
      return writeCachesMap.get(caches[0].getAdvancedCache().getDistributionManager().getPrimaryLocation(key));
   }
}
