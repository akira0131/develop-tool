#!/bin/bash
set -e
# ----------------------------------------------------------------------
# mysqlActionTool.sh[MySQLアクションツール]
#
# param:  refarence showUsage
# return: exit code
# ----------------------------------------------------------------------
# Reqire Function
source $(cd $(dirname $0); pwd)/$(basename $0 .sh)-function.sh
# Set Args
arg_option_cnt=0
while getopts h:u:p:o:-: opt; do
    if [ $opt = "-" ]; then
        opt=$(echo $OPTARG | awk -F'=' '{print $1}')
        OPTARG=$(echo $OPTARG | awk -F'=' '{print $2}')
    fi
    case $opt in
        h | host )
            db_host=${OPTARG:-localhost}
            ;;
        u | user )
            db_user=${OPTARG:-root}
            ;;
        p | pass )
            if [ -z "$OPTARG" -a -z "$MYSQL_PWD" ]; then
                echo "Option needs arg: $opt" >&2
                exit 1
            else
                db_pass=${OPTARG:-$MYSQL_PWD}
                export MYSQL_PWD=$db_pass
            fi
            ;;
        o | output )
            backup_dir=${OPTARG:-/tmp/backup_db}
            ;;
        help )
            showUsage
            exit 0
            ;;
        * )
            if [ $opt != ? ]; then
                echo "$0: illegal option -- $opt"
            fi
            showUsage
            exit 1
            ;;
    esac
done

shift $((OPTIND - 1))

action="$1"
if [ "$action" = "backup" ]; then
    if [ -z "$2" ]; then
        echo "Command needs arg: $action" >&2
        exit 1
    else
        db_name="$2"
    fi
fi
# Run
case $action in
    backup )
        backupDatabase
        ;;
    restore )
        restoreDatabase
        ;;
    * )
        echo "Invalid arg: $action" >&2
        exit 1
        ;;
esac

exit 0
