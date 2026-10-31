# One bounded clock-only topology repair, before routing.
source $::env(SCRIPTS_DIR)/openroad/common/io.tcl
read_current_odb
source $::env(SCRIPTS_DIR)/openroad/common/set_rc.tcl
set block [ord::get_db_block]
set dbu [$block getDbUnitsPerMicron]
set buffer gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
if {[$::db findMaster $buffer] == "NULL"} { error "Missing clock buffer $buffer" }

# Snapshot before any mutation; don't recursively process newly created nets.
set plan [list]
foreach net [$block getNets] {
    if {![string match "clknet_*" [$net getName]]} { continue }
    set rows [list]
    foreach pin [$net getITerms] {
        if {[$pin getIoType] != "INPUT"} { continue }
        set inst [$pin getInst]
        lassign [$inst getLocation] x y
        set pin_name "[$inst getName]/[[$pin getMTerm] getName]"
        lappend rows [list $x $y $pin_name $pin]
    }
    if {[llength $rows] <= 4} { continue }
    set rows [lsort -real -index 0 $rows]
    for {set i 0} {$i < [llength $rows]} {incr i 4} {
        lappend plan [list [$net getName] [lrange $rows $i [expr {$i + 3}]]]
    }
}
puts "STAGE12_CLOCK_SPLIT planned_buffers=[llength $plan] maximum_allowed=400 group_size=4"
if {[llength $plan] > 400} { error "Refusing unbounded clock buffer insertion" }

set number 0
foreach item $plan {
    lassign $item source_net rows
    set pins [list]
    set load_terms [list]
    set xsum 0.0
    set ysum 0.0
    foreach row $rows {
        lassign $row x y pin_name pin_obj
        lappend pins $pin_name
        lappend load_terms $pin_obj
        set xsum [expr {$xsum + $x}]
        set ysum [expr {$ysum + $y}]
    }
    set count [llength $rows]
    set position [list [expr {$xsum / $count / $dbu}] [expr {$ysum / $count / $dbu}]]
    set inst_name clkbuf_stage12_$number
    set net_name clknet_stage12_$number
    puts "STAGE12_CLOCK_INSERT source=$source_net buffer=$inst_name net=$net_name loads=$pins location=$position"
    insert_buffer -buffer_cell $buffer -load_pins $pins -location $position \
        -buffer_name $inst_name -net_name $net_name
    # OpenROAD uniquifies -net_name; inspect the reconnected ODB term instead
    # of assuming the requested base name is the final flat-net name.
    set created [[lindex $load_terms 0] getNet]
    if {$created == "NULL" || [$created getName] eq $source_net} {
        error "First load was not moved to a new net for $net_name"
    }
    foreach load_term $load_terms {
        if {[$load_term getNet] != $created} {
            error "Clock loads were not grouped on one new net for $net_name"
        }
    }
    $created setSigType CLOCK
    puts "STAGE12_CLOCK_CREATED requested=$net_name actual=[$created getName]"
    incr number
}
set_propagated_clock [all_clocks]
source $::env(SCRIPTS_DIR)/openroad/common/dpl.tcl
estimate_parasitics -placement
puts "STAGE12_CLOCK_SPLIT inserted=$number"
write_views

