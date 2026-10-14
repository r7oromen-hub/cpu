# Resolve paths from this file, independent of Vivado's current directory.
# The shared creator explicitly adds every stage/header and sets both tops.
set project_mode local
source [file normalize [file join [file dirname [info script]] ../../../../../scripts/create_vivado.tcl]]
