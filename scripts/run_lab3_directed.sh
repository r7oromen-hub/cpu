#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cpu=cdp_ede_local-master/mycpu_env/myCPU
out=test-results/lab3-directed
mkdir -p "$out"
for mode in forward stall; do
  flags=()
  if [[ "$mode" == stall ]]; then flags+=(-DSTALL_ONLY); fi
  iverilog -g2012 -Wall "${flags[@]}" -I "$cpu" -s isa_extensions_tb \
    -o "$out/$mode.vvp" "$cpu"/*.v tests/isa_extensions_tb.v
  vvp "$out/$mode.vvp" | tee "$out/$mode.log"
done
