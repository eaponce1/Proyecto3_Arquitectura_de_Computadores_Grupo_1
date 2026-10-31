# Read-only clock-load inventory, before considering directed insertion.
read_db $::env(STAGE12_ODB)
set block [ord::get_db_block]
set nets 0
set total_buffers 0
set worst 0
puts "net,loads,proposed_buffers_for_four_load_groups"
foreach net [$block getNets] {
    set name [$net getName]
    if {![string match "clknet_*" $name]} { continue }
    set loads 0
    foreach pin [$net getITerms] {
        if {[$pin getIoType] == "INPUT"} { incr loads }
    }
    if {$loads > $worst} { set worst $loads }
    if {$loads <= 4} { continue }
    set nb [expr {int(ceil($loads / 4.0))}]
    puts "$name,$loads,$nb"
    incr nets
    incr total_buffers $nb
}
puts "STAGE12_CLOCK_PLAN nets=$nets buffers=$total_buffers maximum_original_loads=$worst"
exit

