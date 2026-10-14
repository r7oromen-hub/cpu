# Shared Vivado project repair checks. Use project APIs, never rewrite .xpr XML.
proc lab_clock_configuration {repo_dir project_mode} {
    set cpu_clock_mhz 50.0
    set config_file [file join $repo_dir config clock.tcl]
    if {[file exists $config_file]} { source $config_file }
    if {![string is double -strict $cpu_clock_mhz] || $cpu_clock_mhz <= 0} {
        error "Invalid cpu_clock_mhz in $config_file: $cpu_clock_mhz"
    }
    set input_clock_mhz [expr {$project_mode eq "remote" ? 50.0 : 100.0}]
    return [list CONFIG.PRIM_IN_FREQ $input_clock_mhz \
        CONFIG.CLKOUT1_REQUESTED_OUT_FREQ $cpu_clock_mhz \
        CONFIG.CLKOUT2_REQUESTED_OUT_FREQ 100.0]
}

proc lab_regenerate_changed_ip {ip} {
    set run [get_runs -quiet ${ip}_synth_1]
    if {[llength $run]} {
        puts "Resetting only changed IP OOC run: $run"
        reset_run $run
    }
    reset_target all $ip
    generate_target all $ip
}

proc lab_configure_pll {repo_dir project_mode {regenerate 0}} {
    set ip [get_ips -quiet clk_pll]
    if {[llength $ip] != 1} { error "Expected exactly one clock IP named clk_pll" }
    set config [lab_clock_configuration $repo_dir $project_mode]
    set changed 0
    foreach {property expected} $config {
        set actual [get_property $property $ip]
        if {![string is double -strict $actual] || double($actual) != double($expected)} {
            set changed 1
        }
    }
    if {$changed} {
        puts "Updating PLL clock configuration: $config"
        set_property -dict $config $ip
        if {$regenerate} { lab_regenerate_changed_ip $ip }
    }
    foreach {property expected} $config {
        set actual [get_property $property $ip]
        if {![string is double -strict $actual] || double($actual) != double($expected)} {
            error "PLL did not retain $property=$expected MHz: $actual"
        }
    }
    puts "PLL_CLOCK_READY: $config"
    return $changed
}

proc lab_remove_missing_coe {} {
    set removed 0
    foreach coefficient [get_files -all -quiet *.coe] {
        set filename [get_property NAME $coefficient]
        if {![file exists $filename]} {
            puts "Removing stale missing COE registration: $filename"
            remove_files $coefficient
            incr removed
        }
    }
    return $removed
}

proc lab_resolve_ip_coe {ip ip_dir} {
    set coefficient [get_property CONFIG.Coe_File $ip]
    if {[file pathtype $coefficient] eq "relative"} {
        set coefficient [file join $ip_dir $coefficient]
    }
    return $coefficient
}

proc lab_check_ram_ip {ip ip_dir} {
    set enabled [get_property CONFIG.Load_Init_File $ip]
    set coefficient [lab_resolve_ip_coe $ip $ip_dir]
    if {![string is boolean -strict $enabled] || !$enabled} {
        error "RAM IP $ip initialization is disabled: CONFIG.Load_Init_File=$enabled"
    }
    if {![file exists $coefficient]} {
        error "RAM IP $ip has no existing COE image: $coefficient"
    }
    puts "RAM_IMAGE_READY: $ip, Load_Init_File=$enabled, Coe_File=$coefficient"
}

proc lab_restore_ram_images {env_dir project_dir} {
    foreach ip_name {inst_ram data_ram} {
        set ip [get_ips -quiet $ip_name]
        if {[llength $ip] != 1} { error "Expected exactly one RAM IP named $ip_name" }
        set expected [file join $env_dir func obj $ip_name.coe]
        if {![file exists $expected]} { error "Missing selected RAM image: $expected" }
        set ip_dir [file join $project_dir ip $ip_name]
        set configured [lab_resolve_ip_coe $ip $ip_dir]
        set enabled [get_property CONFIG.Load_Init_File $ip]
        # CONFIG.Coe_File is relative to its XCI directory, not the process CWD.
        # Normalize only for comparison; preserve the ASCII alias for file I/O.
        if {![string is boolean -strict $enabled] || !$enabled ||
            [file normalize $configured] ne [file normalize $expected]} {
            puts "Repairing RAM initialization configuration: $ip_name"
            set_property -dict [list CONFIG.Load_Init_File true CONFIG.Coe_File $expected] $ip
            lab_remove_missing_coe
            # Rebuild only this changed IP's output products. Do not reset
            # unrelated successful OOC synthesis runs or DCPs.
            generate_target all $ip
        }
        lab_check_ram_ip $ip $ip_dir
    }
    lab_remove_missing_coe
}

proc lab_reset_failed_run {name} {
    set run [get_runs $name]
    set status [get_property STATUS $run]
    if {[regexp -nocase {error|failed} $status]} {
        puts "Resetting failed $name only: $status"
        reset_run $name
    }
}

proc lab_run_needs_launch {name} {
    set run [get_runs $name]
    set status [get_property STATUS $run]
    if {[regexp -nocase {error|failed} $status]} { error "Run $name still failed: $status" }
    if {[get_property NEEDS_REFRESH $run]} {
        puts "Resetting stale $name only"
        reset_run $name
        return 1
    }
    return [expr {[get_property PROGRESS $run] ne "100%"}]
}

proc lab_check_run_complete {name} {
    set run [get_runs $name]
    set status [get_property STATUS $run]
    if {[regexp -nocase {error|failed} $status] || [get_property PROGRESS $run] ne "100%"} {
        error "Run $name did not complete successfully: $status"
    }
}
