package org.infinispan.microbenchmarks.remote;

import org.infinispan.client.hotrod.RemoteCache;
import org.infinispan.client.hotrod.RemoteCacheManager;
import org.infinispan.client.hotrod.configuration.Configuration;
import org.infinispan.client.hotrod.configuration.ConfigurationBuilder;
//import org.infinispan.commons.marshall.IdentityMarshaller;
import org.infinispan.configuration.internal.PrivateGlobalConfigurationBuilder;
import org.infinispan.configuration.parsing.ConfigurationBuilderHolder;
import org.infinispan.configuration.parsing.ParserRegistry;
import org.infinispan.manager.DefaultCacheManager;
import org.infinispan.remoting.transport.jgroups.JGroupsTransport;
import org.infinispan.server.hotrod.HotRodServer;
import org.infinispan.server.hotrod.configuration.HotRodServerConfiguration;
import org.infinispan.server.hotrod.configuration.HotRodServerConfigurationBuilder;
import org.infinispan.util.logging.Log;
import org.infinispan.util.logging.LogFactory;
import org.openjdk.jmh.annotations.*;

import java.io.IOException;

@State(Scope.Benchmark)
public class HotRodCacheState {
   private static final Log log = LogFactory.getLog(HotRodCacheState.class);

   @Param("4")
   int clusterSize;
   @Param("missing")
   private String jgroupsConfig;
   @Param("missing")
   private String infinispanConfig;
   private String replCacheName = "repl-sync";
   private String distCacheName = "dist-sync";
   private String host = "127.0.0.1";
   private int basePort = 11100;

   DefaultCacheManager[] managers;
   HotRodServer[] servers;
   RemoteCacheManager[] remoteManagers;
   RemoteCache[] replCaches;
   RemoteCache[] distCaches;

   @Setup
   public void setup(KeySource keySource) throws IOException {
      System.setProperty("jgroups.stack.file", jgroupsConfig);
      Thread.setDefaultUncaughtExceptionHandler((t, e) -> {
         log.fatalf(e, "(%s:) Unhandled exception", t);
      });
      managers = new DefaultCacheManager[clusterSize];
      servers = new HotRodServer[clusterSize];
      for (int i = 0; i < clusterSize; i++) {
         ConfigurationBuilderHolder embeddedConfiguration = new ParserRegistry().parseFile(infinispanConfig);
         embeddedConfiguration.getGlobalConfigurationBuilder().addModule(PrivateGlobalConfigurationBuilder.class).serverMode(true);
         embeddedConfiguration.getGlobalConfigurationBuilder().transport().nodeName("Node" + (char) ('A' + i))
               .addProperty(JGroupsTransport.CONFIGURATION_FILE, jgroupsConfig);
         managers[i] = new DefaultCacheManager(embeddedConfiguration, true);
         servers[i] = new HotRodServer();
         host = "127.0.0.1";
         HotRodServerConfiguration serverConfiguration =
               new HotRodServerConfigurationBuilder().host(host).port(basePort + i).build();
         servers[i].start(serverConfiguration, managers[i]);
      }

      remoteManagers = new RemoteCacheManager[clusterSize];
      replCaches = new RemoteCache[clusterSize];
      distCaches = new RemoteCache[clusterSize];
      for (int i = 0; i < clusterSize; i++) {
         Configuration remoteConfiguration = new ConfigurationBuilder()
                 .addServer().host(host).port(basePort + 1)
//                 .marshaller(IdentityMarshaller.class)
                 .build();
         remoteManagers[i] = new RemoteCacheManager(remoteConfiguration);
         replCaches[i] = remoteManagers[i].getCache(replCacheName);
         distCaches[i] = remoteManagers[i].getCache(distCacheName);
      }

//      System.out.println("Running with Infinispan " + Version.getVersion() + ", " + org.jgroups.Version
// .printDescription());
      System.out.println("Running with " + org.jgroups.Version.printDescription());
      log.infof("Started repl cache with CH %s",
            managers[0].getCache(replCacheName).getAdvancedCache().getDistributionManager()
                  .getWriteConsistentHash());
      log.infof("Started dist cache with CH %s",
            managers[0].getCache(replCacheName).getAdvancedCache().getDistributionManager()
                  .getWriteConsistentHash());
      keySource.populateCache((key, value) -> replCaches[0].put(key, value));
      keySource.populateCache((key, value) -> distCaches[0].put(key, value));
   }

   @TearDown
   public void tearDown() {
      for (int i = 0; i < clusterSize; i++) {
         if (remoteManagers[i] != null) {
            remoteManagers[i].stop();
         }
      }
      for (int i = 0; i < clusterSize; i++) {
         if (servers[i] != null) {
            servers[i].stop();
         }
         if (managers[i] != null) {
            managers[i].stop();
         }
      }
   }

   public RemoteCache getReplCache(long threadId) {
      return replCaches[(int) (threadId % clusterSize)];
   }

   public RemoteCache getDistCache(long threadId) {
      return distCaches[(int) (threadId % clusterSize)];
   }
}
