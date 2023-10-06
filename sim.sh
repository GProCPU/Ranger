#!/bin/bash

PROJ_DIR="$(dirname -- "$(readlink -f "${BASH_SOURCE}")")"

RTL_SRC_DIR="${PROJ_DIR}/rtl"
INC_DIR="${PROJ_DIR}/rtl"
TB_DIR="${PROJ_DIR}/testbench"

XVLOG_OPTS="-sv -i ${INC_DIR}"
XELAB_OPTS="-debug typical"
XSIM_OPTS=""


# Include common functions and definitions such as OUT_FILTER and special_exec()
source "${PROJ_DIR}/scripts/utils.sh"


function usage {
    cat <<USAGE_EOF

usage: $SCRIPT_NAME [option]... <module>...

    <module>        Name of module test

    -a, --all       Run tests for all modules
        --check     Compile and elaborate only (no sim)
    -h, --help      Prints this usage message

USAGE_EOF
}


# Check for empty arguments
if  [ $# -eq 0 ]; then
    >&2 echo "No arguments provided"
    usage
    exit 1
fi


function sim() {
    if [ $# -eq 0 ]; then
        >&2 echo "Function sim called with no module argument"
        exit 2
    fi
    module=$(echo "$1" | sed -E 's/.*\///')
    module_path="$1"
    module_prefix=$(echo "$1" | sed -E 's/\/?[^\/]*$//')
    source="${RTL_SRC_DIR}/${module_path}.sv"
    testbench="${TB_DIR}/${module_path}_TB.sv"
    echo "$module_path"
    echo "    $source"
    echo "    $testbench"
    if [ $# -eq 1 ]; then
        check_only=false
    else
        check_only=$2
    fi
    mkdir -p "build/sim/$module_path"
    cd "build/sim/$module_path"

    # find dependencies
    sv_files="$source $testbench"
    parse_depends $source "$RTL_SRC_DIR"
    sv_files="$sv_files $rval"
    parse_depends $testbench "$RTL_SRC_DIR"
    sv_files="$sv_files $rval"
    #sv_files="$sv_files $(parse_depends $source \'$RTL_SRC_DIR\')"
    #sv_files="$sv_files $(parse_depends $testbench \'$RTL_SRC_DIR\')"
    echo

    # execute macro commands
    exec_macro_cmds "$source" "RANGER_SIM=1"
    exec_macro_cmds "$testbench" "RANGER_SIM=1"
    echo

    # compile
    special_exec xvlog $XVLOG_OPTS $sv_files | $OUT_FORMAT
    rval=$PIPESTATUS
    if [ "$rval" == "0" ]; then
        echo
        echo -e "${BLUE}Compile for $module_path complete${NORMAL}"
        echo
    else
        >&2 echo
        >&2 echo -e "${RED}FAIL: Compile failed for $module_path. Exit code ${rval}${NORMAL}"
        >&2 echo "Check build/sim/$module_path/xvlog.log"
        >&2 echo
        return $rval
    fi

    # elaborate
    special_exec xelab $XELAB_OPTS -s sim ${module}_TB | $OUT_FORMAT
    rval=$PIPESTATUS
    if [ "$rval" = "0" ]; then
        echo
        echo -e "${BLUE}Elaborate for $module_path complete${NORMAL}"
        echo
    else
        >&2 echo
        >&2 echo -e "${RED}FAIL: Elaborate failed for $module_path. Exit code ${rval}${NORMAL}"
        >&2 echo "Check build/sim/$module_path/xelab.log"
        >&2 echo
        return $rval
    fi

    # simulate
    if $check_only; then
        return $rval
    else
        special_exec xsim $XSIM_OPTS --runall sim | $OUT_FORMAT
        rval=$PIPESTATUS
        if [ "$rval" = "0" ]; then
            #echo -e "${BLUE}Simulate for $module complete${NORMAL}"
            echo
        else
            >&2 echo
            >&2 echo -e "${RED}FAIL: Simulate failed for $module_path. Exit code ${rval}${NORMAL}"
            >&2 echo
            return $rval
        fi
        tail -n 2 ${module}.log | grep PASS > /dev/null
        return $?
    fi
}




all=false
check_only=false
modules=()
while [[ $# -gt 0 ]]; do
   case "$1" in
        -a | --all)
            all=true
            shift
            ;;
        --check)
            check_only=true
            shift
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        -* | --*)
            >&2 echo "Unknown argument $1"
            exit 1
            ;;
        *)
            modules+=("$1")
            shift
    esac
done

if $all; then
    if [ "${#modules[@]}" -gt 0 ]; then
        >&2 echo "Module names must not be provided when using the --all option"
        exit 1
    fi
    modules=$(find $TB_DIR | grep -E '_TB\.sv$' | sed -e 's/_TB\.sv$//' | sed -e "s/${TB_DIR}\///")
fi

fail=false
summary="Simulation testing complete"
for module in $modules; do
    sim $module $check_only
    rval=$?
    if [ "$rval" != "0" ]; then
        fail=true
        echo
        >&2 echo -e "Test for module $module ${RED}FAILED${NORMAL}. Exit value $rval"
        summary="${summary}\n${module} ${RED}FAILED${NORMAL}"
    else
        summary="${summary}\n${module} ${GREEN}PASSED${NORMAL}"
    fi
    echo ""
done

if $fail; then
    echo ""
    echo -e "One or more modules ${RED}FAILED${NORMAL}"
    exit 1
else
    echo ""
    echo -e "All modules ${GREEN}PASSED${NORMAL}"
fi

