#!/bin/bash
##VARIABLES
FILE_OUTPUT=""
FILE_INPUT=""
FILE_MEM=""
NMAPSCAN_PREFIX="nmap"
FFUF_LIST="/usr/share/wordlists/dirbuster/directory-list-2.3-small.txt"

#Command Help
usage () {
    echo "Usage: $0"
    echo " -a Automate network discovery (Combine -m and -n option) --- -a @IP/NETWORK"
    echo " -h Display this message and quit."
    echo " -i Input file"
    echo " -m Masscan (top 1000 known ports) scanner on a host or network to specify in the parameter \"-m\" (Specify an output file with \"-o\" too) --- -o FILE -m @IP/NETWORK"
    echo " -n Scan nmap for all host specify in a file (specify with \"-i\" parameter) --- -i FILE  [-o FILE] -n"
    echo " --nikto Use nikto to scan the targets"
}

#Command Output
set_f_output () {
    FILE_OUTPUT=$1
}

set_f_input () {
    FILE_INPUT=$1
}

check_f_input () {
    if [[ $FILE_INPUT == "" ]]; then
        echo "OPTION: \"$1\" - Specify an input file first.";
        exit 1;
    fi
}

testssl_scan(){
    if [[ `dpkg -l | grep "testssl.sh"` ]]; then
        echo "OPTION: \"testssl.sh\" - Command not installed."; 
    fi
    for line in $(cat $FILE_INPUT); do
        testssl --parallel -p -E -P -U --html  https://$line/  
    done
}

nikto_scan(){
    for line in $(cat $FILE_INPUT); do
        domain=`echo $line | sed -n "s/:.*//p"`
        ref=`echo $domain | sed -n "s/\.//gp"`
        nikto -o $ref"_https_nikto.txt" -F txt -host https://$domain/
    done
}

ffuf_scan(){
    for line in $(cat $FILE_INPUT); do
        ref=`echo $line | sed -n "s/\.//gp"`
        ffuf -c -ic -t 50 -u https://$line/FUZZ -w $FFUF_LIST -replay-proxy http://127.0.0.1:8080 -r -recursion -recursion-strategy greedy -recursion-depth 3 -of all -o $ref"_https_ffuf" -debug-log ffuf.log -se
    done
}

nmap_scan(){
    if [[ $FILE_OUTPUT != "" ]]; then
        NMAPSCAN_PREFIX=$FILE_OUTPUT
    fi
    if [[ $FILE_INPUT != "" ]]; then
        for ip in $(cat $FILE_INPUT); do
            printf "________\n"
            printf "NMAP SCAN on %s\n" $ip
            ref=`echo $ip | sed "s/\.//;s/\.//;s/\.//"`
            nmap -A -T4 -Pn -p0-65535 -oN $ref"_"$NMAPSCAN_PREFIX.std -oX $ref"_"$NMAPSCAN_PREFIX.xml -oG $ref"_"$NMAPSCAN_PREFIX.grep $ip;
            cat $ref"_"$NMAPSCAN_PREFIX.grep >> "all_"$NMAPSCAN_PREFIX.grep
        done
    else
        echo "OPTION: \"$OPT\" - Specify an input file first.";
        exit 1;
    fi
}

masscan_scan(){
    if [[ $FILE_OUTPUT == "" ]]; then
        echo "OPTION: \"-$OPT\" - Specify an output file first.";
        exit 1;
    fi
    if [[ $# > 0 ]]; then
        printf "________\n"
        printf "Masscan on %s\n" $1
        sudo masscan --top-ports 1000 --rate 100000 --wait 2 -oJ $FILE_OUTPUT $1;
    else
        echo "OPTION: \"$OPT\" - Specify a network or host"
        exit 1;
    fi
}

fromJSONToHosts(){
    jq '.[].ip' $1 | sort -u | sed -n "s/\"//;s/\"//p" 1>$2
}

while (( $# > 0 ))
do
    OPT="$1"
    shift
    case $OPT in
    "--auto"|"-a")
        if [[ $FILE_OUTPUT == "" ]]; then
            echo "OPTION : \"-a\" - Specify an output file first."
            exit 1;
        fi
        FILE_MEM=$FILE_OUTPUT
        set_f_output "$FILE_OUTPUT.json"
        masscan_scan $1
        shift
        fromJSONToHosts $FILE_OUTPUT $FILE_MEM
        set_f_input $FILE_MEM
        set_f_output $FILE_MEM
        nmap_scan
        break
        ;;
    "--input"|"-i")
        set_f_input $1
        ;;
    "--ouput"|"-o")
        set_f_output $1
        ;;
    "--masscan"|"-m")
        masscan_scan $1
        ;;
    "--nmap"|"-n")
        nmap_scan
        ;;
    "--nikto")
        check_f_input $0
        nikto_scan 
        ;;
    "--testssl")
        check_f_input $0
        testssl_scan
        ;;
    "--ffuf")
        check_f_input $0
        ffuf_scan
        ;;
    "*"|"--help"|"-h")
        usage
        break
        ;;
    esac
    shift
done
