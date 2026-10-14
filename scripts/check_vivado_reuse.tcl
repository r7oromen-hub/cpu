# Read-only API/image checks while another process builds the project.
# No set_property, reset, regenerate, launch_runs, or snapshot writes here.
if {![info exists env(CPU_LAB_ROOT)]} { error "Set CPU_LAB_ROOT to the ASCII worktree alias" }
set repo_dir $env(CPU_LAB_ROOT)
source [file join $repo_dir scripts vivado_helpers.tcl]
set mode [lindex $argv 0]
if {$mode eq ""} { set mode remote }
set project_dir [file join $repo_dir build vivado-$mode]
open_project [file join $project_dir loongson.xpr]
foreach ip_name {inst_ram data_ram} {
    set ip [get_ips $ip_name]
    set ip_dir [file join $project_dir ip $ip_name]
    lab_check_ram_ip $ip $ip_dir
    set expected [file join $repo_dir cdp_ede_local-master mycpu_env func obj $ip_name.coe]
    set configured [lab_resolve_ip_coe $ip $ip_dir]
    if {[lab_read_binary_file $expected] ne [lab_read_binary_file $configured]} {
        error "RAM configuration selects another image: $ip_name"
    }
    if {![lab_mif_matches_coe [file join $ip_dir $ip_name.mif] $expected]} {
        error "Generated MIF differs from selected COE: $ip_name"
    }
    puts "RAM_REUSE_GUARD_PASS: $ip_name, existing XCI and full MIF match selected COE"
}
foreach {property expected} [lab_clock_configuration $repo_dir $mode] {
    set actual [get_property $property [get_ips clk_pll]]
    if {double($actual) != double($expected)} { error "Existing PLL $property=$actual, expected=$expected" }
}
puts "VIVADO_REUSE_API_PASS: no IP or run modified"
close_project
