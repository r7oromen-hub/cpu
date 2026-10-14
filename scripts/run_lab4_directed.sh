#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cpu=cdp_ede_local-master/mycpu_env/myCPU
out=test-results/lab4-directed
mkdir -p "$out"
for mode in forward stall; do
  flags=()
  if [[ "$mode" == stall ]]; then flags+=(-DSTALL_ONLY); fi
  iverilog -g2012 -Wall "${flags[@]}" -I "$cpu" -s load_store_tb \
    -o "$out/$mode.vvp" "$cpu"/*.v tests/load_store_tb.v
  vvp "$out/$mode.vvp" | tee "$out/$mode.log"
done
