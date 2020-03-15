#!/system/bin

# ready term
clear

#s_URL='http://d36.mobdisc.com/download/aedbf916-efa7-4a35-982d-54fd08055766/5592-Asphalt-8-Airborne-v4-8-0i-cache.zip/'

s_URL=$1
s_fname=$2

s_listReject="*.html"
s_ILLEGALCHARS="\:\!\?\ \'\|\/\\"

# filesize
declare -i i_fsLocal
declare -i i_fsRemote

# filename
declare -g s_fname

# counter
declare -g i_tmp=0

# timeout
declare -i i_timeout=10
i_tout_count=0

# info pos
fn_LONGEST_WORD="Reading Meta..."
fn_pos=`expr $COLUMNS - ${#fn_LONGEST_WORD}`

ff_out() {
	echo -e "\033[32m$1\033[0m"
}

ff_out_info() {
	echo -e "\e[1;${fn_pos}H$1\e[K"
}

# print w/ clear line
ff_out_cl() {
	echo -e "\e[K$1"
}

f_refreshConnection() {
	# refresh connection
	su -c svc data disable
	su -c svc data enable
	sleep 15
}

i_status=200
f_checkURLifAlive() {
	curl --connect-timeout $i_timeout -sI $s_URL > temp
	if [ $? -ne 0 ]; then
		f_checkURLifAlive
	fi

	i_status=`cat temp | grep "HTTP*" | grep -o "[0-9][0-9][0-9]"`
	ff_out_info "Status: $i_status"

	case "$i_status" in
		404)
			ff_out_cl "File not found."
			exit 1
			;;
		403)
			ff_out_cl "Forbidden / Path expired!"
			exit 1
			;;
		302 | 301)
			ff_out_cl 'Document Found / Moved. Awaiting response...'
			s_URL=`cat temp | grep -i "location: " | cut -d ' ' -f 2 | grep -o "[[:print:]]**"`
			f_checkURLifAlive
			;;
		200)
			ff_out_cl "Feteched OK!"
			;;
        405)
            ff_out_cl "OK"
            ;;
		*)
			ff_out_cl "Status cant decode. Exiting..."
			exit 1
			::
	esac

}

f_getfname() {
	let i_tmp++
    s_fname="`cat temp | grep -i -o "filename=[[:print:]]*" | cut -d '"' -f 2 | grep -o "[[:print:]]**" | sed s/["$s_ILLEGALCHARS"]/./g`"
    if [ -z "$s_fname" ]
    then
        s_fname=$(echo $s_URL | rev | cut -d '/' -f1 | rev | sed s/%20/_/g)

        if [ "${#s_fname}" -gt 50 ]
		then
			s_fname="`echo $s_fname | grep -o ".........$"`"
		fi
	fi

	# hardcode fname
#	eval "'s_fname='\"$s_fname\"'"
	i_tmp=0
}

f_getfsLocal() {
	i_fsLocal=$(stat -c %s "$s_fname")
}

f_getfsRemote() {
	i_fsRemote=`cat temp | grep -i -o "content-length: [0-9]*" | grep -o "[0-9]*"`

	if [ -z "$i_fsRemote" ]
	then
		i_fsRemote=999999999
	fi
}

f_getExtension() {
	s_ext=`echo "$s_fname" | rev | cut -d '.' -f 1 | rev`

	if [ ${#s_ext} -gt 5 ]; then
		s_ext=`file --mime-type "$s_fname" | rev | cut -d '/' -f 1 | rev`
		s_nfname=`echo "$s_fname".$s_ext`
		mv "$s_fname" "$s_nfname"
	fi
}


ti_counterArgs=1
f_args() {
	val="$2"

	case $1 in
		"--output" | "-o")
			s_fname="$val"
			;;
	esac
}


f_inits () {
	# args
	for params in "$@"; do
		arg_val="`eval 'echo $'$(($ti_counterArgs + 1))`"
		f_args $params "$arg_val"
		let ti_counterArgs++
	done

	# one time
	f_trywrite
	ff_out_info "Checking file..."
	f_checkURLifAlive
	if [ -z $s_fname ]; then
		ff_out "Getting filename... "
		f_getfname
	else
		ff_out "Provided filename:"
	fi
	echo "filename: $s_fname"

	echo
	ff_out "Getting filesize..."
	f_getfsRemote
	echo -n "length: "

	kb=1024
	mb=$(($kb * $kb))
	gb=$(($mb * $mb))

	if [ $i_fsRemote -ge $gb ]; then
		echo "$(($i_fsRemote / $gb)) GB"
	elif [ $i_fsRemote -ge $mb ]; then
		echo "$(($i_fsRemote / $mb)) MB"
	elif [ $i_fsRemote -ge $kb ]; then
		echo "$(($i_fsRemote / $kb)) KB"
	fi

	rm temp

}

f_trywrite() {
	touch tmp &> /dev/null

	if [ $? -ne 0 ]; then
		echo "Cannot write files. Abort."
		exit 1
	fi

	rm tmp
}

f_inits $@

while :
do
	ff_out_info "Online"
	# ready ln 7
	echo -e "\033[9;0H\033[K"
	# non-verbose
	wget -q --show-progress -R $s_listReject -O "$s_fname"  --tries=$i_timeout -T $i_timeout -c "$s_URL"

	# compare sizes
	f_getfsLocal
	if [ $i_fsLocal -eq $i_fsRemote ]
	then
		f_getExtension
		ff_out "Complete!"
		exit 0
	else
		ff_out_info "Retrying..."
		let i_tout_count++
		sleep 1
	fi

	if [ $i_tout_count -ge 10 ]
	then
		i_tout_count=0
	#	f_refreshConnection
	fi
done
