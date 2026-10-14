#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cpu=cdp_ede_local-master/mycpu_env/myCPU
out=test-results/lab5-directed
mkdir -p "$out"
iverilog -g2012 -Wall -s divider_tb -o "$out/divider.vvp" \
  "$cpu/iterative_divider.v" tests/divider_tb.v
vvp "$out/divider.vvp" | tee "$out/divider.log"
# Pipeline tests are enabled after integrating the experiment-4 instruction set.
if [[ -f tests/muldiv_pipeline_tb.v ]]; then
  for mode in forward stall; do
    flags=()
    if [[ "$mode" == stall ]]; then flags+=(-DSTALL_ONLY); fi
    iverilog -g2012 -Wall "${flags[@]}" -I "$cpu" -s muldiv_pipeline_tb \
      -o "$out/$mode.vvp" "$cpu"/*.v tests/muldiv_pipeline_tb.v
    vvp "$out/$mode.vvp" | tee "$out/$mode.log"
  done
  iverilog -g2012 -Wall -I "$cpu" -s muldiv_exe_hold_tb \
    -o "$out/exe-hold.vvp" "$cpu"/*.v tests/muldiv_exe_hold_tb.v
  vvp "$out/exe-hold.vvp" | tee "$out/exe-hold.log"
fi
