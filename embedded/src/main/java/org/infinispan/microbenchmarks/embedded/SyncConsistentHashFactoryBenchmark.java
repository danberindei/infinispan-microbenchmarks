package org.infinispan.microbenchmarks.embedded;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.TimeUnit;

import org.infinispan.distribution.ch.ConsistentHash;
import org.infinispan.distribution.ch.impl.SyncConsistentHashFactory;
import org.infinispan.distribution.ch.impl.TopologyAwareSyncConsistentHashFactory;
import org.infinispan.remoting.transport.Address;
import org.infinispan.remoting.transport.jgroups.JGroupsAddress;
import org.infinispan.remoting.transport.jgroups.JGroupsTopologyAwareAddress;
import org.infinispan.topology.PersistentUUID;
import org.jgroups.util.ExtendedUUID;
import org.openjdk.jmh.annotations.Benchmark;
import org.openjdk.jmh.annotations.Mode;
import org.openjdk.jmh.annotations.Param;
import org.openjdk.jmh.annotations.Scope;
import org.openjdk.jmh.annotations.Setup;
import org.openjdk.jmh.annotations.State;
import org.openjdk.jmh.annotations.TearDown;
import org.openjdk.jmh.runner.Runner;
import org.openjdk.jmh.runner.options.Options;
import org.openjdk.jmh.runner.options.OptionsBuilder;

public class SyncConsistentHashFactoryBenchmark {

    private static final int MEASUREMENT_ITERATIONS_COUNT = 1;
    private static final int WARMUP_ITERATIONS_COUNT = 1;

    public void performRouterBenchmark() throws Exception {
        Options opt = new OptionsBuilder()
                .include(this.getClass().getName() + ".*")
                .mode(Mode.AverageTime)
                .mode(Mode.SingleShotTime)
                .timeUnit(TimeUnit.MILLISECONDS)
                .warmupIterations(WARMUP_ITERATIONS_COUNT)
                .measurementIterations(MEASUREMENT_ITERATIONS_COUNT)
                .threads(1)
                .forks(1)
                .shouldFailOnError(true)
                .shouldDoGC(true)
                .build();

        new Runner(opt).run();
    }

    @State(Scope.Thread)
    public static class BenchmarkState {

        @Param("500")
        int numSegments;
        @Param("2")
        int numOwners;
        @Param("100")
        int numNodes;

        private SyncConsistentHashFactory factory;
        private TopologyAwareSyncConsistentHashFactory topologyAwareFactory;
        private List<Address> nodes;
        private Map<Address, Float> capacityFactors;

        @Setup
        public void setup() throws Exception {
            factory = new SyncConsistentHashFactory();
            topologyAwareFactory = new TopologyAwareSyncConsistentHashFactory();
            nodes = new ArrayList<>(numNodes);
            capacityFactors = new HashMap<>();
            for (int i = 0; i < numNodes; i++) {
                JGroupsAddress node = new JGroupsTopologyAwareAddress(JGroupsTopologyAwareAddress.randomUUID("A" + i, null, null, "m0"));
                nodes.add(node);
                capacityFactors.put(node, 1f);
            }
        }

        @TearDown
        public void tearDown() {
        }

        @Benchmark
        public ConsistentHash createConsistentHash() {
            return factory.create(numOwners, numSegments, nodes, null);
        }

        @Benchmark
        public ConsistentHash createTopologyAwareConsistentHash() {
            return topologyAwareFactory.create(numOwners, numSegments, nodes, null);
        }
    }

}
