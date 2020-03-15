#!/system/bin/sh
# please note that this only relies on site structure
# dont modify anything unless you know what youre doing
# except for strings, a single change may cause unexpected errors

i_counter=1
i_listcount=0
i_timeout=5
s_URL=""
s_tmp=""
s_tmpName="bctemp"
s_NEWDIR=""
s_MPATH="$PWD" #get main path before anything else
s_UNIQUE_ID="tmp$RANDOM" #use for now

ff_out_red() {
    echo -ne "\e[31m$1\e[0m"
}
ff_out_green() {
    echo -ne "\e[32m$1\e[0m"
}
f_cleanup() {
    rm $s_tmpName &> /dev/null
    rm ${s_tmpName}2 &> /dev/null
    rm ${s_tmpName}3 &> /dev/null
    rm bcinfo &> /dev/null
    rm $s_MPATH/$s_NEWDIR/dl.sh # ensure it will rm cloned dl.sh
    cd $s_MPATH
}
f_prepare() {
    #create folder
    s_NEWDIR="$(cat $s_tmpName | grep "<title>" | cut -d '>' -f 2 | cut -d '-' -f 1 | sed s/\ /_/g)" 
    mkdir "$s_NEWDIR" &> /dev/null
    ls dl.sh &> /dev/null # check if shell dl.sh present, quit if none
    if [ $? -ne 0 ]; then
        ff_out_red "Shell dl.sh not found!"
        f_cleanup
        rmdir $s_NEWDIR
        exit 1
    fi

    cp -n dl.sh "$s_MPATH"/"$s_NEWDIR" &> /dev/null
    cd "$s_MPATH"/"$s_NEWDIR"
}
#parse urls
f_parser_tH() {
    cat $s_tmpName | grep "<td><a href" > ${s_tmpName}2
    i_listcount=$(cat ${s_tmpName}2 | grep -c [^\n])
    echo $i_listcount

    if [ $i_listcount -eq 0 ]; then
        ff_out_red "Cannot get file/s, please check your url."
        f_cleanup
        rmdir $s_NEWDIR
        exit 1
    fi
}
f_parser_tH_post() {
    # get url only
    cat ${s_tmpName}2 | cut -d '"' -f 2 > ${s_tmpName}3
    newtmp=$(cat ${s_tmpName}3 | grep -c [^\n])

    # continue if bcinfo file exist
    ls bcinfo &> /dev/null
    if [ $? -ne 0 ]; then
        echo "$i_counter" > bcinfo
    else
        i_counter=$(cat bcinfo)
    fi

    if [ $newtmp -ne $i_listcount ]; then
        ff_out_red "Parsed url not matched! Expected is $i_listcount, but got $newtmp"
        f_cleanup
        rmdir $s_NEWDIR
        exit 1
    fi

    while [ $i_counter -le $i_listcount ]
    do
        clear

        echo -ne "\e[KDownloading $i_counter of $i_listcount...\r"
        tmp_URL=$(sed -n ${i_counter}p ${s_tmpName}3) # read list of url by line
        f_getUrl "${s_tmpName}4" "${tmp_URL}"
        tmp_URL_post=$(cat ${s_tmpName}4 | grep "Download to Computer" | grep -o "https.*mp3")
        
        sleep 1 # delay before new shell
        bash dl.sh $tmp_URL_post

        # remove after use
        rm ${s_tmpName}4
        let i_counter++
        echo "$i_counter" > bcinfo
    done

    echo
}
f_getUrl() {
    curl --connect-timeout $i_timeout -o "$1" "$2" &> /dev/null
    if [ $? -ne 0 ]; then
        f_getUrl $1
    fi
}
main() {
    ff_out_green "Preparing...\n"
    # prepare
    f_getUrl $s_tmpName $s_URL
    f_prepare
    rm $s_MPATH/$s_tmpName

    # start
    ff_out_green "Track List: "
    f_getUrl $s_tmpName $s_URL
    f_parser_tH
    # get url downloads
    f_parser_tH_post

    ff_out_green "Finished!"
    f_cleanup
}

#init checks
s_URL="$1"
if [ -z $s_URL ]; then
    ff_out_red "Please provide link!"
    exit 1
fi
touch "$s_UNIQUE_ID" &> /dev/null
if [ $? -ne 0 ]; then
    ff_out_red "Cannot write on this directory!"
    exit 1
fi
rm "$s_UNIQUE_ID"

main

# not required, but why not?
cd "$s_MPATH"
