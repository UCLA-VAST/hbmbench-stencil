#!/bin/bash
set -ex
function usage() {
  echo "usage: $0 <u50|u280> <channel count> <1|2|3>" >&2
  exit 1
}
case $1 in
  u50)
    platform=xilinx_u50_gen3x16_xdma_201920_3
    ;;
  u280)
    platform=xilinx_u280_xdma_201920_3
    ;;
  *)
    usage
    ;;
esac

channel_count="$2"
if ! test "${channel_count}" -le 32; then
  echo "too many channels" >&2
  exit 2
fi
if ! test "${channel_count}" -ge 14; then
  echo "too few channels" >&2
  exit 3
fi

case $3 in
  1)
    # case 1:
    #   each channel connects to 1 input port or 1 output port
    #   each port is k-element wide
    burst_width=512
    # 512 bits / 16 bits * # channels
    unroll_factor=$((burst_width / 16 * channel_count / 2))
    dram_in="$(seq -s . 0 $((channel_count / 2 - 1)))"
    dram_out="$(seq -s . $((channel_count / 2)) $((channel_count - 1)))"
    ;;
  2)
    # case 2:
    #   each channel connects to 1 input port and 1 output port
    #   each port is k/2-element wide
    burst_width=256
    # 256 bits / 16 bits * # channels
    unroll_factor=$((burst_width / 16 * channel_count))
    dram_in="$(seq -s . 0 $((channel_count - 1)))"
    dram_out="$(seq -s . 0 $((channel_count - 1)))"
    ;;
  3)
    # case 3:
    #   each channel connects to 2 input ports or 2 output port
    #   each port is k/2-element wide
    burst_width=256
    # = 256 bits / 16 bits * # channels
    unroll_factor=$((burst_width / 16 * channel_count))
    dram_in="$(for i in $(seq 0 $((channel_count / 2 - 1))); do echo -n "$i.$((i+32))."; done)"
    dram_out="$(for i in $(seq $((channel_count / 2)) $((channel_count - 1))); do echo -n "$i.$((i+32))."; done)"
    dram_in="${dram_in::-1}"
    dram_out="${dram_out::-1}"
    ;;
  *)
    usage
    ;;
esac

base_dir="$(pwd)"
tmp_dir="${base_dir}/tmp/${platform}.${channel_count}_chan.case_$3"
mkdir -p "${tmp_dir}"
host="${tmp_dir}/gaussian.frt.cpp"
exe="${tmp_dir}/gaussian.frt"
kernel="${tmp_dir}/gaussian.cpp"
config="${tmp_dir}/gaussian.ini"
object="${tmp_dir}/gaussian.xo"
binary="${tmp_dir}/gaussian.xclbin"
test -f "${host}" && test -f "${kernel}" ||
  sodac "${base_dir}/src/gaussian.soda" \
    --burst-width="${burst_width}" \
    --unroll-factor="${unroll_factor}" \
    --dram-in="${dram_in}" \
    --dram-out="${dram_out}" \
    --frt-host="${host}" \
    --xocl-kernel="${kernel}"
test -x "${exe}" ||
  g++ "${host}" \
    -DSODA_TEST_MAIN -O3 \
    "-I${XILINX_VIVADO}/include" \
    -l:libfrt.a -l:libtinyxml.a -lOpenCL \
    -o "${exe}"
if ! test -f "${config}"; then
  cat >"${config}" <<EOF
[advanced]
prop=kernel.gaussian_kernel.kernel_flags=-std=c++11

[connectivity]
nk=gaussian_kernel:1:gaussian_kernel
EOF
  for i in $(sed <<<"${dram_in}" -e 's/\./\n/g' | sort -n | uniq); do
    echo "sp=gaussian_kernel.bank_${i}_input:HBM[$((i%32))]" >>"${config}"
  done
  for i in $(sed <<<"${dram_out}" -e 's/\./\n/g' | sort -n | uniq); do
    echo "sp=gaussian_kernel.bank_${i}_output:HBM[$((i%32))]" >>"${config}"
  done
fi
pushd "${tmp_dir}"
test -f "${object}" ||
  v++ "${kernel}" \
    --compile \
    --save-temps \
    --report_level 2 \
    --target hw \
    --platform "${platform}" \
    --config "${config}" \
    --kernel gaussian_kernel \
    --output "${object}"
test -f "${binary}" ||
  v++ "${object}" \
    --link \
    --save-temps \
    --report_level 2 \
    --target hw \
    --platform "${platform}" \
    --config "${config}" \
    --remote_ip_cache ~/.remote_ip_cache \
    --output "${binary}"
popd
