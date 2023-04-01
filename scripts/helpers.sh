#!/bin/bash

loading() {
    CHARS="/-\|"

    if [[ $# -eq 0 ]]; then
        ITER=1
    else
        ITER=$1
    fi

    for (( a=0; a<${ITER}; a++ )); do
        for (( b=0; b<${#CHARS}; b++ )); do
            sleep 0.5
            echo -en "${CHARS:$b:1}" "\r"
        done
    done
}