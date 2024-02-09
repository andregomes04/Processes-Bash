#!/bin/bash

# expressões, vars e etc
reverse="-r" #se "" sorted ao contrário
sort=4 # by default é sorted pela coluna readb (4 coluna); se 7 sorted pelo número de writeb
pidlist=()
rchar_list=()
wchar_list=()
p=123456789

#1 --------------------------------------------- verificação de opções -----------------------------------------------------------
while getopts "c:s:e:u:m:M:p:rw"  OPTION; do
  case $OPTION in
    c)
        c=${OPTARG}; #regex
        ;;
    s)
        s=${OPTARG}; #data min  (se s então next tem que ser e)
        ;;
    e)
        e=${OPTARG}; #data max
        ;;
    u)
        u=${OPTARG}; #user
        ;;
    m)
        m=${OPTARG}; #min pid;
        ;;
    M)
        M=${OPTARG}; #max pid;
        ;;
    p)
        p=${OPTARG}; #num processos aka linhas impressas;
        ;;
    r)  
        reverse=""
        ;;
    w)
        sort=7
        ;;
  esac
done
shift $((OPTIND-1))

#2 --------------------------------------------- verificação de args -------------------------------------------------------------
if [ $# -lt 1 ] || [[ $1 =~ '^[0-9]+$' ]] || [ $1 -lt 1 ]; then
    echo "USE AT LEAST: './rwstat arg' , with arg being a positive number\n"
    exit 1
fi
#3 -------------------------------------------- ler de /proc/[pid]/io -----------------------------------------------------------
get_pids () {
    for pid in /proc/*; do
        actual_pid="$(basename $pid)" # basename /Users/path/file.txt retorna file.txt
        if ! [[ $actual_pid =~ ^[0-9]+$ ]]; then
            continue
        fi

        if [ -r "$pid/io" ] && [ -r "$pid/comm" ]; then # se tivermos permissão de leitura
            if [[ $c != '' ]] ; then
                comm=$(cat $pid/comm);
                if ! [[ $comm =~ $c ]]; then
                    continue
                fi
            fi
            if [[ $s != '' && $e != '' ]] ; then
                date=$(ls -ld /proc/$actual_pid)
                date=$(echo $date | awk '{ print $6" "$7" "$8}')
                date=$(date -d "${date}" +"%s")
                if ! ([[ date -gt $(date -d "${s}" +"%s") ]] && [[ date -lt $(date -d "${e}" +"%s") ]]); then
                    continue
                fi
            fi 
            if [[ $u != '' ]] ; then
                id="$( stat -c "%u" /proc/${actual_pid} )"
                user="$( id -nu ${id} )"
                if ! [[ $user =~ $u ]]; then
                    continue
                fi
            fi
            if [[ $m != '' ]] ; then
                if ! [[ $actual_pid -gt $m ]]; then
                    continue
                fi
            fi
            if [[ $M != '' ]] ; then
            if ! [[ $actual_pid -lt $M ]]; then
                    continue
                fi
            fi

            pidlist+=($pid) #add to array
        fi
    done
}


#4 --------------------------------------------------- Ler rchar e wchar ----------------------------------------------------------
read_pids() {
    count=0
    for l in "${pidlist[@]}"; do
        pid="$(basename $l)"
        if [ -e /proc/$pid ]; then # verificar se a diretoria ainda existe
            rchar_line=$(grep 'rchar' $l/io) # linhas onde está presente rchar
            rchar=$(echo $rchar_line | grep -o -E '[0-9]+') # valor de rchar
            wchar_line=$(grep 'wchar' $l/io)
            wchar=$(echo $wchar_line | grep -o -E '[0-9]+')
            if [[ $read -eq 1 ]]; then #se já tiver sido executado 1 vez
                op1=${rchar_pre[count]}
                res=$(echo "$(($rchar - $op1))")
                rchar_list+=($res)
                op2=${wchar_pre[count]}
                res2=$(echo "$(($wchar - $op2))")
                wchar_list+=($res2)
                count=$((count+1))
            else #caso contrário ler para preencher lista
                rchar_list+=($rchar)
                wchar_list+=($wchar)
            fi
        fi
    done
}

#5 ---------------------------------------------------- Execução -----------------------------------------------------------------
read=0
get_pids
read_pids
rchar_pre=("${rchar_list[@]}")
wchar_pre=("${wchar_list[@]}")
sleep $1 
rchar_list=()
wchar_list=()
read=1
read_pids

#6 ------------------------------------------------------ Prints e Sorts -------------------------------------------------------------

k=0 
printf '%-20s\t\t %8s\t\t %10s\t %10s\t %9s\t %10s\t %10s %16s\n' "COMM" "USER" "PID" "READB" "WRITEB" "RATER" "RATEW" "DATE" # cabeçalho
for pids in "${pidlist[@]}"; do

    actual_pids="$(basename $pids)"
    comm=$(cat $pids/comm);
    date=$(ls -ld /proc/$actual_pids)
    date=$(echo $date | awk '{ print $6" "$7" "$8}')
    id="$( stat -c "%u" /proc/${actual_pids} )"
    user="$( id -nu ${id} )"
    rchar=${rchar_list[k]}
    wchar=${wchar_list[k]}
    rater=$(echo "scale=3; ($rchar/$1)" | bc)
    ratew=$(echo "scale=3; ($wchar/$1)" | bc)

    printf '%-30s\t %-20s\t %10s\t %10s\t %9s\t %10s\t %10s\t %5s\n' "$comm" "$user" "$actual_pids" "$rchar" "$wchar" "$rater" "$ratew" "$date" 
    k=$((k+1))
done | sort -n -k $sort $reverse | head -n $p
