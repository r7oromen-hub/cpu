# Resolve paths from this file, independent of Vivado's current directory.
# The shared creator explicitly adds every stage/header and sets both tops.
set project_mode local
if {[info exists env(CPU_LAB_ROOT)] && $env(CPU_LAB_ROOT) ne ""} {
    source [file join $env(CPU_LAB_ROOT) scripts create_vivado.tcl]
} else {
    source [file normalize [file join [file dirname [info script]] ../../../../../scripts/create_vivado.tcl]]
}
