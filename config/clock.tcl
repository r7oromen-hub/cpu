# CPU output clock for experiments 4/5. Board input stays 50 MHz remotely,
# 100 MHz locally; timer_clk remains 100 MHz. This does not relax constraints.
# Actual 50 MHz routed failures: experiment-4 WNS=-1.860 ns;
# experiment-5 WNS=-2.007 ns. Revalidate implementation at this requested clock.
# 实验四修改：CPU实际PLL输出由默认50 MHz改为25 MHz；板级输入和timer时钟不变。
# 50 MHz布线时WNS=-1.860 ns，故降低实际运行频率后重新实现，而非仅放宽时序约束。
set cpu_clock_mhz 25.0
