# CPU output clock for experiments 4/5. Board input stays 50 MHz remotely,
# 100 MHz locally; timer_clk remains 100 MHz. This does not relax constraints.
# Actual 50 MHz routed failures: experiment-4 WNS=-1.860 ns;
# experiment-5 WNS=-2.007 ns. Revalidate implementation at this requested clock.
set cpu_clock_mhz 25.0
