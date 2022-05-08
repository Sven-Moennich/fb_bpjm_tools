#!/bin/bash


function bpjm_crc32 {
RAW=$1
echo "# check crc32 of file $RAW"
calc="$(crc32 <( tail -c +$((1 + 4)) $RAW ))"
read="$(head -c4 $RAW | xxd -p)"
[ "$calc" != "$read" ] && echo "# fail: $read != $calc" || echo "# match: $read"
}

function bpjm_get_filename {
FILE=$1
echo $( strings $FILE | head -n 1)
}

function bpjm_decode {
RAWFILE=$1
OUTFILE=$( bpjm_get_filename $RAWFILE )
echo "# decode $RAWFILE"
od -t x1 -An -j 64 $RAWFILE | tr -d '\n ' > $OUTFILE
# Nach 66 Zeichen Zeilenumbruch einfügen
sed -i -e 's/.\{66\}/&\n/g' $OUTFILE
# Nach 32 Zeichen (erster md5 hash) leerzeichen einfügen
sed -i 's/.\{32\}/& /' $OUTFILE
# nach 65 Zeichen (zweiter md5 hash + leerzeichen) leerzeichen einfügen
sed -i 's/.\{65\}/& /' $OUTFILE
echo "# $OUTFILE written."
}

function bpjm_encode {
RAWFILE=$1
OUTFILE=bpjm_$RAWFILE.data
echo "# encode $RAWFILE"
tmpfile=$(mktemp)
# Trenner zwischen crc32 und filename
echo -ne '\x01' > $tmpfile
# Filename auf 59 stellen füllen
printf %-59s $RAWFILE | tr ' ' '\0' >>$tmpfile
# Daten aus Datei convertieren
cat $RAWFILE | tr -d '\n ' | xxd -r -ps >>$tmpfile
# crc32 berechnen
CRC32=$(crc32 "$tmpfile")
# crc32 in datei schreiben
echo -n $CRC32 | xxd -r -ps >$OUTFILE
# rest daten in datei schreiben
cat $tmpfile >>$OUTFILE
rm -f "$tmpfile"
echo "# $OUTFILE written."
}

function bpjm_add {
FILE=$1
URL=$2

bpjm_crc32 $FILE
bpjm_decode $FILE
RAWFILE=$( bpjm_get_filename $FILE )
echo "# add $URL to bpjm list"
MD5_URL=$( echo -n $URL | md5sum | awk '{print $1}' )
MD5_PATH=$( echo -n "/" | md5sum | awk '{print $1}' )
DEEP=00
echo "$MD5_URL $MD5_PATH $DEEP" >>$RAWFILE
bpjm_encode $RAWFILE
bpjm_crc32 $FILE
rm -f $RAWFILE
}

function bpjm_remove {
FILE=$1
URL=$2
bpjm_crc32 $FILE
bpjm_decode $FILE
RAWFILE=$( bpjm_get_filename $FILE )
MD5_URL=$( echo -n $URL | md5sum | awk '{print $1}' )
MD5_PATH=$( echo -n "/" | md5sum | awk '{print $1}' )
DEEP=00
if grep -Rq "$MD5_URL" $RAWFILE
then
echo "# remove $URL from bpjm list"
sed -i "/$MD5_URL/d" $RAWFILE
else
echo "# URL $URL not found in bpjm list"
fi
bpjm_encode $RAWFILE
bpjm_crc32 $FILE
rm -f $RAWFILE
}

function bpjm_test {
FILE=$1
URL=$2
bpjm_crc32 $FILE
bpjm_decode $FILE
RAWFILE=$( bpjm_get_filename $FILE )
MD5_URL=$( echo -n $URL | md5sum | awk '{print $1}' )
MD5_PATH=$( echo -n "/" | md5sum | awk '{print $1}' )
DEEP=00
if grep -Rq "$MD5_URL" $RAWFILE
then
echo "# URL $URL is blocked by bpjm"
else
echo "# URL $URL not found in bpjm list"
fi
#bpjm_encode $RAWFILE
#bpjm_crc32 $FILE
rm -f $RAWFILE
}


cmd=help
filename=""
input=""

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help) cmd=help ;;
        -e|--encode) cmd=encode ;;
        -d|--decode) cmd=decode ;;
        -c|--crc32) cmd=crc32 ;;
        -f|--file) filename="$2"; shift ;;
        -a|--add) cmd=add; input="$2"; shift ;;
        -r|--remove) cmd=remove; input="$2"; shift ;;
        -t|--test) cmd=test; input="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

echo "######################################################"
echo "# fb bpjm tools by lano"
echo "# "
if [ "$cmd" = "help" ]; then
echo "# -h / --help               print this help"
echo "# -e / --encode             encode <filename>"
echo "# -d / --decode             decode <filename>"
echo "# -a / --add                add a url to list"
echo "# -r / --remove             remove a entry from list"
echo "# -t / --test               test if URL is blocked by bpjm"
echo "# -c / --crc32              check crc32 of given filename"
echo "# -f / --file               <filename>"
fi

if [ "$cmd" = "encode" ]; then
bpjm_encode $filename
fi

if [ "$cmd" = "decode" ]; then
bpjm_decode  $filename
fi

if [ "$cmd" = "crc32" ]; then
bpjm_crc32  $filename
fi

if [ "$cmd" = "add" ]; then
bpjm_add  $filename $input 
fi

if [ "$cmd" = "remove" ]; then
bpjm_remove  $filename $input
fi

if [ "$cmd" = "test" ]; then
bpjm_test  $filename $input 
fi
















