 #!/bin/sh

LOG_FILE='/var/log/cloudflarespeedtest.log'
IP_FILE='/usr/share/cloudflarespeedtestresult.txt'
IPV4_TXT='/usr/share/CloudflareSpeedTest/ip.txt'
IPV6_TXT='/usr/share/CloudflareSpeedTest/ipv6.txt'

function get_global_config(){
	while [[ "$*" != "" ]]; do
		eval ${1}='`uci get cloudflarespeedtest.global.$1`' 2>/dev/null
		shift
	done
}

function get_servers_config(){
	while [[ "$*" != "" ]]; do
		eval ${1}='`uci get cloudflarespeedtest.servers.$1`' 2>/dev/null
		shift
	done
}

echolog() {
	local d="$(date "+%Y-%m-%d %H:%M:%S")"
	echo -e "$d: $*" >>$LOG_FILE
}

function read_config(){
	get_global_config "enabled" "speed" "custome_url" "threads" "custome_cors_enabled" "custome_cron" "t" "tp" "dt" "dn" "dd" "tl" "tll" "allip_enabled" "advanced" "proxy_mode"
	get_servers_config "ssr_services" "ssr_enabled" "passwall_enabled" "passwall_services" "passwall2_enabled" "passwall2_services" "bypass_enabled" "bypass_services" "vssr_enabled" "vssr_services" "DNS_enabled" "xray_core_enabled" "xray_core_services" "v2ray_enabled" "v2ray_services" "shadowsocks_services" "shadowsocks_disabled"  "HOST_enabled"
}

function  speed_test(){

	rm -rf $LOG_FILE

	command="/usr/bin/cdnspeedtest -sl $((speed*125/1000)) -url ${custome_url} -o ${IP_FILE}"

	if [ $allip_enabled -eq "1" ] ;then
		command="${command} -f ${IPV4_TXT} -f ${IPV6_TXT}"
	else
		command="${command} -f ${IPV4_TXT}"
	fi

	if [ $advanced -eq "1" ] ; then
		command="${command} -httping-code 200 -tl ${tl} -tll ${tll} -n ${threads} -t ${t} -dt ${dt} -dn ${dn}"
		if [ $dd -eq "1" ] ; then
			command="${command} -dd"
		fi
		if [ $tp -ne "443" ] ; then
		 	command="${command} -tp ${tp}"
		fi
	else
		command="${command} -httping-code 200 -tl 200 -tll 40 -n 200 -t 4 -dt 10 -dn 2"
	fi
	
	ssr_original_server=$(uci get shadowsocksr.@global[0].global_server 2>/dev/null)
	ssr_original_run_mode=$(uci get shadowsocksr.@global[0].run_mode 2>/dev/null)
	if [ $ssr_original_server != "nil" ] ;then
		if [ $proxy_mode  == "close" ] ;then
			uci set shadowsocksr.@global[0].global_server="nil"			
		elif  [ $proxy_mode  == "gfw" ] ;then
			uci set shadowsocksr.@global[0].run_mode="gfw"
		fi
		uci commit shadowsocksr
		/etc/init.d/shadowsocksr restart 2>/dev/null
	fi

	xray_core_server_enabled=$(uci get xray_core.@general[0].main_server 2>/dev/null)
	xray_original_run_mode=$(uci get xray_core.@general[0].forwarded_domain_rules 2>/dev/null)
	if [ $xray_core_server_enabled != "disabled" ] ;then
		if [ $proxy_mode  == "close" ] ;then
			uci set xray_core.@general[0].main_server="disabled"			
		elif  [ $proxy_mode  == "gfw" ] ;then
			uci set xray_core.@general[0].forwarded_domain_rules="geosite:gfw"
		fi
		uci commit xray_core
		/etc/init.d/xray_core restart 2>/dev/null
	fi

	v2ray_server_enabled=$(uci get v2ray.@v2ray[0].enabled 2>/dev/null)
	v2ray_original_run_mode=$(uci get v2ray.@transparent_proxy[0].proxy_mode 2>/dev/null)
	if [ $v2ray_server_enabled -eq "1" ] ;then
		if [ $proxy_mode  == "close" ] ;then
			uci set v2ray.@v2ray[0].enabled="0"			
		elif  [ $proxy_mode  == "gfw" ] ;then
			uci set v2ray.@transparent_proxy[0].proxy_mode="gfwlist_proxy"
		fi
		uci commit v2ray
		/etc/init.d/v2ray restart 2>/dev/null
	fi

	passwall_server_enabled=$(uci get passwall.@global[0].enabled 2>/dev/null)
	# passwall_original_run_mode=$(uci get passwall.@global[0].tcp_proxy_mode 2>/dev/null)
	passwall_original_run_mode="proxy"
	if [ $passwall_server_enabled -eq "1" ] ;then
		if [ $proxy_mode  == "close" ] ;then
			uci set passwall.@global[0].enabled="0"			
		elif  [ $proxy_mode  == "gfw" ] ;then
			uci set passwall.@global[0].tcp_proxy_mode="disable"
   			uci set passwall.@global[0].udp_proxy_mode="disable"
		fi
		uci commit passwall
		/etc/init.d/passwall  restart 2>/dev/null
	fi

	passwall2_server_enabled=$(uci get passwall2.@global[0].enabled 2>/dev/null)
	passwall2_original_run_mode=$(uci get passwall2.@global[0].tcp_proxy_mode 2>/dev/null)
	if [ $passwall2_server_enabled -eq "1" ] ;then
		if [ $proxy_mode  == "close" ] ;then
			uci set passwall2.@global[0].enabled="0"			
		elif  [ $proxy_mode  == "gfw" ] ;then
			uci set passwall2.@global[0].tcp_proxy_mode="gfwlist"
			uci set passwall2.@global[0].udp_proxy_mode="gfwlist"
		fi
		uci commit passwall2
		/etc/init.d/passwall2 restart 2>/dev/null
	fi
	
	bypass_original_server=$(uci get bypass.@global[0].global_server 2>/dev/null)
	bypass_original_run_mode=$(uci get bypass.@global[0].run_mode 2>/dev/null)
	if [ $bypass_original_server != "$bypass_key_table" ] ;then
		if [ $proxy_mode  == "close" ] ;then
			uci set bypass.@global[0].global_server="$bypass_key_table"			
		elif  [ $proxy_mode  == "gfw" ] ;then
			uci set bypass.@global[0].run_mode="gfw"
		fi
		uci commit bypass
		/etc/init.d/bypass restart 2>/dev/null
	fi
	
	vssr_original_server=$(uci get vssr.@global[0].global_server 2>/dev/null)
	vssr_original_run_mode=$(uci get vssr.@global[0].run_mode 2>/dev/null)
	if [ $vssr_original_server != "nil" ] ;then
		if [ $proxy_mode  == "close" ] ;then
			uci set vssr.@global[0].global_server="nil"		
		elif  [ $proxy_mode  == "gfw" ] ;then
			uci set vssr.@global[0].run_mode="gfw"
		fi
		uci commit vssr
		/etc/init.d/vssr restart 2>/dev/null
	fi
	
	shadowsocks_server_disabled=$(uci get shadowsocks-libev.@server[0].disabled 2>/dev/null)
	shadowsocks_original_run_mode=$(uci get shadowsocks-libev.@ss_rules[0].disabled 2>/dev/null)
	if [ $shadowsocks_server_disabled -eq "0" ] ;then
		if [ $proxy_mode  == "close" ] ;then
			uci set shadowsocks-libev.@server[0].disabled="1"		
		elif  [ $proxy_mode  == "gfw" ] ;then
			uci set shadowsocks-libev.@ss_rules[0].disabled="0"
		fi
		uci commit shadowsocks-libev
		/etc/init.d/shadowsocks-libev restart 2>/dev/null
	fi
		
	echo $command  >> $LOG_FILE 2>&1 
	echolog "-----------start----------" 
	$command >> $LOG_FILE 2>&1
	echolog "-----------end------------"
}

function ip_replace(){

	# 获取最快 IP（从 result.csv 结果文件中获取第一个 IP）
	bestip=$(sed -n "2,1p" $IP_FILE | awk -F, '{print $1}')
	[[ -z "${bestip}" ]] && echo "CloudflareST 测速结果 IP 数量为 0，跳过下面步骤..." && exit 0

	alidns_ip

	ssr_best_ip

	xray_best_ip

	v2ray_best_ip
	
	vssr_best_ip

	bypass_best_ip

	passwall_best_ip

	passwall2_best_ip
	
	shadowsocks_best_ip
	
	host_ip

}

function passwall_best_ip(){
	if [ $passwall_server_enabled -eq '1' ] ; then
		echolog "设置passwall代理模式"
		if [ $proxy_mode  == "close" ] ;then
			uci set passwall.@global[0].enabled="${passwall_server_enabled}"		
		elif [ $proxy_mode  == "gfw" ] ;then
			uci set passwall.@global[0].tcp_proxy_mode="${passwall_original_run_mode}"
   			uci set passwall.@global[0].udp_proxy_mode="${passwall_original_run_mode}"
		fi	
		uci commit passwall
	fi

	if [ $passwall_enabled -eq "1" ] ;then
		echolog "设置passwall IP"
		for ssrname in $passwall_services
		do
			echo $ssrname
			uci set passwall.$ssrname.address="${bestip}"
		done
		uci commit passwall
 		if [ $passwall_server_enabled -eq "1" ] ;then
			/etc/init.d/passwall restart 2>/dev/null
			echolog "passwall重启完成"
		fi
	fi
}

function passwall2_best_ip(){
	if [ $passwall2_server_enabled -eq '1' ] ; then
		echolog "设置passwall2代理模式"
		if [ $proxy_mode  == "close" ] ;then
			uci set passwall2.@global[0].enabled="${passwall2_server_enabled}"		
		 elif [ $proxy_mode  == "gfw" ] ;then
		 	uci set passwall2.@global[0].tcp_proxy_mode="${passwall2_original_run_mode}"
			uci set passwall2.@global[0].udp_proxy_mode="${passwall2_original_run_mode}"
		fi	
		uci commit passwall2
	fi

	if [ $passwall2_enabled -eq "1" ] ;then
		echolog "设置passwall2 IP"
		for ssrname in $passwall2_services
		do
			echo $ssrname
			uci set passwall2.$ssrname.address="${bestip}"
		done
		uci commit passwall2
 		if [ $passwall2_server_enabled -eq "1" ] ;then
			/etc/init.d/passwall2 restart 2>/dev/null
			echolog "passwall2重启完成"
		fi
	fi
}

function ssr_best_ip(){
	if [ $ssr_enabled -eq "1" ] ;then
		echolog "设置ssr IP"
		for ssrname in $ssr_services
		do
			echo $ssrname
			uci set shadowsocksr.$ssrname.server="${bestip}"
			uci set shadowsocksr.$ssrname.ip="${bestip}"
		done
		uci commit shadowsocksr
		 	
	fi

	if [ $ssr_original_server != 'nil' ] ; then
		echolog "设置ssr代理模式"
		if [ $proxy_mode  == "close" ] ;then
			uci set shadowsocksr.@global[0].global_server="${ssr_original_server}"		
		elif [ $proxy_mode  == "gfw" ] ;then
			uci set  shadowsocksr.@global[0].run_mode="${ssr_original_run_mode}"
		fi	
		uci commit shadowsocksr
		/etc/init.d/shadowsocksr restart 2 >/dev/null
		echolog "ssr重启完成"
	fi
}

function xray_best_ip(){
	if [ $xray_core_server_enabled != 'disabled' ] ; then
		echolog "设置xray代理模式"
		if [ $proxy_mode  == "close" ] ;then
			uci set xray_core.@general[0].main_server="${xray_core_server_enabled}"		
		elif [ $proxy_mode  == "gfw" ] ;then
			uci set xray_core.@general[0].forwarded_domain_rules="${xray_original_run_mode}"
		fi	
		uci commit xray_core
	fi

	if [ $xray_core_enabled -eq "1" ] ;then
		echolog "设置Xray IP"
		for ssrname in $xray_core_services
		do
			echo $ssrname
			uci set xray_core.$ssrname.server="${bestip}"
		done
		uci commit xray_core
 		if [ $xray_core_server_enabled != "disabled" ] ;then
			/etc/init.d/xray_core restart 2>/dev/null
			echolog "Xray重启完成"
		fi
	fi
}

function v2ray_best_ip(){
	if [ $v2ray_server_enabled -eq '1' ] ; then
		echolog "设置V2ray代理模式"
		if [ $proxy_mode  == "close" ] ;then
			uci set v2ray.@v2ray[0].enabled="${v2ray_server_enabled}"		
		elif [ $proxy_mode  == "gfw" ] ;then
			uci set v2ray.@transparent_proxy[0].proxy_mode="${v2ray_original_run_mode}"
		fi	
		uci commit v2ray
	fi

	if [ $v2ray_enabled -eq "1" ] ;then
		echolog "设置V2ray IP"
		for ssrname in $v2ray_services
		do
		if [ -n `uci get v2ray.@outbound[0].s_vmess_address` ] && [ -n `uci get v2ray.@outbound[0].s_vless_address` ];then
			echo $ssrname
			uci set v2ray.$ssrname.s_vless_address="${bestip}"
			uci set v2ray.$ssrname.s_vmess_address="${bestip}"
		elif [ -n `uci get v2ray.@outbound[0].s_vmess_address` ];then
			echo $ssrname
			uci set v2ray.$ssrname.s_vmess_address="${bestip}"
		elif [ -n `uci get v2ray.@outbound[0].s_vless_address` ];then
			echo $ssrname
			uci set v2ray.$ssrname.s_vless_address="${bestip}"
		fi
		done
		uci commit v2ray
 		if [ $v2ray_server_enabled -eq "1" ] ;then
			/etc/init.d/v2ray restart 2>/dev/null
			echolog "V2ray重启完成"
		fi
	fi
}


function vssr_best_ip(){
	if [ $vssr_enabled -eq "1" ] ;then
		echolog "设置Vssr IP"
		for ssrname in $vssr_services
		do
			echo $ssrname
			uci set vssr.$ssrname.server="${bestip}"
		done
		uci commit vssr
		 	
	fi

	if [ $vssr_original_server != 'nil' ] ; then
		echolog "设置Vssr代理模式"
		if [ $proxy_mode  == "close" ] ;then
			uci set vssr.@global[0].global_server="${vssr_original_server}"		
		elif [ $proxy_mode  == "gfw" ] ;then
			uci set vssr.@global[0].run_mode="${vssr_original_run_mode}"
		fi	
		uci commit vssr
		/etc/init.d/vssr restart 2 >/dev/null
		echolog "Vssr重启完成"
	fi
}

function bypass_best_ip(){
	if [ $bypass_enabled -eq "1" ] ;then
		echolog "设置Bypass IP"
		for ssrname in $bypass_services
		do
			echo $ssrname
			uci set bypass.$ssrname.server="${bestip}"
		done
		uci commit bypass

	fi

	if [ $bypass_original_server != '$bypass_key_table' ] ; then
		echolog "设置Bypass代理模式"
		if [ $proxy_mode  == "close" ] ;then
			uci set bypass.@global[0].global_server="${bypass_original_server}"		
		elif [ $proxy_mode  == "gfw" ] ;then
			uci set  bypass.@global[0].run_mode="${bypass_original_run_mode}"
		fi	
		uci commit bypass
		/etc/init.d/bypass restart 2 >/dev/null
		echolog "Bypass重启完成"
	fi
}

function shadowsocks_best_ip(){

	count=`ps | grep ss-local | grep -v grep | wc -l`
	if [ $count -ge "1" ];then
		uci set shadowsocks-libev.@server[0].disabled="0"
		uci commit shadowsocks-libev
		/etc/init.d/shadowsocks-libev restart 2>/dev/null
	fi

	if [ $shadowsocks_server_disabled -eq '0' ] ; then
		echolog "设置Shadowsocks-libev代理模式"
		if [ $proxy_mode  == "close" ] ;then
			uci set shadowsocks-libev.@server[0].disabled="1"		
		elif [ $proxy_mode  == "gfw" ] ;then
			uci set shadowsocks-libev.@ss_rules[0].disabled="${shadowsocks_original_run_mode}"
		fi	
		uci commit shadowsocks-libev
	fi
	
	if [ $shadowsocks_enabled -eq "1" ] ;then
		echolog "设置Shadowsocks-libev IP"
		for ssrname in $shadowsocks_services
		do
			echo $ssrname
			uci set shadowsocks-libev.$ssrname.server="${bestip}"
			# uci set shadowsocks-libev.$ssrname.ip="${bestip}"
		done
		uci commit shadowsocks-libev
		if [ $shadowsocks_server_enabled -eq "0" ] ;then
			/etc/init.d/shadowsocks-libev restart 2>/dev/null
			echolog "Shadowsocks-libev重启完成"
		fi
	fi


}

function alidns_ip(){
	if [ $DNS_enabled -eq "1" ] ;then
		get_servers_config "DNS_type" "app_key" "app_secret" "main_domain" "sub_domain" "line"
		if [ $DNS_type == "aliyu" ] ;then
			/usr/bin/cloudflarespeedtest/aliddns.sh $app_key $app_secret $main_domain $sub_domain $line $ipv6_enabled $bestip
			echolog "更新阿里云DNS完成"
		fi		
	fi
}

function host_ip() {
        if [ "x${HOST_enabled}" == "x1" ] ;then
            get_servers_config "host_domain"
            HOSTS_LINE=$(echo "$host_domain" | sed 's/,/ /g' | sed "s/^/$bestip /g")
            host_domain_first=$(echo "$host_domain" | awk -F, '{print $1}')

            if [ -n "$(grep $host_domain_first /etc/hosts)" ]
            then
                echo $host_domain_first
                sed -i".bak" "/$host_domain_first/d" /etc/hosts
                echo $HOSTS_LINE >> /etc/hosts;
            else
            echo $HOSTS_LINE >> /etc/hosts;
            fi
            /etc/init.d/dnsmasq reload &>/dev/null
            echolog "HOST 完成"
        fi
}
read_config

# 启动参数
if [ "$1" ] ;then
	[ $1 == "start" ] && speed_test && ip_replace
	[ $1 == "test" ] && speed_test
	[ $1 == "replace" ] && ip_replace
	exit
fi
