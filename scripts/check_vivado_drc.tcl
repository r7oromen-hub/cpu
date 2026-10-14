# Read-only routed-design DRC API inspection; no suppression or waiver.
if {![info exists env(CPU_LAB_ROOT)]} { error "Set CPU_LAB_ROOT to the ASCII worktree alias" }
set repo_dir $env(CPU_LAB_ROOT)
source [file join $repo_dir scripts vivado_helpers.tcl]
set project_dir [file join $repo_dir build vivado-remote]
open_project [file join $project_dir loongson.xpr]
open_run impl_1
report_drc
foreach violation [get_drc_violations -quiet] {
    puts "DRC_API_OBJECT: $violation"
    report_property $violation
}
lab_check_drc
puts "VIVADO_DRC_API_PASS: actual CHECK/SEVERITY inspected; no severity or waiver changed"
close_project
