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

proc lab_read_binary_file {filename} {
    set channel [open $filename rb]
    fconfigure $channel -translation binary -encoding binary
    set contents [read $channel]
    close $channel
    return $contents
}

proc lab_coe_words {filename} {
    set contents [lab_read_binary_file $filename]
    if {![regexp -nocase {memory_initialization_radix\s*=\s*([0-9]+)\s*;} \
        $contents -> radix] || $radix ni {2 10 16}} {
        error "Invalid COE radix in $filename"
    }
    if {![regexp -nocase {memory_initialization_vector\s*=\s*(.*)} $contents -> vector]} {
        error "Missing COE initialization vector in $filename"
    }
    set words {}
    foreach token [regexp -all -inline {[^,;\s]+} $vector] {
        switch $radix {
            16 {
                if {![regexp {^[0-9a-fA-F]{1,8}$} $token]} { error "Invalid 32-bit COE hex token: $token" }
                # scan %x can return a signed 32-bit value on Windows Tcl.
                set value [expr "0x$token"]
            }
            2 {
                if {![regexp {^[01]{1,32}$} $token]} { error "Invalid 32-bit COE binary token: $token" }
                set value [expr "0b$token"]
            }
            10 {
                if {![regexp {^[0-9]{1,10}$} $token]} { error "Invalid 32-bit COE decimal token: $token" }
                set decimal [string trimleft $token 0]
                if {$decimal eq ""} { set decimal 0 }
                set value [expr $decimal]
            }
        }
        if {$value < 0 || $value > 0xffffffff} { error "COE value exceeds 32 bits: $token" }
        lappend words [format %08x $value]
    }
    if {[llength $words] == 0} { error "Empty COE initialization vector in $filename" }
    return $words
}

proc lab_mif_matches_coe {mif_file coe_file} {
    if {![file exists $mif_file]} { return 0 }
    set expected [lab_coe_words $coe_file]
    set actual [regexp -all -inline {\S+} [lab_read_binary_file $mif_file]]
    if {[llength $expected] != [llength $actual]} { return 0 }
    foreach bits $actual hex $expected {
        if {![regexp {^[01]{32}$} $bits]} { return 0 }
        if {[format %08x [expr "0b$bits"]] ne $hex} { return 0 }
    }
    return 1
}

proc lab_snapshot_ram_image {ip_name coe_file ip_dir} {
    set mif_file [file join $ip_dir $ip_name.mif]
    if {![lab_mif_matches_coe $mif_file $coe_file]} {
        error "Generated RAM MIF does not match selected COE: $mif_file"
    }
    file copy -force $coe_file [file join $ip_dir init_snapshot.coe]
    puts "RAM_IMAGE_SNAPSHOT_READY: $ip_name"
}

proc lab_check_pulse_width {report_file} {
    set global_table 0
    foreach line [split [lab_read_binary_file $report_file] "\n"] {
        if {[regexp {^\s*WNS\(ns\).*WPWS\(ns\)} $line]} { set global_table 1; continue }
        if {!$global_table} { continue }
        set columns [regexp -all -inline {\S+} $line]
        if {[llength $columns] != 12} { continue }
        set numeric 1
        foreach column $columns {
            if {![string is double -strict $column]} { set numeric 0; break }
        }
        if {!$numeric} { continue }
        set wpws [lindex $columns 8]
        set failures [lindex $columns 10]
        if {$wpws < 0 || $failures != 0} {
            error "Pulse-width timing failed: WPWS=$wpws ns, failing endpoints=$failures"
        }
        puts "PULSE_WIDTH_READY: WPWS=$wpws ns, failing endpoints=$failures"
        return
    }
    error "No complete 12-column global timing summary in $report_file"
}

proc lab_check_drc {} {
    set violations [get_drc_violations -quiet]
    if {[llength $violations]} { error "DRC violations remain: $violations" }
    puts "DRC_READY: zero violations"
}

proc lab_restore_ram_images {env_dir project_dir} {
    set any_changed 0
    foreach ip_name {inst_ram data_ram} {
        set ip [get_ips -quiet $ip_name]
        if {[llength $ip] != 1} { error "Expected exactly one RAM IP named $ip_name" }
        set expected [file join $env_dir func obj $ip_name.coe]
        if {![file exists $expected]} { error "Missing selected RAM image: $expected" }
        set ip_dir [file join $project_dir ip $ip_name]
        set configured [lab_resolve_ip_coe $ip $ip_dir]
        set enabled [get_property CONFIG.Load_Init_File $ip]
        set changed 0
        # CONFIG.Coe_File is relative to its XCI directory, not the process CWD.
        # Normalize only for comparison; preserve the ASCII alias for file I/O.
        if {![string is boolean -strict $enabled] || !$enabled ||
            [file normalize $configured] ne [file normalize $expected]} {
            puts "Repairing RAM initialization configuration: $ip_name"
            set_property -dict [list CONFIG.Load_Init_File true CONFIG.Coe_File $expected] $ip
            set changed 1
        }
        lab_check_ram_ip $ip $ip_dir
        set snapshot [file join $ip_dir init_snapshot.coe]
        if {[file exists $snapshot]} {
            if {[lab_read_binary_file $snapshot] ne [lab_read_binary_file $expected] ||
                ![file exists [file join $ip_dir $ip_name.mif]]} {
                set changed 1
            }
        } elseif {!$changed && [lab_mif_matches_coe [file join $ip_dir $ip_name.mif] $expected]} {
            # Older generated projects have no snapshot. Seed it only after
            # proving every generated 32-bit MIF word equals the current COE.
            file copy $expected $snapshot
            puts "Seeded verified existing RAM image snapshot: $ip_name"
        } else {
            set changed 1
        }
        if {$changed} {
            puts "RAM contents/configuration changed; regenerating only $ip_name"
            lab_remove_missing_coe
            lab_regenerate_changed_ip $ip
            lab_snapshot_ram_image $ip_name $expected $ip_dir
            set any_changed 1
        }
    }
    lab_remove_missing_coe
    return $any_changed
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
