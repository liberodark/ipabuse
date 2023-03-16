#!/bin/bash
#
# About: Check IP automatically
# Author: liberodark
# Thanks :
# License: GNU GPLv3

version="0.0.3"
echo "Welcome on Control IP Script $version"

#=================================================
# CHECK ROOT
#=================================================

if [[ $(id -u) -ne 0 ]] ; then echo "Please run as root" ; exit 1 ; fi

#=================================================
# RETRIEVE ARGUMENTS FROM THE MANIFEST AND VAR
#=================================================

API="Your API"
IP=$1
VALUE="false"

usage ()
{
     echo "usage: script -ip 127.0.0.1"
     echo "options :"
     echo "ip : 127.0.0.1"
     echo "unban : 127.0.0.1"
     echo "-h: Show help"
}

set_ip(){
IP="$1"
}

run_check(){
    echo "Check ${IP}"
    grep -r "${IP}" /var/log/nginx/*.log || echo "No found ${IP} in Nginx"
    cscli alerts list | grep "${IP}" || echo "No found ${IP} in CrowdSec"
    }

ipabuse_check(){
    curl -G --silent https://api.abuseipdb.com/api/v2/check \
    --data-urlencode "ipAddress=${IP}" \
    -d maxAgeInDays=90 \
    -d verbose \
    -H "Key: ${API}" \
    -H "Accept: application/json" >> ip.test
    grep -F -o '"isWhitelisted":false' ip.test | sed 's/"isWhitelisted"://g'
    rm -f ip.test
    }

ipabuse_repport(){
    curl https://api.abuseipdb.com/api/v2/report \
    --data-urlencode "ip=${IP}" \
    -d categories=21 \
    --data-urlencode "comment=Web Attack Detection" \
    -H "Key: ${API}" \
    -H "Accept: application/json"
    }

run_ban(){
    echo "Check ${IP}"
    if [ "$(ipabuse_check)" = ${VALUE} ]; then
        echo "${IP} is Blacklisted"
        fail2ban-client set yunohost banip "${IP}"
        fail2ban-client reload
        ipabuse_repport > /dev/null 2>&1
    else
        echo "${IP} is Whitelisted"
    fi
    }

run_unban(){
    echo "Unban ${IP}"
        fail2ban-client set yunohost unbanip "${IP}"
        fail2ban-client reload
    }

parse_args ()
{
    while [ $# -ne 0 ]
    do
      case "${1}" in
        -ip)
            shift
            set_ip "$@"
            run_check
            run_ban
            ;;
        -unban)
            shift
            set_ip "$@"
            run_unban
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Invalid argument : ${1}" >&2
            usage >&2
            exit 1
            ;;
      esac
      shift
    done

}

parse_args "$@"
