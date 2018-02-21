#!/bin/bash
# ----------------------------------------------------------------------
# getFibonatiNumber.sh[フィボナッチ数列値取得]
#
# param1: 数値
# return: フィボナッチ数列値
# ----------------------------------------------------------------------
function getFibonatiNumber() {
    local START_FIBONATI_NUMBER=0
    local ADD_FIBONATI_NUMBER=1

    expr $1 + 1 > /dev/null 2>&1
    if [ ! $? -ne 2 ]; then
        echo "数値を指定してください。"
        exit 1
    elif [ $1 -le 0 ]; then
        echo "[$START_FIBONATI_NUMBER]以上を指定してください。"
        exit 1
    fi

    case $1 in
        1 )
            echo $START_FIBONATI_NUMBER ;;
        2 )
            echo $ADD_FIBONATI_NUMBER ;;
        * )
            echo $(($(getFibonatiNumber $(($1 - 2))) + $(getFibonatiNumber $(($1 - 1))))) ;;
    esac

    return 0
}

getFibonatiNumber $1
