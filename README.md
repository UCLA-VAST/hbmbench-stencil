# FPGA HBM Benchmarks - Stencil

## Target Platforms

+ Intel Stratix 10 MX
+ Xilinx Alveo U50, U280

## Prerequisites

+ Intel Quartus (with AOCL) 19.4
+ Xilinx Vitis (with Vivado HLS) 2019.2
+ [SODA Compiler](https://github.com/UCLA-VAST/soda)
+ [FPGA Runtime](https://github.com/UCLA-VAST/fpga-runtime)

Please refer to vendors' manual/project README for installation steps.
Our experiments are performed on Ubuntu 18.04.

## How to run

### S10

```bash
# Host executable and kernel bitstream generation.
./intel.sh 2
pushd tmp/s10mx_hbm_es.32_chan.case_2
# On-board execution.
./gaussian.frt gaussian.aocx 32768 32768
popd
```

### U50

```bash
# Host executable and kernel bitstream generation.
./xilinx.sh u50 14 2
pushd tmp/xilinx_u50_gen3x16_xdma_201920_3.14_chan.case_2
# On-board execution.
./gaussian.frt gaussian.Congestion_SpreadLogic_high.xclbin 32768 32768
popd
```

### U280

```bash
# Host executable and kernel bitstream generation.
./xilinx.sh u280 16 2
pushd tmp/xilinx_u280_xdma_201920_3.16_chan.case_2
# On-board execution.
./gaussian.frt gaussian.Congestion_SpreadLogic_high.xclbin 32768 32768
popd
```
