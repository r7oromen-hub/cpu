#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cpu=cdp_ede_local-master/mycpu_env/myCPU
out=test-results/lab2-directed
mkdir -p "$out"
for mode in forward stall; do
  flags=()
  if [[ "$mode" == stall ]]; then flags+=(-DSTALL_ONLY); fi
  iverilog -g2012 -Wall "${flags[@]}" -I "$cpu" -s lab2_hazards_tb \
    -o "$out/$mode.vvp" "$cpu"/*.v tests/lab2_hazards_tb.v
  vvp "$out/$mode.vvp" | tee "$out/$mode.log"
done
iverilog -g2012 -Wall -s base_ram_tb -o "$out/base_ram.vvp" \
  "$cpu/BaseRAM_control.v" tests/base_ram_tb.v
vvp "$out/base_ram.vvp" | tee "$out/base_ram.log"
