#!/bin/bash
set -ex
board=s10mx_hbm_es
# use 32 channels
channel_count="32"
case $1 in
  1)
    # case 1:
    #   each channel connects to 1 input port or 1 output port
    #   each port is k-element wide
    burst_width=256
    unroll_factor=256   # = 256 bits / 16 bits * 16 channels
    dram_in="$(seq -s . 0 15)"
    dram_out="$(seq -s . 16 31)"
    ;;
  2)
    # case 2:
    #   each channel connects to 1 input port and 1 output port
    #   each port is k/2-element wide
    burst_width=128
    unroll_factor=256   # = 256 bits / 16 bits * 32 channels
    dram_in="$(seq -s . 0 31)"
    dram_out="$(seq -s . 0 31)"
    ;;
  3)
    # case 3:
    #   each channel connects to 2 input ports or 2 output port
    #   each port is k/2-element wide
    burst_width=128
    unroll_factor=256   # = 256 bits / 16 bits * 32 channels
    dram_in="$(seq -s . -f %.0f 0 0.4999999 15.5)"
    dram_out="$(seq -s . -f %.0f 16 0.4999999 31.5)"
    ;;
  *)
    echo "usage: $0 <1|2|3>" >&2
    exit 1
    ;;
esac

base_dir="$(pwd)"
tmp_dir="${base_dir}/tmp/${board}.${channel_count}_chan.case_$1"
mkdir -p "${tmp_dir}"
host="${tmp_dir}/gaussian.frt.cpp"
exe="${tmp_dir}/gaussian.frt"
kernel="${tmp_dir}/gaussian.cl"
binary="${tmp_dir}/gaussian.aocx"
test -f "${host}" || test -f "${kernel}" ||
  sodac "${base_dir}/src/gaussian.soda" \
    --burst-width="${burst_width}" \
    --unroll-factor="${unroll_factor}" \
    --dram-in="${dram_in}" \
    --dram-out="${dram_out}" \
    --frt-host="${host}" \
    --iocl-kernel="${kernel}"
test -x "${exe}" ||
  g++ "${host}" \
    -DSODA_TEST_MAIN -O3 \
    -fopenmp \
    "-I${XILINX_VIVADO}/include" \
    -l:libfrt.a -l:libtinyxml.a -lOpenCL \
    -o "${exe}"
test -f "${binary}" ||
  aoc "${kernel}" \
    -board="${board}" \
    "-I${INTELFPGAOCLSDKROOT}/include/kernel_headers" \
    -hyper-optimized-handshaking=off \
    -o "${binary}"
