## JDG 7.1.x
#### no touch
107175.989 ± 4476.349  ops/s
ap 90183.205 ± 2458.410  ops/s
102180.782 ± 3886.030  ops/s
ap 89681.014 ± 1928.761  ops/s

## Infinispan 9.4.x
#### sync touch
49380.331 ± 4139.194  ops/s
ap 41705.525 ± 707.562  ops/s

## Infinispan 9.4.x - async touch branch
#### sync touch
48093.478 ± 4658.840  ops/s
ap 40673.680 ± 5382.388  ops/s

#### async touch
51940.215 ± 2935.579  ops/s
ap 44815.513 ± 805.511  ops/s

#### async touch + netty thread
73846.933 ± 4420.753  ops/s
ap 60274.009 ± 1394.454  ops/s

#### async touch + netty thread + transfer queue
67083.955 ± 5664.137  ops/s
ap 59401.691 ± 1229.086  ops/s

#### async touch + netty thread + micro-optimizations
70988.489 ± 3826.981  ops/s
ap 62384.943 ± 1358.447  ops/s

## Infinispan 11.0.x
#### sync touch
48564.296 ± 2960.145  ops/s
ap 37274.855 ± 1386.821  ops/s

## Infinispan 13.0.x - async touch branch
#### sync touch
41262.205 ± 288.293  ops/s
ap 37600.828 ± 539.254  ops/s

#### async touch (transfer queue default)
44699.275 ± 4031.801  ops/s
ap 37191.204 ± 1333.016  ops/s

#### async touch + explicit transfer queue
44365.720 ± 3553.552  ops/s
36147.863 ± 1242.604  ops/s
