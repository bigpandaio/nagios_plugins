#!/bin/bash
 
#############################################################################
#
#	define command {
#				command_name check_ssl_expire
#				command_line /path/to/script/location/check_ssl_expire -c $ARG1$ -d $ARG2$ -D $ARG3$
#				command_line $USER1$/check_ssl_expire -c $ARG1$ -d $ARG2$ -D $ARG3$
#	}
#
#	define service {
#        		use             		generic-service
#        		host_name  				host
#        		service_description 	HTTPS-CRT
#        		check_command 			check_ssl_expire!host.com:443!60!30
#	}
#
#############################################################################
function PRINT_USAGE(){
  echo "This Nagios plugin checks SSL certificates for expiration :
  -c HOST:PORT host and port to connect
  -d DAYS  minimum days before expiry, otherwise a WARNING is issued
  -D DAYS  minimum days before expiry, otherwise a CRITICAL is issued
  -h    prints out this help"
  exit 0
}
 
CONNECT='';WDAYS=0;CDAYS=0;
declare -i CDAYS 
declare -i WDAYS
while true ; do
  getopts 'c:d:D:h' OPT 
  if [ "$OPT" = '?' ] ; then break; fi; 
  case "$OPT" in
    "c") CONNECT="$OPTARG";;
    "d") WDAYS="$OPTARG";;
    "D") CDAYS="$OPTARG";;
    "h") PRINT_USAGE;;
  esac
done
 
if [ -z "$CONNECT" -o '(' "$WDAYS" = '0' -a "$CDAYS" = '0' ')' ] ; then
  PRINT_USAGE
fi
 
function get_crt_expiry
{
        # connect to host with OpenSSL client, filter CRT, parse CRT,
        # get expiry time, convert to traditionnal y-m-d h:s
        echo -n '' | openssl s_client -connect "$1" 2>/dev/null \
                | awk 'BEGIN { p = 0 }
                                         /BEGIN CERT/ { p = 1 }
                                         { if (p) print $0 }
                                         /END CERT/ { p = 0 }' \
                | openssl asn1parse 2>/dev/null \
                | grep 'UTCTIME' \
                | awk '{ print $7 }' \
                | tr -d 'Z:' \
                | tail -n 1 \
                | sed -r 's/^(..)(..)(..)(..)(..).*$/\1-\2-\3 \4:\5/'
}
 
EXPIRY=$(get_crt_expiry "$CONNECT")
if [ -z "$EXPIRY" ] ; then
        echo "WARNING - cannot get expiry date for $CONNECT"
        exit 1
fi
EPOCH_EXPIRY=$(date -d "$EXPIRY" +%s)
EPOCH_NOW=$(date +%s)
let "REM_DAYS = (EPOCH_EXPIRY - EPOCH_NOW)/(24*3600)"
 
if [ "$CDAYS" -gt 0 -a "$REM_DAYS" -lt "$CDAYS" ] ; then
  echo "CRITICAL - $CONNECT crt expries on $EXPIRY ($REM_DAYS days left)" 
        exit 2
fi
 
if [ "$WDAYS" -gt 0 -a "$REM_DAYS" -lt "$WDAYS" ] ; then
  echo "WARNING - $CONNECT crt expries on $EXPIRY ($REM_DAYS days left)" 
        exit 1
fi
  
echo "OK - $CONNECT crt expries on $EXPIRY ($REM_DAYS days left)"
