## JDG 7.1.x
#### no touch
106673.560 ± 4778.046  ops/s
ap 89056.503 ± 3121.847  ops/s
105122.405 ± 3200.990  ops/s
ap 88883.420 ± 3441.551  ops/s

## Infinispan 9.4.x
#### sync touch

## Infinispan 9.4.x - async touch branch
#### sync touch

#### async touch
39930.500 ± 2219.054  ops/s
ap 34021.164 ± 541.032  ops/s

#### async touch + netty thread
49356.579 ± 2873.035  ops/s
ap 42919.061 ± 820.391  ops/s

#### async touch + netty thread + transfer queue

#### async touch + netty thread + micro-optimizations
50948.988 ± 2883.762  ops/s
at 40115.727 ± 1000.080  ops/s

## Infinispan 11.0.x
#### sync touch

## Infinispan 13.0.x - async touch branch
#### sync touch

#### async touch (transfer queue default)
42419.528 ± 332.612  ops/s
ap 38709.498 ± 699.361  ops/s
