#!/bin/sh
#copyright by hiboy
hiboyfile="http://opt.cn2qq.com/opt-file"
hiboyscript="http://opt.cn2qq.com/opt-script"
hiboyfile2="https://raw.githubusercontent.com/hiboyhiboy/opt-file/master"
hiboyscript2="https://raw.githubusercontent.com/hiboyhiboy/opt-script/master"
ACTION=$1
scriptfilepath=$(cd "$(dirname "$0")"; pwd)/$(basename $0)
scriptpath=$(cd "$(dirname "$0")"; pwd)
scriptname=$(basename $0)

eval `dbus export speedup_`
[ -z $speedup_enable ] && speedup_enable=0
speedup_path="/koolshare/bin/speedup"
if [ "$speedup_enable" != "0" ] ; then
	[ -z "$speedup_Info" ] && speedup_Info=1
	Info="$speedup_Info"
	[ -z "$Info" ] && Info=1
	STATUS="N"
	SN=""
	check_Qos="$speedup_check_Qos"
	Start_Qos="$speedup_Start_Qos"
	Heart_Qos="$speedup_Heart_Qos"
	ln -sf /koolshare/scripts/speedup.sh /koolshare/init.d/Sh27speedup.sh
	chmod 777 /koolshare/init.d/Sh27_speedup.sh
fi



speedup_restart () {

speedup_renum=`dbus get speedup_renum`
relock="/var/lock/speedup_restart.lock"
if [ "$1" = "o" ] ; then
	dbus set speedup_renum="0"
	[ -f $relock ] && rm -f $relock
	return 0
fi
if [ "$1" = "x" ] ; then
	if [ -f $relock ] ; then
		logger -t "【speedup】" "多次尝试启动失败，等待【"`cat $relock`"分钟】后自动尝试重新启动"
		exit 0
	fi
	speedup_renum=${speedup_renum:-"0"}
	speedup_renum=`expr $speedup_renum + 1`
	dbus set speedup_renum="$speedup_renum"
	if [ "$speedup_renum" -gt "2" ] ; then
		I=19
		echo $I > $relock
		logger -t "【speedup】" "多次尝试启动失败，等待【"`cat $relock`"分钟】后自动尝试重新启动"
		while [ $I -gt 0 ]; do
			I=$(($I - 1))
			echo $I > $relock
			sleep 60
			[ "$(dbus get speedup_renum)" = "0" ] && exit 0
			[ $I -lt 0 ] && break
		done
		dbus set speedup_renum="0"
	fi
	[ -f $relock ] && rm -f $relock
fi
dbus set speedup_status=0
eval "$scriptfilepath &"
exit 0
}

speedup_get_status () {

A_restart=`dbus get speedup_status`
B_restart="$speedup_enable$speedup_Info$check_Qos$Start_Qos$Heart_Qos"
B_restart=`echo -n "$B_restart" | md5sum | sed s/[[:space:]]//g | sed s/-//g`
if [ "$A_restart" != "$B_restart" ] ; then
	dbus set speedup_status=$B_restart
	needed_restart=1
else
	needed_restart=0
fi
}

speedup_check () {

speedup_get_status
if [ "$speedup_enable" != "1" ] && [ "$needed_restart" = "1" ] ; then
	[ ! -z "$(ps -w | grep "$speedup_path" | grep -v grep )" ] && logger -t "【speedup】" "停止 speedup" && speedup_close
	{ eval $(ps -w | grep "$scriptname" | grep -v grep | awk '{print "kill "$1";";}'); exit 0; }
fi
if [ "$speedup_enable" = "1" ] ; then
	if [ "$needed_restart" = "1" ] ; then
		speedup_close
		speedup_start
	else
		[ -z "$(ps -w | grep "$speedup_path" | grep -v grep )" ] && speedup_restart
	fi
fi
}

speedup_keep () {
logger -t "【speedup】" "守护进程启动"
sleep 60
speedup_enable=`dbus get speedup_enable` #speedup_enable
i=1
while [ "$speedup_enable" = "1" ]; do
	NUM=`ps -w | grep "$speedup_path" | grep -v grep |wc -l`
	if [ "$NUM" -lt "1" ] || [ ! -s "$speedup_path" ] || [ "$i" -ge 369 ] ; then
		logger -t "【speedup】" "重新启动$NUM"
		speedup_restart
	fi
sleep 69
i=$((i+1))
speedup_enable=`dbus get speedup_enable` #speedup_enable
done
}

speedup_close () {
killall speedup
killall -9 speedup
eval $(ps -w | grep "speedup start_path" | grep -v grep | awk '{print "kill "$1";";}')
eval $(ps -w | grep "speedup.sh keep" | grep -v grep | awk '{print "kill "$1";";}')
eval $(ps -w | grep "$scriptname keep" | grep -v grep | awk '{print "kill "$1";";}')
}

speedup_start () {

[ -z "$check_Qos" ] && logger -t "【speedup】" "错误！！！【Check代码】未填写" && sleep 10 && exit
[ -z "$Start_Qos" ] && logger -t "【speedup】" "错误！！！【Start代码】未填写" && sleep 10 && exit

curltest=`which curl`
if [ -z "$curltest" ] || [ ! -s "`which curl`" ] ; then
	logger -t "【speedup】" "找不到 curl ，需要手动安装"
	logger -t "【speedup】" "启动失败, 10 秒后自动尝试重新启动" && sleep 10 && speedup_restart x
fi

speedup_vv=2017-10-25
speedup_v=$(grep 'speedup_vv=' /koolshare/scripts/speedup.sh | grep -v 'speedup_v=' | awk -F '=' '{print $2;}')
logger -t "【speedup】" "运行 $speedup_path"
ln -sf /koolshare/scripts/speedup.sh /koolshare/bin/speedup
chmod 777 /koolshare/bin/speedup
eval "$speedup_path" start_path &
sleep 2
[ ! -z "$(ps -w | grep "/koolshare/bin/speedup" | grep -v grep )" ] && logger -t "【speedup】" "启动成功 $speedup_v " && speedup_restart o
[ -z "$(ps -w | grep "/koolshare/bin/speedup" | grep -v grep )" ] && logger -t "【speedup】" "启动失败, 注意检查端口是否有冲突,程序是否下载完整,10 秒后自动尝试重新启动" && sleep 10 && speedup_restart x

speedup_get_status
eval "$scriptfilepath keep &"

}

speedup_start_path () {

# 主程序循环
re_STAT="$(eval "$check_Qos" | grep qosListResponse)"

# 获取提速包数量
qos_Info="$(echo "$re_STAT" | awk -F"/qosInfo" '{print NF-1}')"
[ -z "$qos_Info" ] && qos_Info=0
if [[ "$qos_Info"x == "1"x ]]; then
Info=1
fi
if [[ "$qos_Info" -ge 1 ]]; then
# 提速包1
qos_Info_1="$(echo "$re_STAT" | awk -F '/qosInfo' '{print $1}')"
qos_Info_x="$qos_Info_1"
get_info
logger -t "【speedup】" "包【1】 提速状态【$re_STATUS】 提速包名称【$prod_Name】 提速包代码【$prod_Code】 提速包时间【$used_Minutes/$total_Minutes】"
fi
if [[ "$qos_Info" -ge 2 ]]; then
# 提速包2
qos_Info_2="$(echo "$re_STAT" | awk -F '/qosInfo' '{print $2}')"
qos_Info_x="$qos_Info_2"
get_info
logger -t "【speedup】" "包【2】 提速状态【$re_STATUS】 提速包名称【$prod_Name】 提速包代码【$prod_Code】 提速包时间【$used_Minutes/$total_Minutes】"
fi
if [[ "$qos_Info" -ge 3 ]]; then
# 提速包3
qos_Info_3="$(echo "$re_STAT" | awk -F '/qosInfo' '{print $3}')"
qos_Info_x="$qos_Info_3"
get_info
logger -t "【speedup】" "包【3】 提速状态【$re_STATUS】 提速包名称【$prod_Name】 提速包代码【$prod_Code】 提速包时间【$used_Minutes/$total_Minutes】"
fi
if [[ "$qos_Info" -ge 4 ]]; then
# 提速包4
qos_Info_4="$(echo "$re_STAT" | awk -F '/qosInfo' '{print $4}')"
qos_Info_x="$qos_Info_4"
get_info
logger -t "【speedup】" "包【4】 提速状态【$re_STATUS】 提速包名称【$prod_Name】 提速包代码【$prod_Code】 提速包时间【$used_Minutes/$total_Minutes】"
fi
if [[ "$qos_Info" -ge 5 ]]; then
# 提速包5
qos_Info_5="$(echo "$re_STAT" | awk -F '/qosInfo' '{print $5}')"
qos_Info_x="$qos_Info_5"
get_info
logger -t "【speedup】" "包【5】 提速状态【$re_STATUS】 提速包名称【$prod_Name】 提速包代码【$prod_Code】 提速包时间【$used_Minutes/$total_Minutes】"
fi


QOS_Status
logger -t "【speedup】" "包【$Info】 提速状态【$re_STATUS】 重置时间【$remaining_Time】 提速包名称【$prod_Name】 提速包代码【$prod_Code】 提速包时间【$used_Minutes/$total_Minutes】"
#QOS_Start
[ -z "$SN" ] && SN=0
speedup_enable=`dbus get speedup_enable`
[ -z $speedup_enable ] && speedup_enable=0 && dbus set speedup_enable=0
while [[ "$speedup_enable" != 0 ]] 
do
	if [[ "$STATUS"x != "Y"x ]]; then
		logger -t "【speedup】" "STATUS is $STATUS , need to Speedup now"
		QOS_Start
		if [[ -z "$SN" ]]; then
			logger -t "【speedup】" "Start_ERROR!!!"
		else
			logger -t "【speedup】" "Start Speedup, SN: $SN"
			[ ! -z "$Heart_Qos" ] && QOS_Heart
			sleep 57
			QOS_Status
			logger -t "【speedup】" "包【$Info】 提速状态【$re_STATUS】 重置时间【$remaining_Time】 提速包名称【$prod_Name】 提速包代码【$prod_Code】 提速包时间【$used_Minutes/$total_Minutes】"
			if [[ "$STATUS"x == "Y"x ]]; then
				[ ! -z "$Heart_Qos" ] && QOS_Heart
				sleep 57
			fi
		fi
	fi
	QOS_Status
	#logger -t "【speedup】" "包【$Info】 提速状态【$re_STATUS】 重置时间【$remaining_Time】 提速包名称【$prod_Name】 提速包代码【$prod_Code】 提速包时间【$used_Minutes/$total_Minutes】"
	if [[ "$STATUS"x == "Y"x ]]; then
		[ ! -z "$Heart_Qos" ] && QOS_Heart
		sleep 57
	fi
	speedup_enable=`dbus get speedup_enable`
	[ -z $speedup_enable ] && speedup_enable=0 && dbus set speedup_enable=0
done

}

get_info()
{
# 提速包名称
prod_Name="$(echo "$qos_Info_x" | awk -F"\<prodName\>|\<\/prodName\>" '{if($2!="") print $2}')"
# 提速包代码
prod_Code="$(echo "$qos_Info_x" | awk -F"\<prodCode\>|\<\/prodCode\>" '{if($2!="") print $2}')"
# 提速包总时间（分钟）
total_Minutes="$(echo "$qos_Info_x" | awk -F"\<totalMinutes\>|\<\/totalMinutes\>" '{if($2!="") print $2}')"
# 提速包使用时间（分钟）
used_Minutes="$(echo "$qos_Info_x" | awk -F"\<usedMinutes\>|\<\/usedMinutes\>" '{if($2!="") print $2}')"
# 提速状态
re_STATUS="$(echo "$qos_Info_x" | awk -F"\<isSpeedup\>|\<\/isSpeedup\>" '{if($2!="") print $2}')"
# 重置剩余时间
remaining_Time="$(echo "$qos_Info_x" | awk -F"\<remainingTime\>|\<\/remainingTime\>" '{if($2!="") print $2}')"

}

QOS_Status()
{

#Session_Key="$(echo "$check_Qos" | grep -Eo "SessionKey:[ A-Za-z0-9_-]+" | cut -d ':' -f2 | sed -e "s/ //g" )"
#Signa_ture="$(echo "$check_Qos" | grep -Eo "Signature:[ A-Za-z0-9_-]+" | cut -d ':' -f2 | sed -e "s/ //g" )"
#GMT_Date="$(echo "$check_Qos" | grep -Eo "Date:[ A-Za-z0-9_-]+,[ A-Za-z0-9_-]+:[0-9]+:[ A-Za-z0-9_-]+" | awk -F 'Date: ' '{print $2}')"
#family_Id="$(echo "$check_Qos" | grep -Eo "familyId=[0-9]+" | awk -F '=' '{print $2}')"

#check_Qos_x="curl -s -H 'SessionKey: ""$Session_Key""' -H 'Signature: ""$Signa_ture""' -H 'Date: ""$GMT_Date""' -H 'Content-Type: text/xml; charset=utf-8' -H 'Host: api.cloud.189.cn' -H 'User-Agent: Apache-HttpClient/UNAVAILABLE (java 1.4)' 'http://api.cloud.189.cn/family/qos/checkQosAbility.action?familyId=""$family_Id""'"

check_Qos_x="$(echo "$check_Qos"" -s ")"

re_STAT="$(eval "$check_Qos_x" | grep qosListResponse)"

# 获取状态
if [[ "$Info"x == "1"x ]]; then
	# 提速包1
	qos_Info_1="$(echo "$re_STAT" | awk -F '/qosInfo' '{print $1}')"
	qos_Info_x="$qos_Info_1"
fi
if [[ "$Info"x == "2"x ]]; then
	# 提速包2
	qos_Info_2="$(echo "$re_STAT" | awk -F '/qosInfo' '{print $2}')"
	qos_Info_x="$qos_Info_2"
fi
if [[ "$Info"x == "3"x ]]; then
	# 提速包3
	qos_Info_3="$(echo "$re_STAT" | awk -F '/qosInfo' '{print $3}')"
	qos_Info_x="$qos_Info_3"
fi
if [[ "$Info"x == "4"x ]]; then
	# 提速包4
	qos_Info_4="$(echo "$re_STAT" | awk -F '/qosInfo' '{print $4}')"
	qos_Info_x="$qos_Info_4"
fi
if [[ "$Info"x == "5"x ]]; then
	# 提速包5
	qos_Info_5="$(echo "$re_STAT" | awk -F '/qosInfo' '{print $5}')"
	qos_Info_x="$qos_Info_5"
fi

get_info

STATUS=$re_STATUS

sleep 3
}

QOS_Start()
{

#Session_Key="$(echo "$Start_Qos" | grep -Eo "SessionKey:[ A-Za-z0-9_-]+" | cut -d ':' -f2 | sed -e "s/ //g" )"
#Signa_ture="$(echo "$Start_Qos" | grep -Eo "Signature:[ A-Za-z0-9_-]+" | cut -d ':' -f2 | sed -e "s/ //g" )"
#GMT_Date="$(echo "$Start_Qos" | grep -Eo "Date:[ A-Za-z0-9_-]+,[ A-Za-z0-9_-]+:[0-9]+:[ A-Za-z0-9_-]+" | awk -F 'Date: ' '{print $2}')"

#start_Qos_x="curl -s -H 'SessionKey: ""$Session_Key""' -H 'Signature: ""$Signa_ture""' -H 'Date: ""$GMT_Date""' -H 'Content-Type: text/xml; charset=utf-8' -H 'Host: api.cloud.189.cn' -H 'User-Agent: Apache-HttpClient/UNAVAILABLE (java 1.4)' 'http://api.cloud.189.cn/family/qos/startQos.action?prodCode=""$prod_Code""'"

start_Qos_x="$(echo "$Start_Qos"" -s ")"

SN_STAT="$(eval "$start_Qos_x" | grep qosInfo)"

SN="$(echo "$SN_STAT" | awk -F"\<qosSn\>|\<\/qosSn\>" '{if($2!="") print $2}')"

echo `date "+%Y-%m-%d %H:%M:%S"` "Start Speedup, SN: $SN"
sleep 3
}

QOS_Heart()
{

if [ "$SN"x != "x" ] && [ "$SN" != "0" ] ; then
	Heart_Qos_x="$(echo "$Heart_Qos" | sed -e "s|^\(.*qosSn.*\)=[^=]*$|\1=$SN|")"
	Heart_Qos_x="$(echo "$Heart_Qos_x""' -s ")"
	eval "$Heart_Qos_x"

fi

}



case $ACTION in
start)
	dbus set speedup_status=0
	speedup_close
	speedup_check
	;;
check)
	speedup_check
	;;
stop)
	speedup_close
	;;
keep)
	#speedup_check
	speedup_keep
	;;
start_path)
	speedup_start_path
	;;
*)
	speedup_check
	;;
esac








