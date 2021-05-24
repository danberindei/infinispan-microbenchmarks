## JDG 7.1.x
#### no touch
23971.674 ± 1362.793  ops/s

## Infinispan 9.4.x
#### sync touch
21156.635 ± 1034.944  ops/s
ap 17605.723 ± 1145.777  ops/s

## Infinispan 9.4.x - async touch branch
#### sync touch
19869.555 ± 910.936  ops/s
ap 18878.774 ± 953.301  ops/s

#### async touch

#### async touch + netty thread
23729.706 ± 763.470  ops/s
ap 21865.417 ± 633.486  ops/s

#### async touch + netty thread + transfer queue

#### async touch + netty thread + micro-optimizations
23827.117 ± 388.644  ops/s
ap 22461.559 ± 1223.035  ops/s

## Infinispan 11.0.x
#### sync touch
25449.763 ± 915.374  ops/s
ap 24173.784 ± 696.688  ops/s

## Infinispan 13.0.x - async touch branch
#### sync touch
16347.879 ± 568.467  ops/s
ap 16492.691 ± 210.344  ops/s

#### async touch (transfer queue default)
