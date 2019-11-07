#!/bin/bash

# The functions is_root, has_sudo and elevate_cmd was taken from https://bit.ly/2H42ppN
# These functions are use to elevate a regular using either sudo or the root user password
function is_root () {
    return $(id -u)
}


function display_help() {
    setup_required_paths
    SCRIPT="$0"
    cat < "${project_dir}/docs/qubinode-install.adoc"
}

# generic user choice menu
# this should eventually be used anywhere we need
# to provide user with choice
function createmenu () {
    select selected_option; do # in "$@" is the default
        if [ "$REPLY" -eq "$REPLY" 2>/dev/null ]
        then
            if [ 1 -le "$REPLY" ] && [ "$REPLY" -le $(($#)) ]; then
                break;
            else
                echo "Please make a vaild selection (1-$#)."
            fi
         else
            echo "Please make a vaild selection (1-$#)."
         fi
    done
}

# validates that the argument options are valid
# e.g. if script -s-p pass, it won't use '-' as
# an argument for -s
function check_args () {
    if [[ $OPTARG =~ ^-[p/c/h/d/a/v/m]$ ]]
    then
      echo "Invalid option argument $OPTARG, check that each argument has a value." >&2
      exit 1
    fi
}

# this configs prints out asterisks when sensitive data
# is being entered
function read_sensitive_data () {
    # based on shorturl.at/BEHY3
    sensitive_data=''
    while IFS= read -r -s -n1 char; do
      [[ -z $char ]] && { printf '\n'; break; } # ENTER pressed; output \n and break.
      if [[ $char == $'\x7f' ]]; then # backspace was pressed
          # Remove last char from output variable.
          [[ -n $sensitive_data ]] && sensitive_data=${sensitive_data%?}
          # Erase '*' to the left.
          printf '\b \b'
      else
        # Add typed char to output variable.
        sensitive_data+=$char
        # Print '*' in its stead.
        printf '*'
      fi
    done
}

function check_for_dns () {
    record=$1
    if [ -f /usr/bin/dig ]
    then
        resolvedIP=$(nslookup "$record" | awk -F':' '/^Address: / { matched = 1 } matched { print $2}' | xargs)
    elif [ -f /usr/bin/nslookup ]
    then
        resolvedIP=$(dig +short "$record")
    else
        echo "Can't find the dig or nslookup command, please resolved and run script again"
        exit 1
    fi

    if [ "A${resolvedIP}" == "A" ]
    then
        echo "DNS resolution for $record failed!"
        echo "Please ensure you have access to the internet or /etc/resolv.conf has the correct entries"
        exit 1
    fi
}

# check if a given or given files exist
function does_file_exist () {
    exist=()
    for f in $(echo "$@")
    do
        if [ -f $f ]
        then
            exist=("${exist[@]}" "$f")
        fi
    done

    if [ ${#exist[@]} -ne 0 ]
    then
        echo "yes"
    else
        echo "no"
    fi
}

function check_for_hash () {
    if [ -n $string ] && [ `expr "$string" : '[0-9a-fA-F]\{32\}\|[0-9a-fA-F]\{40\}'` -eq ${#string} ]
    then
        echo "valid"
    else
        echo "invalid"
    fi
}

function setup_user_ssh_key () {
    HOMEDIR=$(eval echo ~${CURRENT_USER})
    if [ ! -f "${HOMEDIR}/.ssh/id_rsa.pub" ]
    then
        echo "Setting up ssh keys for ${CURRENT_USER}"
        ssh-keygen -f "${HOMEDIR}/.ssh/id_rsa" -q -N ''
    fi
}

function confirm () {
    continue=""
    while [[ "${continue}" != "yes" ]];
    do
        read -r -p "${1:-Are you sure Yes or no?} " response
        if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]
        then
            response="yes"
            continue="yes"
        elif [[ $response =~ ^([nN][oO])$ ]]
        then
            echo "You choose $response"
            response="no"
            continue="yes"
        else
            echo "Try again"
        fi
    done
}

function verbose() {
    if [[ $_V -eq 1 ]]; then
        "$@"
    else
        "$@" >/dev/null 2>&1
    fi
}

function contains_string () {
    [[ $1 =~ (^|[[:space:]])$2($|[[:space:]]) ]] && echo "$2" || echo 'invalid'
    #echo "${1}" | grep -w "${2}" && echo "$2" || echo 'invalid'
}

function isRPMinstalled() {
    if rpm -q $1 &> /dev/null; then
        return 0
    else
        return 1
    fi
}

