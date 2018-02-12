#!/bin/bash
# ----------------------------------------------------------------------
# mysqlActionTool-function.sh[MySQLアクションツール用関数]
#
# ----------------------------------------------------------------------
# 関数名: 使い方表示関数
function showUsage() {
    echo "Usage: $0 OPTION COMMAND"
    echo ""
    echo "Options:"
    echo "  -h, --host string    実行ホスト名"
    echo "  -u, --user string    実行ユーザ名"
    echo "  -p, --pass string    実行ユーザパスワード"
    echo "  -o, --output string  バックアップ格納先"
    echo "      --help           使い方表示"
    echo ""
    echo "Commands:"
    echo "  backup param1        バックアップ実行, param1: データベース名※allも指定可"
    echo "  restore              リストア実行"
}

# 関数名: データベースバックアップ関数
# 対応バージョン: 
#   MySQL: ~> 5.5.x, >= 5.7.12
#   MariaDB: >= 10.0.6
function backupDatabase() {
    # バックアップ対象外
    exclude_list=("information_schema" "mysql" "performance_schema" "sys")
    # バックアップ格納先作成
    backup_dir=$backup_dir/$(date +%Y%m%d%H%M%S)
    if [ ! -e $backup_dir ]; then
        mkdir -p $backup_dir
    fi
    # データベース名取得
    db_list=$(mysql ${db_host:+-h$db_host} ${db_user:+-u$db_user} ${db_pass:+-p$db_pass} \
              -N -s -e "SHOW DATABASES")
    backup="$IFS"
    IFS=$'\n', eval 'db_list=($db_list)'
    IFS=$backup
    if [ "$db_name" != "all" ]; then
        EXIST_FLG=0
        for ((i = 0; i < ${#db_list[@]}; i++)) {
            if [ "${db_list[i]}" = "$db_name" ]; then
                EXIST_FLG=1
            fi
        }
        if [ $EXIST_FLG -eq 1 ]; then
            db_list=("$db_name")
        else
            echo "Not exist database: $db_name" >&2
            return 1
        fi
    fi
    # バックアップ(テーブル定義+データ)
    for ((i = 0; i < ${#db_list[@]}; i++)) {
        # データベース存在確認:
        #   バックアップ対象外の場合 => スキップ
        if [ "$db_name" = "all" ]; then
            for ((j = 0; j < ${#exclude_list[@]}; j++)) {
                if [ "${db_list[i]}" = "${exclude_list[j]}" ]; then
                    continue
                fi
            }
        fi
        # InnoDBテーブル以外のテーブル名取得
        tbl_list=$(mysql ${db_host:+-h$db_host} ${db_user:+-u$db_user} ${db_pass:+-p$db_pass} \
                   -N -s -e "SELECT table_name
                             FROM information_schema.TABLES
                             WHERE TABLE_SCHEMA = '${db_list[i]}' AND engine NOT IN('InnoDB')")
        # InnoDBテーブルしかないデータベースダンプ
        if [ -z "$tbl_list" ]; then
            mysqldump ${db_host:+-h$db_host} ${db_user:+-u$db_user} ${db_pass:+-p$db_pass} ${db_list[i]} \
            --single-transaction \
            --default-character-set=binary \
            > $backup_dir/${db_list[i]}.sql
        # MyISAMテーブルを含むデータベースダンプ
        else
            mysqldump ${db_host:+-h$db_host} ${db_user:+-u$db_user} ${db_pass:+-p$db_pass} ${db_list[i]} \
            --lock-tables \
            --default-character-set=binary \
            > $backup_dir/${db_list[i]}.sql
        fi
        # ダンプファイル文字コードチェック
        if [ $? = 0 ]; then
            # ファイルの文字コード
            # 変換:
            #   ****** => utf8
            encode=$(file -i $backup_dir/${db_list[i]}.sql | awk '{print $3}' | sed 's/charset=//g')
            if [ "$endode" != "uft8" ]; then
                iconv -f $encode -t utf8 $backup_dir/${db_list[i]}.sql -o $backup_dir/${db_list[i]}.sql
            fi
            # ダンプ時の文字コード
            # 変換:
            #   binary => utf8
            cnt=$(cat $backup_dir/${db_list[i]}.sql | grep "SET NAMES binary" | wc -l)
            if [ $cnt -ge 1 ]; then
                sed -i -e 's/SET NAMES binary/SET NAMES utf8/g' \
                $backup_dir/${db_list[i]}.sql
            fi
        fi
        # ダンプファイル構文チェック
        if [ $? = 0 ]; then
            # MySQL5.6以降に追加されたテーブル定義
            # 変換:
            #   STATS_PERSISTENT=0 => blank
            cnt=$(cat $backup_dir/${db_list[i]}.sql | grep "STATS_PERSISTENT=0" | wc -l)
            if [ $cnt -ge 1 ]; then
                sed -i -e 's/STATS_PERSISTENT=0//g' \
                $backup_dir/${db_list[i]}.sql
            fi
        fi
        # ダンプファイルアーカイブ
        if [ $? = 0 ]; then
            tar -zcf ${db_list[i]}.sql.tar.gz ${db_list[i]}.sql --remove-files -C $backup_dir
        fi
        if [ $? = 0 ]; then
            echo "[バックアップ]${db_list[i]}: [ OK ]"
        else
            echo "[バックアップ]${db_list[i]}: [ NG ]"
        fi
    }

    return 0
}

# 関数名: データベースリストア関数
# 対応バージョン:
#   MySQL: ~> 5.5.x, >= 5.7.12
#   MariaDB: >= 10.0.6
function restoreDatabase() {
    # リストア格納先取得
    restore_dir=$backup_dir/$(ls $backup_dir | tail -n 1)
    # データベース名取得
    db_list=$(mysql ${db_host:+-h$db_host} ${db_user:+-u$db_user} \
              -N -s -e "SHOW DATABASES")
    backup="$IFS"
    IFS=$'\n', eval 'db_list=($db_list)'
    IFS=$backup
    # リストア(テーブル定義+データ)
    file in $(find $restore_dir -name '*.sql.tar.gz' | sort -r); do
        # データベース存在確認:
        #   存在していた場合 => 削除
        for ((i = 0; i < ${#db_list[@]}; i++)) {
            if [ "${db_list[i]}" = "$(basename $file .sql.tar.gz)" ]; then
                mysql ${db_host:+-h$db_host} ${db_user:+-u$db_user} \
                -e "DROP DATABASE $(basename $file .sql.tar.gz)"
                break
            fi
        }
        # 空のデータベース作成
        mysql ${db_host:+-h$db_host} ${db_user:+-u$db_user} \
        -e "CREATE DATABASE $(basename $file .sql.tar.gz)"
        # データインポート
        tar -xf $file -O | \
        mysql ${db_host:+-h$db_host} ${db_user:+-u$db_user} $(basename $file .sql.tar.gz)
        if [ $? = 0 ]; then
            echo "[リストア]$(basename $file .sql.tar.gz): [ OK ]"
        else
            echo "[リストア]$(basename $file .sql.tar.gz): [ NG ]"
        fi
    done

    return 0
}
