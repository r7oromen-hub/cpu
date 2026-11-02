# 实验四修改：CPU实际PLL输出由默认50 MHz改为25 MHz；板级输入和timer时钟不变。
# 50 MHz布线时WNS=-1.860 ns，故降低实际运行频率后重新实现，而非仅放宽时序约束。
set cpu_clock_mhz 25.0
