proc usage {} {
    set SCRIPT_NAME $argv0
    puts ""
    puts "usage: $SCRIPT_NAME \[option\]... <src file(s)>..."
    puts ""
    puts "    <src file(s)>         One or more Verilog source files"
    puts ""
    puts "    -i, -include_dirs     Include directory"
    puts "    -v, -verbose          Disable message limits"
    puts "    -h, -help             Prints this usage message"
    puts ""
}

# Parse arguments
if { $argc < 1} {
    puts "ERROR: Build script requires at least 1 argument"
    usage
    exit 1
}
set ind_dir ""
lappend sv_files
for {set i 0} {$i < $argc} {incr i} {
    set option [string trim [lindex $argv $i]]
    switch -regexp -- $option {
        "(-i|--?include_dirs)"  { incr i; set inc_dir [lindex $argv $i]}
        "(-v|--?verbose)"       { set_param messaging.defaultLimit 1000 }
        "(-h|--?help)"          { usage; exit 0}
        default {
            lappend sv_files [lindex $argv $i]
        }
    }
}


# Set number of CPUs
proc numberOfCPUs {} {
    # Windows puts it in an environment variable
    global tcl_platform env
    if {$tcl_platform(platform) eq "windows"} {
        return $env(NUMBER_OF_PROCESSORS)
    }
    # Check for sysctl (OSX, BSD)
    set sysctl [auto_execok "sysctl"]
    if {[llength $sysctl]} {
        if {![catch {exec {*}$sysctl -n "hw.ncpu"} cores]} {
            return $cores
        }
    }
    # Assume Linux, which has /proc/cpuinfo, but be careful
    if {![catch {open "/proc/cpuinfo"} f]} {
        set cores [regexp -all -line {^processor\s} [read $f]]
        close $f
        if {$cores > 0} {
            return $cores
        }
    }
    # No idea what the actual number of cores is; exhausted all our options
    # Fall back to returning 4
    return 4
}
set_param general.maxThreads [numberOfCPUs]


# Load sources
read_verilog -sv $sv_files
read_xdc Basys3.xdc

# Run Synthesis
synth_design -top top -include_dirs $inc_dir -part xc7a35tcpg236-1
write_verilog -force post_synth.v

# Implement (optimize, place, route)
opt_design
place_design
phys_opt_design
#write_checkpoint -force post_place
route_design


# Generate Reports
report_timing_summary -file post_route_timing.rpt
report_utilization -file post_route_utilization.rpt
report_power -file post_route_power.rpt
report_drc -file post_imp_drc.rpt

# Make bitstream
write_bitstream -force ranger.bit
