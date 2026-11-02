# Vivado batch example: vivado -mode batch -source scripts/create_vivado.tcl -tclargs local
# This creates a NEW project and never silently overwrites an existing one.
if {[info exists env(CPU_LAB_ROOT)] && $env(CPU_LAB_ROOT) ne ""} {
    # Vivado 2018.3 can corrupt Chinese paths when normalizing a junction.
    # Preserve an explicitly supplied absolute ASCII worktree alias verbatim.
    set repo_dir $env(CPU_LAB_ROOT)
} else {
    set repo_dir [file normalize [file join [file dirname [info script]] ..]]
}
if {![info exists project_mode]} {
    set project_mode [lindex $argv 0]
    if {$project_mode eq ""} { set project_mode local }
}
if {$project_mode ni {local remote}} { error "Mode must be local or remote" }
source [file join $repo_dir scripts vivado_helpers.tcl]
set env_dir [file join $repo_dir cdp_ede_local-master mycpu_env]
set soc_dir [file join $env_dir soc_verify soc_bram]
set project_dir [file join $repo_dir build vivado-$project_mode]
set project_file [file join $project_dir loongson.xpr]
if {[file exists $project_file]} {
    error "Project already exists: $project_file. Reopen with open_project; do not recreate."
}
foreach image {inst_ram.coe data_ram.coe} {
    if {![file exists [file join $env_dir func obj $image]]} {
        error "Missing $image. First run scripts/run_regression.py --image exN_obj."
    }
}
create_project loongson $project_dir -part xc7a200tfbg676-1
set cpu_dir [file join $env_dir myCPU]
add_files -norecurse [glob -directory $cpu_dir *.v]
set_property file_type {Verilog Header} [get_files [file join $cpu_dir mycpu_head.v]]
set_property include_dirs [list $cpu_dir] [get_filesets sources_1]
set_property include_dirs [list $cpu_dir] [get_filesets sim_1]
add_files -norecurse [glob -directory [file join $soc_dir rtl] *.v]
foreach directory {BRIDGE CONFREG} {
    add_files -norecurse [glob -directory [file join $soc_dir rtl $directory] *.v]
}
add_files -fileset sim_1 -norecurse [glob -directory [file join $soc_dir testbench] *.v]
foreach ip_name {clk_pll inst_ram data_ram} {
    # Customize a project-local copy so local/remote PLL configurations do not
    # mutate the shared course source .xci files or another branch's project.
    set ip_dir [file join $project_dir ip $ip_name]
    file mkdir $ip_dir
    set ip_file [file join $ip_dir $ip_name.xci]
    file copy [file join $soc_dir rtl xilinx_ip $ip_name $ip_name.xci] $ip_file
    add_files -norecurse $ip_file
    set ip [get_ips $ip_name]
    if {[get_property IS_LOCKED $ip]} { upgrade_ip $ip }
    if {$ip_name eq "clk_pll"} {
        lab_configure_pll $repo_dir $project_mode
    } else {
        set_property -dict [list CONFIG.Load_Init_File true CONFIG.Coe_File \
            [file join $env_dir func obj $ip_name.coe]] $ip
        lab_check_ram_ip $ip $ip_dir
    }
    # add_files/upgrade_ip may register the old relative COE even after the IP
    # configuration points to the new image. Drop only nonexistent records.
    lab_remove_missing_coe
    generate_target all $ip
    if {$ip_name ne "clk_pll"} {
        lab_snapshot_ram_image $ip_name [file join $env_dir func obj $ip_name.coe] $ip_dir
    }
}
lab_remove_missing_coe
if {$project_mode eq "remote"} {
    add_files -norecurse [list [file join $repo_dir remote remote2local.v] \
        [file join $repo_dir remote loongson_remote_top.v]]
    add_files -fileset constrs_1 -norecurse [file join $repo_dir remote loongson_remote.xdc]
    set_property top looongson_remote_top [get_filesets sources_1]
} else {
    add_files -fileset constrs_1 -norecurse [glob -directory [file join $soc_dir run_vivado constraints] *.xdc]
    set_property top soc_lite_top [get_filesets sources_1]
}
set_property top tb_top [get_filesets sim_1]
set_property xsim.simulate.log_all_signals false [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
puts "Created $project_mode project: $project_file"
