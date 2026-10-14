# vivado -mode batch -source scripts/build_vivado.tcl -tclargs local|remote [jobs]
set script_dir [file dirname [info script]]
if {[info exists env(CPU_LAB_ROOT)] && $env(CPU_LAB_ROOT) ne ""} {
    set repo_dir $env(CPU_LAB_ROOT)
} else {
    set repo_dir [file normalize [file join $script_dir ..]]
}
set project_mode [lindex $argv 0]
if {$project_mode eq ""} { set project_mode local }
if {$project_mode ni {local remote}} { error "Mode must be local or remote" }
source [file join $repo_dir scripts vivado_helpers.tcl]
set jobs [lindex $argv 1]
if {$jobs eq ""} { set jobs 4 }
set project_file [file join $repo_dir build vivado-$project_mode loongson.xpr]
if {[file exists $project_file]} {
    open_project $project_file
} else {
    source [file join $script_dir create_vivado.tcl]
}
lab_restore_ram_images [file join $repo_dir cdp_ede_local-master mycpu_env] [file dirname $project_file]
update_compile_order -fileset sources_1
# Recover failed generated projects too. Only top-level runs are reset;
# successful inst/data/PLL OOC runs retain their checkpoints.
lab_reset_failed_run impl_1
lab_reset_failed_run synth_1
if {[lab_run_needs_launch synth_1]} {
    launch_runs synth_1 -jobs $jobs
    wait_on_run synth_1
}
lab_check_run_complete synth_1
if {[lab_run_needs_launch impl_1]} {
    launch_runs impl_1 -to_step write_bitstream -jobs $jobs
    wait_on_run impl_1
}
lab_check_run_complete impl_1
open_run impl_1
set report_dir [file join $repo_dir test-results vivado-$project_mode]
file mkdir $report_dir
report_timing_summary -file [file join $report_dir timing-summary.txt]
report_utilization -file [file join $report_dir utilization.txt]
report_drc -file [file join $report_dir drc.txt]
set setup_paths [get_timing_paths -delay_type max -max_paths 1]
set hold_paths [get_timing_paths -delay_type min -max_paths 1]
if {[llength $setup_paths] == 0} { error "No constrained setup timing paths; inspect timing-summary.txt" }
if {[get_property SLACK $setup_paths] < 0} { error "Setup timing failed; inspect timing-summary.txt" }
if {[llength $hold_paths] && [get_property SLACK $hold_paths] < 0} { error "Hold timing failed; inspect timing-summary.txt" }
puts "BITSTREAM_READY: [glob -directory [get_property DIRECTORY [get_runs impl_1]] *.bit]"
