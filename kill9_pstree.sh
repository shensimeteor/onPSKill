#!/bin/bash
#usage: kill_pstree.sh [-f] <ps_efl_grep_pattern> [<username>]

#print pstree rooted at $1, $2="-"(the indent, used for recursive call)
#also get the $tree_node_pid(global var) (all the pid in the tree)
function ls_pstree_bypid(){
    local xpid xcmd xtim xstt line 
    pid=$1
    sons="$(ps --ppid $pid |  tr -s ' ' | sed 's/^ *//g' | sed '/^PID/d' | cut -d ' ' -f 1)"
    line="$(ps -p $pid -lf | tr -s ' ' | tail -n 1)"
    xpid=$(echo $line | cut -d ' ' -f 4)
    xstt=$(echo $line | cut -d ' ' -f 2)
    xtim=$(echo $line | cut -d ' ' -f 14)
    xcmd="$(echo $line | cut -d ' ' -f 15-)"
    echo "$2 $xstt $xpid $xtim $xcmd"
    for son in $sons; do
        if [ -n "$son" ]; then
            ls_pstree_bypid $son $2"-" 
        fi
    done
    tree_node_pid="$tree_node_pid $xpid"
}

#$1: ps -elf search pattern; $2: username (if not empty)
# return: pid
function search_pself_pattern(){
    local pattern username line
    pattern=$1
    username=$2
    pid=""
    if [ -z "$username" ]; then
        pid="$(ps -elf | grep "$pattern" | grep -v grep | grep -v kill9_pstree | tr -s ' ' | sed 's/^ *//g' | cut -d ' ' -f 4 )"
    else
        pid="$(ps -lf -U $username | grep "$pattern" | grep -v grep | grep -v kill9_pstree.sh | tr -s ' ' | sed 's/^ *//g' | cut -d ' ' -f 4 2>/dev/null)"
    fi
    echo $pid
}

#main code
narg=$#
if [ $narg -eq 1  ]; then
    pattern=$1
    username=""
    prompt=1
elif [ $narg -eq 2 ] && [ "$1" == "-f" ]; then
    pattern=$2
    username=""
    prompt=0
elif [ $narg -eq 2 ]; then
    pattern=$1
    username=$2
    prompt=1
elif [ $narg -eq 3 ] && [ "$1" == "-f" ]; then
    pattern=$2
    username=$3
    prompt=0
else
    echo "<usage> $0 [-f] <ps_elf_grep_pattern> [<username>]"
    exit 2
fi
exit_code=0
#first, grep the ps
process_id="$(search_pself_pattern "$pattern" $username)"
if [ -z "$process_id" ]; then
    echo "No process found based, EXIT without killing"
    exit 
fi
if [ $prompt -eq 1 ]; then
    echo "You will kill these root process: "
    ps -lf | head -n 1
    for pid in $process_id; do
        ps -lf -p $pid | tail -n 1
    done
    echo 
    read -p "to continue view its tree (won't kill now), press Y/y, to escape press other key:  " ans
    if [ "$ans" == "Y" ] || [ "$ans" == "y" ]; then
        echo
        echo "You will kill these ps_tree: "
        pids=""
        for pid in $process_id; do
            echo "-------------------"
            tree_node_pid=""
            ls_pstree_bypid $pid
            pids="$pids $tree_node_pid"
        done
        read -p "to continue KILL these trees, press Y/y, to escape press other key:  " ans
        if [ "$ans" == "Y" ] || [ "$ans" == "y" ]; then
            for pid in $pids; do
                echo "kill $pid"
                kill -9 $pid
                ec=$?
                if [ $ec -ne 0 ]; then
                    exit_code=$ec
                fi
            done
        fi
    else
        exit
    fi
else #no prompt
    echo "You will kill these root process: "
    ps -lf | head -n 1
    for pid in $process_id; do
        ps -lf -p $pid | tail -n 1
    done
    for pid in $process_id; do
        echo "-------------------"
        tree_node_pid=""
        ls_pstree_bypid $pid
        pids="$pids $tree_node_pid"
    done
    echo "-------------------"
    for pid in $pids; do
        echo "kill $pid"
        kill -9 $pid
       ec=$?
       if [ $ec -ne 0 ]; then
           exit_code=$ec
       fi
    done
fi    
exit $ec

