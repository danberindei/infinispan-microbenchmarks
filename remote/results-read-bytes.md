## JDG 7.1.x
#### no touch
106673.560 ± 4778.046  ops/s
ap 89056.503 ± 3121.847  ops/s
105122.405 ± 3200.990  ops/s
ap 88883.420 ± 3441.551  ops/s

## Infinispan 9.4.x
#### sync touch
26286.183 ± 634.888  ops/s
ap 23622.715 ± 386.442  ops/s

## Infinispan 9.4.x - async touch branch
#### sync touch
26142.822 ± 433.599  ops/s
ap 23495.271 ± 1647.606  ops/s

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

#### async touch + no passivation
43555.256 ± 976.023  ops/s
11 54175.755 ± 1359.323  ops/s
11 ap 38187.577 ± 1968.386  ops/s


## Infinispan 11.0.x
#### sync touch
31584.054 ± 2310.736  ops/s
ap 24979.793 ± 602.764  ops/s
29226.177 ± 2304.561  ops/s
ap 24812.491 ± 429.841  ops/s
46649.533 ± 3886.732  ops/s
ap 39514.864 ± 787.474  ops/s

#### async touch
34534.951 ± 3371.033  ops/s
ap 28635.806 ± 1082.574  ops/s
11 46747.591 ± 432.412  ops/s
11 ap 40544.412 ± 367.085  ops/s

#### async touch + no passivation
45507.973 ± 5101.446  ops/s
11 54226.313 ± 2461.975  ops/s
11 ap 35439.481 ± 2146.684  ops/s

#### async touch + no passivation + micro-optimizations (DevAsyncTouch2)
47331.081 ± 3984.030  ops/s
ap 39834.361 ± 499.564  ops/s

#### async touch + no passivation + micro-optimizations (DevAsyncTouch3)
51456.829 ± 3906.190  ops/s
ap 39768.617 ± 916.977  ops/s

#### async touch + micro-optimizations + NBS (DevAsyncTouch3)
53724.055 ± 1207.247  ops/s
ap 37738.265 ± 793.968  ops/s
11 49199.629 ± 1920.770  ops/s
11 ap 35911.246 ± 3688.665  ops/s
11 47952.881 ± 2805.064  ops/s
11 ap 36378.001 ± 660.559  ops/s

#### async touch + micro-optimizations + sync load (DevAsyncTouch4)
11 51631.887 ± 622.188  ops/s
11 ap 49815.160 ± 817.279  ops/s
50116.821 ± 4512.418  ops/s
ap 32466.987 ± 1657.081  ops/s

#### async touch + micro-optimizations + sync load + sync delete (DevAsyncTouch5)
11 45205.439 ± 2923.692  ops/s
11 ap 48593.811 ± 1225.940  ops/s
11 50374.049 ± 1929.693  ops/s
11 ap alloc 50613.219 ± 939.294  ops/s

## Infinispan 13.0.x - async touch branch
#### sync touch

#### async touch (transfer queue default)
42419.528 ± 332.612  ops/s
ap 38709.498 ± 699.361  ops/s

#### async touch + no passivation
46992.470 ± 3709.855  ops/s
11 51426.030 ± 1719.449  ops/s
11 ap 38091.549 ± 1324.226  ops/s
