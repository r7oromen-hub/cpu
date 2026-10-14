# vivado -mode batch -source scripts/synth_cpu.tcl
# CPU-only synthesis; board-level timing/bitstream uses build_vivado.tcl.
if {[info exists env(CPU_LAB_ROOT)] && $env(CPU_LAB_ROOT) ne ""} {
    set repo_dir $env(CPU_LAB_ROOT)
} else {
    set repo_dir [file normalize [file join [file dirname [info script]] ..]]
}
set cpu_dir [file join $repo_dir cdp_ede_local-master mycpu_env myCPU]
set out_dir [file join $repo_dir build cpu-synthesis]
file mkdir $out_dir
create_project -in_memory -part xc7a200tfbg676-1
set_property include_dirs $cpu_dir [current_fileset]
read_verilog [glob -nocomplain [file join $cpu_dir *.v]]
synth_design -top mycpu_top -part xc7a200tfbg676-1
create_clock -name cpu_clk -period 20.000 [get_ports clk]
report_utilization -file [file join $out_dir utilization.rpt]
report_timing_summary -file [file join $out_dir timing.rpt]
report_drc -file [file join $out_dir drc.rpt]
write_checkpoint -force [file join $out_dir cpu_synth.dcp]
puts "CPU_SYNTHESIS_PASS"
