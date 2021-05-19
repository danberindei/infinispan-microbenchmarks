package org.infinispan.microbenchmarks.remote;

import net.spy.memcached.MemcachedClient;
import org.infinispan.Cache;
import org.infinispan.configuration.parsing.ConfigurationBuilderHolder;
import org.infinispan.configuration.parsing.ParserRegistry;
import org.infinispan.manager.DefaultCacheManager;
import org.infinispan.remoting.transport.jgroups.JGroupsTransport;
import org.infinispan.server.memcached.MemcachedServer;
import org.infinispan.server.memcached.configuration.MemcachedServerConfiguration;
import org.infinispan.server.memcached.configuration.MemcachedServerConfigurationBuilder;
import org.infinispan.util.logging.Log;
import org.infinispan.util.logging.LogFactory;
import org.openjdk.jmh.annotations.Param;
import org.openjdk.jmh.annotations.Scope;
import org.openjdk.jmh.annotations.Setup;
import org.openjdk.jmh.annotations.State;
import org.openjdk.jmh.annotations.TearDown;

import java.io.IOException;
import java.net.InetSocketAddress;

@State(Scope.Benchmark)
public class MemcachedReplCacheState {
   private static final Log log = LogFactory.getLog(MemcachedReplCacheState.class);

   @Param("4")
   int clusterSize;
   @Param("missing")
   private String jgroupsConfig;
   @Param("missing")
   private String infinispanConfig;
   private String cacheName;
   private String host = "127.0.0.1";
   private int basePort = 22200;

   DefaultCacheManager[] managers;
   MemcachedServer[] servers;
   MemcachedClient[] clients;

   public MemcachedReplCacheState() {
      this("repl-sync");
   }

   public MemcachedReplCacheState(String cacheName) {
      this.cacheName = cacheName;
   }

   @Setup
   public void setup(KeySource keySource) throws IOException {
      Thread.setDefaultUncaughtExceptionHandler((t, e) -> {
         log.fatalf(e, "(%s:) Unhandled exception", t);
      });
      managers = new DefaultCacheManager[clusterSize];
      servers = new MemcachedServer[clusterSize];
      InetSocketAddress[] serverAddresses = new InetSocketAddress[clusterSize];
      for (int i = 0; i < clusterSize; i++) {
         ConfigurationBuilderHolder embeddedConfiguration = new ParserRegistry().parseFile(infinispanConfig);
         embeddedConfiguration.getGlobalConfigurationBuilder().transport().nodeName("Node" + (char) ('A' + i))
               .addProperty(JGroupsTransport.CONFIGURATION_FILE, jgroupsConfig);
         managers[i] = new DefaultCacheManager(embeddedConfiguration, true);
         servers[i] = new MemcachedServer();
         host = "127.0.0.1";
         int port = basePort + i;
         MemcachedServerConfiguration replServerConfiguration =
               new MemcachedServerConfigurationBuilder().host(host).port(port).defaultCacheName(cacheName).build();
         servers[i].start(replServerConfiguration, managers[i]);
         serverAddresses[i] = new InetSocketAddress(host, port);
      }

      clients = new MemcachedClient[clusterSize];
      for (int i = 0; i < clusterSize; i++) {
         clients[i] = new MemcachedClient(serverAddresses);
      }

//      System.out.println("Running with Infinispan " + Version.getVersion() + ", " + org.jgroups.Version
// .printDescription());
      System.out.println("Running with " + org.jgroups.Version.printDescription());
      log.infof("Started repl cache with CH %s",
            managers[0].getCache(cacheName).getAdvancedCache().getDistributionManager()
                  .getConsistentHash());
      log.infof("Started dist cache with CH %s",
            managers[0].getCache(cacheName).getAdvancedCache().getDistributionManager()
                  .getConsistentHash());
      Cache<Object, Object> embeddedCache = managers[0].getCache(cacheName);
      keySource.populateCache((key, value) -> embeddedCache.put(key, value.getBytes()));
   }

   @TearDown
   public void tearDown() {
      for (int i = 0; i < clusterSize; i++) {
         clients[i].shutdown();
      }
      for (int i = 0; i < clusterSize; i++) {
         servers[i].stop();
         managers[i].stop();
      }
   }

   public MemcachedClient getCache(long threadId) {
      return clients[(int) (threadId % clusterSize)];
   }
}
