#!/bin/sh
LOG_PIPE=log.pipe
rm -f LOG_PIPE
mkfifo ${LOG_PIPE}
LOG_FILE=log.file
rm -f LOG_FILE
tee < ${LOG_PIPE} ${LOG_FILE} &

exec  > ${LOG_PIPE}
exec  2> ${LOG_PIPE}


Infon() {
	printf "\033[1;32m$@\033[0m"
}
Info()
{
	Infon "$@\n"
}
Error()
{
	printf "\033[1;31m$@\033[0m\n"
}
Error_n()
{
	Error "- - - $@"
}
Error_s()
{
	Error "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - "
}
log_s()
{
	Info "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - "
}
log_n()
{
	Info "- - - $@"
}
log_t()
{
	log_s
	Info "- - - $@"
	log_s
}
install_allpack()
{
read -p "Вы уверены что хотите установить все пакеты? y/n " Uver
if [ $Uver = "y" ]; then
	install_base
	install_fastdl "1"
	install_fastdl "2"
	install_ftp
	install_java
	menu
else
	menu
fi
}
install_gamepl()
{
	Info "This skript installed GamePL"
	read -p "Please write your domain: " DOMAIN
	log_t "Start Install GamePL"
	log_t "Update"
	apt-get update
	log_t "Install packages"
	apt-get install -y apt-utils
	apt-get install -y pwgen
	apt-get install -y dialog
	MYPASS=$(pwgen -cns -1 20)
	MYPASS2=$(pwgen -cns -1 20)
	OS=$(lsb_release -s -i -c -r | xargs echo |sed 's; ;-;g' | grep Ubuntu)
	if [ "$OS" = "" ]; then
		log_t "Add repository"
		echo "deb http://packages.dotdeb.org wheezy-php55 all">"/etc/apt/sources.list.d/dotdeb.list"
		echo "deb-src http://packages.dotdeb.org wheezy-php55 all">>"/etc/apt/sources.list.d/dotdeb.list"
		wget http://www.dotdeb.org/dotdeb.gpg
		apt-key add dotdeb.gpg
		rm dotdeb.gpg
		log_t "Update"
		apt-get update
	fi
	log_t "Upgrade"
	apt-get upgrade -y
	echo mysql-server mysql-server/root_password select "$MYPASS" | debconf-set-selections
	echo mysql-server mysql-server/root_password_again select "$MYPASS" | debconf-set-selections
	log_t "Install packages"
	apt-get install -y apache2 php5 php5-dev cron unzip sudo php5-curl php5-memcache php5-json memcached mysql-server libapache2-mod-php5
	if [ "$OS" = "" ]; then
		apt-get install -y php5-ssh2
	else
		apt-get install -y  libssh2-php
	fi
	echo "phpmyadmin phpmyadmin/dbconfig-install boolean true" | debconf-set-selections
	echo "phpmyadmin phpmyadmin/mysql/admin-user string root" | debconf-set-selections
	echo "phpmyadmin phpmyadmin/mysql/admin-pass password $MYPASS" | debconf-set-selections
	echo "phpmyadmin phpmyadmin/mysql/app-pass password $MYPASS" |debconf-set-selections
	echo "phpmyadmin phpmyadmin/app-password-confirm password $MYPASS" | debconf-set-selections
	echo 'phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2' | debconf-set-selections
	apt-get install -y phpmyadmin
	STRING=$(apache2 -v | grep Apache/2.4)
	if [ "$STRING" = "" ]; then
		FILE='/etc/apache2/conf.d/gamepl'
		echo "<VirtualHost *:80>">$FILE
		echo "ServerName $DOMAIN">>$FILE
		echo "DocumentRoot /var/gamepl">>$FILE
		echo "<Directory /var/gamepl/>">>$FILE
		echo "Options Indexes FollowSymLinks MultiViews">>$FILE
		echo "AllowOverride All">>$FILE
		echo "Order allow,deny">>$FILE
		echo "allow from all">>$FILE
		echo "</Directory>">>$FILE
		echo "ErrorLog \${APACHE_LOG_DIR}/error.log">>$FILE
		echo "LogLevel warn">>$FILE
		echo "CustomLog \${APACHE_LOG_DIR}/access.log combined">>$FILE
		echo "</VirtualHost>">>$FILE
	else
		FILE='/etc/apache2/conf-enabled/gamepl.conf'
		cd /etc/apache2/sites-available
		sed -i "/Listen 80/d" *
		cd ~
		echo "Listen 80">$FILE
		echo "<VirtualHost *:80>">$FILE
		echo "ServerName $DOMAIN">>$FILE
		echo "DocumentRoot /var/gamepl">>$FILE
		echo "<Directory /var/gamepl/>">>$FILE
		echo "AllowOverride All">>$FILE
		echo "Require all granted">>$FILE
		echo "</Directory>">>$FILE
		echo "ErrorLog \${APACHE_LOG_DIR}/error.log">>$FILE
		echo "LogLevel warn">>$FILE
		echo "CustomLog \${APACHE_LOG_DIR}/access.log combined">>$FILE
		echo "</VirtualHost>">>$FILE
	fi
	log_t "Enable modules Apache2"
	a2enmod rewrite
	a2enmod php5
	log_t "Install Ioncube"
	wget http://downloads3.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64.zip
	unzip ioncube_loaders_lin_x86-64.zip
	cp ioncube/ioncube_loader_lin_5.5.so /usr/lib/php5/20121212/ioncube_loader_lin_5.5.so
	rm -R ioncube*
	echo "zend_extension=ioncube_loader_lin_5.5.so">>"/etc/php5/apache2/php.ini"
	echo "zend_extension=ioncube_loader_lin_5.5.so">>"/etc/php5/cli/php.ini"
	(crontab -l ; echo "*/5 * * * * cd /var/gamepl/;php5 cron.php") 2>&1 | grep -v "no crontab" | sort | uniq | crontab -
	chown root:crontab /var/spool/cron/crontabs/root
	log_t "Service restart"
	service cron restart
	service apache2 restart
	log_t "install GamePL to dir /var/gamepl"
	cd ~
	mkdir /var/gamepl/
	cd /var/
	wget http://dl.flaminggaming.ru/gamepl.tgz
	tar -xvf gamepl.tgz
	rm -r gamepl.tgz
	cd /var/gamepl/data/
	echo '{"domain":"kinghost.net.ru","title":"Хостинг игровых серверов","mail_type":"aviras","smtp_server":"ssl:\/\/smtp.yandex.ru","smtp_port":"465","smtp_mail":"info@game-panel.ru","mail":"info@game-panel.ru","smtp_pass":null,"db_users_host":"127.0.0.1","db_users_name":"gamepl","db_users_user":"root","db_users_pass":"89534012","m_ip":"127.0.0.1","m_port":"11211","tpl":2,"key":null,"curs":"1","curs-name":"руб","lang":"ru","keywords":"","description":"","mysql-price":null,"stats_profit":"","buy":"","vk_id":"","vk_key":"","dell":"","lang2":"0","signup":0,"sphone":0,"tpl2":0,"tpl3":0,"tpl4":0,"fprice":1,"wmr1":"","wmr2":"","yandex1":"","yandex2":"","rbc1":"","rbc2":"","rbc3":"","rbc4":"","unitpay_key":"","unitpay":"","sp1":"","sp2":"","nextpay":"","nextpay_key":"","waytopay":"","waytopay2":"","interkassa":"","interkassa2":"","interkassa3":"","qiwi":"","qiwi2":"","qiwi3":"","qiwi4":"","sms_signup":0,"sms_recovery":0,"sms_support":0,"sms_time_pre":0,"sms_time_end":0,"sms_time_del":0,"sms_boxes":0,"sms_payment":0,"sms_key":"","sms_phone_admin":"","smtp":{"server":"","port":"","mail":"","pass":""},"index":4,"index-page":0,"price":[{"day":"30","price1":3,"price2":0},{"day":"60","price1":5,"price2":0},{"day":"90","price1":7,"price2":0},{"day":"120","price1":9,"price2":0},{"day":"360","price1":10,"price2":0}]}' > conf.ini
	cd ~
	wget http://dl.flaminggaming.ru/gameplsqll.zip
	unzip gameplsqll.zip
	rm -r gameplsqll.zip
	mysql -uroot -p89534012 -e "CREATE DATABASE gamepl;"
	mysql -uroot -p89534012 gamepl < gamepl.sql
	rm -r gamepl.sql
	chown -R www-data:www-data /var/gamepl/
	chmod -R 770 /var/gamepl/
	log_t "End install GamePL"
		log_s
		log_n "GamePL installed!"
		log_n ""
		log_n "phpMyAdmin and MySQL:"
		log_n "Login: root"
		log_n "Password: 89534012"
		log_n ""
		log_n "Go to installed site: http://$DOMAIN"
		log_n "Go to phpMyAdmin: http://$DOMAIN/phpmyadmin"
		log_n ""
		log_n "Login and Password to enter the site:"
		log_n "Login: admin@serverpanel.ru"
		log_n "Password: fef558K8FOSRlYx3TlAM"
		log_n "#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#"
		log_n "Change E-Mail and Password!"
		log_n "#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#"
		log_s
	Info
	log_t "Welcome to installer GamePl v.7"
	Info "1  -  Configure machine to games"
	Info "2  -  Configure machine to games (All packets)"
	Info "3  -  Install Games"
	Info "0  -  Exit"
	Info
	read -p "Select menu number:" case
	case $case in
		1) configure_box;;   
		2) install_allpack;;
		3) install_games;;
		0) exit;;
	esac
}
install_mineallversion()
{
	clear
	Info
	log_t "List of versions"
	Info "- 1  - 1.12.1"
	Info "- 2  - 1.12"
	Info "- 3  - 1.11.2"
	Info "- 4  - 1.11.1"
	Info "- 5  - 1.11"
	Info "- 6  - 1.10.2"
	Info "- 7  - 1.10"
	Info "- 8  - 1.9.4"
	Info "- 9  - 1.9.2"
	Info "- 10  - 1.9"
	Info "- 11  - 1.8.8"
	Info "- 12  - 1.8.7"
	Info "- 13  - 1.8.6"
	Info "- 14  - 1.8.5"
	Info "- 15  - 1.8.4"
	Info "- 16  - 1.8.3"
	Info "- 17  - 1.8"
	Info "- 18  - 1.7.10"
	Info "- 19  - 1.7.9"
	Info "- 20  - 1.7.8"
	Info "- 21  - 1.7.5"
	Info "- 22  - 1.7.2"
	Info "- 23  - 1.6.4"
	Info "- 24  - 1.6.2"
	Info "- 25  - 1.6.1"
	Info "- 26  - 1.5.2"
	Info "- 27  - 1.5.1"
	Info "- 28  - 1.5"
	Info "- 29  - 1.4.7"
	Info "- 30  - 1.4.6"
	Info "- 31  - 1.4.5"
	Info "- 32  - 1.4.2"
	Info "- 33  - 1.3.2"
	Info "- 34  - 1.3.1"
	Info "- 35  - 1.2.5"
	Info "- 36  - 1.2.4"
	Info "- 37  - 1.2.3"
	Info "- 38  - 1.2.2"
	Info "- 39  - 1.1"
	Info "- 40  - 1.0.0"
	Info "- 0  -  Back"
	log_s
	Info
	read -p "Pleas select number: " case
	case $case in
		1)
		mkdir /host/servers/mine1121/
		cd /host/servers/mine1121/
		wget http://dl.flaminggaming.ru/mc/craftbukkit-1.12.1.jar
		install_games
		;;
		2)
		mkdir /host/servers/mine112/
		cd /host/servers/mine112/
		wget http://dl.flaminggaming.ru/mc/craftbukkit-1.12.jar
		install_games
		;;
		3)
		mkdir /host/servers/mine1112/
		cd /host/servers/mine1112/
		wget http://dl.flaminggaming.ru/mc/craftbukkit-1.11.2.jar
		install_games
		;;
		4)
		mkdir /host/servers/mine1111/
		cd /host/servers/mine1111/
		wget http://dl.flaminggaming.ru/mc/craftbukkit-1.11.1.jar
		install_games
		;;
		5)
		mkdir /host/servers/mine111/
		cd /host/servers/mine111/
		wget http://dl.flaminggaming.ru/mc/craftbukkit-1.11.jar
		install_games
		;;
		6)
		mkdir /host/servers/mine1102/
		cd /host/servers/mine1102/
		wget http://dl.flaminggaming.ru/mc/craftbukkit-1.10.2-R0.1-SNAPSHOT-latest.jar
		install_games
		;;
		7)
		mkdir /host/servers/mine110/
		cd /host/servers/mine110/
		wget http://dl.flaminggaming.ru/mc/craftbukkit-1.10-R0.1-SNAPSHOT-latest.jar
		install_games
		;;
		8)
		mkdir /host/servers/mine194/
		cd /host/servers/mine194/
		wget http://dl.flaminggaming.ru/mc/craftbukkit-1.9.4-R0.1-SNAPSHOT-latest.jar
		install_games
		;;
		9)
		mkdir /host/servers/mine192/
		cd /host/servers/mine192/
		wget http://dl.flaminggaming.ru/mc/craftbukkit-1.9.2-R0.1-SNAPSHOT-latest.jar
		install_games
		;;
		10)
		mkdir /host/servers/mine19/
		cd /host/servers/mine19/
		wget http://dl.flaminggaming.ru/mc/craftbukkit-1.9-R0.1-SNAPSHOT-latest.jar
		install_games
		;;
		11)
		mkdir /host/servers/mine188/
		cd /host/servers/mine188/
		wget http://dl.flaminggaming.ru/mc/craftbukkit-1.8.8-R0.1-SNAPSHOT-latest.jar
		install_games
		;;
		12)
		mkdir /host/servers/mine187/
		cd /host/servers/mine187/
		wget http://dl.flaminggaming.ru/mc/craftbukkit-1.8.7-R0.1-SNAPSHOT-latest.jar
		install_games
		;;
		13)
		mkdir /host/servers/mine186/
		cd /host/servers/mine186/
		wget http://dl.flaminggaming.ru/mc/craftbukkit-1.8.6-R0.1-SNAPSHOT-latest.jar
		install_games
		;;
		14)
		mkdir /host/servers/mine185/
		cd /host/servers/mine185/
		wget http://dl.flaminggaming.ru/mc/craftbukkit-1.8.5-R0.1-SNAPSHOT-latest.jar
		install_games
		;;
		15)
		mkdir /host/servers/mine184/
		cd /host/servers/mine184/
		wget http://dl.flaminggaming.ru/mc/craftbukkit-1.8.4-R0.1-SNAPSHOT-latest.jar
		install_games
		;;
		16)
		mkdir /host/servers/mine183/
		cd /host/servers/mine183/
		wget http://dl.flaminggaming.ru/mc/craftbukkit-1.8.3-R0.1-SNAPSHOT-latest.jar
		install_games
		;;
		17)
		mkdir /host/servers/mine18/
		cd /host/servers/mine18/
		wget http://dl.flaminggaming.ru/mc/craftbukkit-1.8-R0.1-SNAPSHOT-latest.jar
		install_games
		;;
		18)
		mkdir /host/servers/mine1710/
		cd /host/servers/mine1710/
		wget http://dl.flaminggaming.ru/mc/craftbukkit-1.7.10-R0.1-20140808.005431-8.jar
		install_games
		;;
		19)
		mkdir /host/servers/mine179/
		cd /host/servers/mine179/
		wget http://dl.flaminggaming.ru/mc/craftbukkit-1.7.9-R0.2-SNAPSHOT.jar
		install_games
		;;
		20)
		mkdir /host/servers/mine178/
		cd /host/servers/mine178/
		wget http://dl.flaminggaming.ru/mc/craftbukkit-1.7.8-R0.1-SNAPSHOT.jar
		install_games
		;;
		21)
		mkdir /host/servers/mine175/
		cd /host/servers/mine175/
		wget http://dl.flaminggaming.ru/mc/craftbukkit-1.7.5-R0.1-20140402.020013-12.jar
		install_games
		;;
		22)
		mkdir /host/servers/mine172/
		cd /host/servers/mine172/
		wget http://dl.flaminggaming.ru/mc/craftbukkit-1.7.2-R0.4-20140216.012104-3.jar
		install_games
		;;
		23)
		mkdir /host/servers/mine164/
		cd /host/servers/mine164/
		wget http://dl.flaminggaming.ru/mc/craftbukkit-1.6.4-R2.0.jar
		install_games
		;;
		24)
		mkdir /host/servers/mine162/
		cd /host/servers/mine162/
		wget http://dl.flaminggaming.ru/mc/craftbukkit-1.6.2-R0.1-SNAPSHOT.jar
		install_games
		;;
		25)
		mkdir /host/servers/mine161/
		cd /host/servers/mine161/
		wget http://dl.flaminggaming.ru/mc/craftbukkit-1.6.1-R0.1-SNAPSHOT.jar
		install_games
		;;
		26)
		mkdir /host/servers/mine152/
		cd /host/servers/mine152/
		wget http://dl.flaminggaming.ru/mc/craftbukkit-1.5.2-R1.0.jar
		install_games
		;;
		27)
		mkdir /host/servers/mine151/
		cd /host/servers/mine151/
		wget http://dl.flaminggaming.ru/mc/craftbukkit-1.5.1-R0.2-SNAPSHOT.jar
		install_games
		;;
		28)
		mkdir /host/servers/mine15/
		cd /host/servers/mine15/
		wget http://dl.flaminggaming.ru/mc/craftbukkit-1.5-R0.1-20130317.180842-21.jar
		install_games
		;;
		29)
		mkdir /host/servers/mine147/
		cd /host/servers/mine147/
		wget http://dl.flaminggaming.ru/mc/craftbukkit-1.4.7-R1.1-SNAPSHOT.jar
		install_games
		;;
		30)
		mkdir /host/servers/mine146/
		cd /host/servers/mine146/
		wget http://dl.flaminggaming.ru/mc/craftbukkit-1.4.6-R0.4-SNAPSHOT.jar
		install_games
		;;
		31)
		mkdir /host/servers/mine145/
		cd /host/servers/mine145/
		wget http://dl.flaminggaming.ru/mc/craftbukkit-1.4.5-R1.1-SNAPSHOT.jar
		install_games
		;;
		32)
		mkdir /host/servers/mine142/
		cd /host/servers/mine142/
		wget http://dl.flaminggaming.ru/mc/craftbukkit-1.4.2-R0.3-SNAPSHOT.jar
		install_games
		;;
		33)
		mkdir /host/servers/mine132/
		cd /host/servers/mine132/
		wget http://dl.flaminggaming.ru/mc/craftbukkit-1.3.2-R2.1-SNAPSHOT.jar
		install_games
		;;
		34)
		mkdir /host/servers/mine131/
		cd /host/servers/mine131/
		wget http://dl.flaminggaming.ru/mc/craftbukkit-1.3.1-R2.1-SNAPSHOT.jar
		install_games
		;;
		35)
		mkdir /host/servers/mine125/
		cd /host/servers/mine125/
		wget http://dl.flaminggaming.ru/mc/craftbukkit-1.2.5-R5.1-SNAPSHOT.jar
		install_games
		;;
		36)
		mkdir /host/servers/mine124/
		cd /host/servers/mine124/
		wget http://dl.flaminggaming.ru/mc/craftbukkit-1.2.4-R1.1-SNAPSHOT.jar
		install_games
		;;
		37)
		mkdir /host/servers/mine123/
		cd /host/servers/mine123/
		wget http://dl.flaminggaming.ru/mc/craftbukkit-1.2.3-R0.3-SNAPSHOT.jar
		install_games
		;;
		38)
		mkdir /host/servers/mine122/
		cd /host/servers/mine122/
		wget http://dl.flaminggaming.ru/mc/craftbukkit-1.2.2-R0.1-SNAPSHOT.jar
		install_games
		;;
		39)
		mkdir /host/servers/mine11/
		cd /host/servers/mine11/
		wget http://dl.flaminggaming.ru/mc/craftbukkit-1.1-R5-SNAPSHOT.jar
		install_games
		;;
		40)
		mkdir /host/servers/mine100/
		cd /host/servers/mine100/
		wget http://dl.flaminggaming.ru/mc/craftbukkit-1.0.0-SNAPSHOT.jar
		install_games
		;;
		0)
		install_games
		;;
	esac
}
install_games()
{
	upd
	clear
	Info
	log_t "List of Games"
	Info "- 1  -  Install SteamCMD"
	Info "- 2  -  Counter-Strike: 1.6"
	Info "- 3  -  Counter-Strike: Source"
	Info "- 4  -  Counter-Strike: Source v34"
	Info "- 5  -  Counter-Strike: GO"
	Info "- 6  -  Half-Life: Deathmatch"
	Info "- 7  -  Day of Defeat: Source"
	Info "- 8  -  Team Fortress 2"
	Info "- 9  -  Garry's Mod"
	Info "- 10 -  Left 4 Dead 2"
	Info "- 11 -  Minecraft [All versions]"
	Info "- 12 -  Killing Floor"
	Info "- 13 -  GTA: Multi Theft Auto"
	Info "- 14 -  GTA: San Andreas Multiplayer"
	Info "- 15 -  GTA: Criminal Russia MP"
    Info "- 16 -  ARK: Survival Evolved Dedicated Server (Beta)"
	Info "- 0  -  Go to main menu"
	log_s
	Info
	read -p "Please select menu number: " case
	case $case in
		1) 
			mkdir -p /host/
			mkdir -p /host/servers
			mkdir -p /host/servers/cmd
			cd /host/servers/cmd/
			wget http://media.steampowered.com/client/steamcmd_linux.tar.gz
			tar xvzf steamcmd_linux.tar.gz
			rm steamcmd_linux.tar.gz
			install_games
		;;   
		2)
			cd /host/servers/cmd/
			./steamcmd.sh +login anonymous +force_install_dir /host/servers/cs/ +app_update 90 validate +quit
			install_games
		;;
		3)
			cd /host/servers/cmd/
			./steamcmd.sh +login anonymous +force_install_dir /host/servers/css/ +app_update 232330 validate +quit
			install_games
		;;
		4)
			apt-get install -y zip unzip
			mkdir /host/servers/css34/
			cd /host/servers/css34/
			wget http://dl.flaminggaming.ru/css34/css.zip
			unzip css.zip
			rm css.zip
			install_games
			
		;;
		5)
			cd /host/servers/cmd/
			./steamcmd.sh +login anonymous +force_install_dir /host/servers/csgo/ +app_update 740 validate +quit
			install_games
		;;
		6)
			cd /host/servers/cmd/
			./steamcmd.sh +login anonymous +force_install_dir /host/servers/hldm/ +app_update 232370 validate +quit
			install_games
		;;
		7)
			cd /host/servers/cmd/
			./steamcmd.sh +login anonymous +force_install_dir /host/servers/dods/ +app_update 232290 validate +quit
			install_games
		;;
		8)
			cd /host/servers/cmd/
			./steamcmd.sh +login anonymous +force_install_dir /host/servers/tf2/ +app_update 232250 validate +quit
			install_games
		;;
		9)
			cd /host/servers/cmd/
			./steamcmd.sh +login anonymous +force_install_dir /host/servers/gm/ +app_update 4020 validate +quit
			install_games
		;;
		10)
			cd /host/servers/cmd/
			./steamcmd.sh +login anonymous +force_install_dir /host/servers/l4d2/ +app_update 222860 validate +quit
			install_games
		;;
		11)
			install_mineallversion
		;;
		12)
			cd /host/servers/cmd/
			./steamcmd.sh +login anonymous +force_install_dir /host/servers/kf/ +app_update 215360 validate +quit
			install_games
		;;
		13)
			mkdir /host/servers/mta/
			cd /host/servers/mta/
			wget http://dl.flaminggaming.ru/gta/mta.tar
			tar -xvf mta.tar
			rm mta.tar
			install_games
		;;
		14)
			mkdir /host/servers/samp/
			cd /host/servers/samp/
			wget http://dl.flaminggaming.ru/gta/samp.tar
			tar -xvf samp.tar
			rm samp.tar
			install_games
		;;
		15)
			mkdir /host/servers/crmp/
			cd /host/servers/crmp/
			wget http://dl.flaminggaming.ru/gta/crmp.tar
			tar -xvf crmp.tar
			rm crmp.tar
			install_games
		;;
		16)
			 cd /host/servers/cmd/
			 ./steamcmd.sh +login anonymous +force_install_dir /host/servers/ark_seds/ +app_update 376030 validate +quit
			 install_games
		 ;;
		0) menu;;
	esac
}
install_fastdl()
{
	if [ "$@" = "1" ]; then
		apt-get install -y apache2-mpm-itk php5
		STRING=$(apache2 -v | grep Apache/2.4)
		mkdir /etc/apache2/fastdl
		if [ "$STRING" = "" ]; then
			echo "Include /etc/apache2/fastdl/*.conf">>"/etc/apache2/apache2.conf"
		else
			echo "IncludeOptional fastdl/*.conf">>"/etc/apache2/apache2.conf"
		fi
		service apache2 restart
	else
		apt-get install -y nginx
		mkdir /etc/nginx/fastdl
		echo "server {">"/etc/nginx/sites-enabled/fastdl.conf"
		echo "listen 80 default;">>"/etc/nginx/sites-enabled/fastdl.conf"
		echo "include /etc/nginx/fastdl/*;">>"/etc/nginx/sites-enabled/fastdl.conf"
		echo "}">>"/etc/nginx/sites-enabled/fastdl.conf"
		sed -i 's/user www-data;/user root;/g' "/etc/nginx/nginx.conf"
		service nginx restart
	fi
}
install_ftp()
{
	apt-get install -y pure-ftpd-common pure-ftpd
	echo "yes" > /etc/pure-ftpd/conf/CreateHomeDir
	echo "yes" > /etc/pure-ftpd/conf/NoAnonymous
	echo "yes" > /etc/pure-ftpd/conf/ChrootEveryone
	echo "yes" > /etc/pure-ftpd/conf/VerboseLog
	echo "yes" > /etc/pure-ftpd/conf/IPV4Only
	echo "100" > /etc/pure-ftpd/conf/MaxClientsNumber
	echo "8" > /etc/pure-ftpd/conf/MaxClientsPerIP
	echo "no" > /etc/pure-ftpd/conf/DisplayDotFiles 
	echo "15" > /etc/pure-ftpd/conf/MaxIdleTime
	echo "16" > /etc/pure-ftpd/conf/MaxLoad
	echo "50000 50300" > /etc/pure-ftpd/conf/PassivePortRange
	rm /etc/pure-ftpd/conf/PAMAuthentication /etc/pure-ftpd/auth/70pam 
	ln -s ../conf/PureDB /etc/pure-ftpd/auth/45puredb
	pure-pw mkdb
	/etc/init.d/pure-ftpd restart
	screen -dmS ftp_s pure-pw useradd root -u www-data -g www-data -d /host -N 15000
	sleep 5
	screen -S ftp_s -p 0 -X stuff '123$\n';
	sleep 5
	screen -S ftp_s -p 0 -X stuff '123$\n';
	sleep 5
	pure-pw mkdb
	/etc/init.d/pure-ftpd restart
	pure-pw userdel root
	pure-pw mkdb
	/etc/init.d/pure-ftpd restart
}
install_java()
{
	echo debconf shared/accepted-oracle-license-v1-1 select true | debconf-set-selections
	echo debconf shared/accepted-oracle-license-v1-1 seen true | debconf-set-selections
	echo "deb http://ppa.launchpad.net/webupd8team/java/ubuntu precise main" | tee -a /etc/apt/sources.list
	echo "deb-src http://ppa.launchpad.net/webupd8team/java/ubuntu precise main" | tee -a /etc/apt/sources.list
	apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys EEA14886
	apt-get update
	apt-get install -y oracle-java7-installer
}
install_base()
{
	apt-get install -y ssh sudo screen cpulimit zip unzip
	OS=$(lsb_release -s -i -c -r | xargs echo |sed 's; ;-;g' | grep Ubuntu)
	if [ "$OS" = "" ]; then
		sudo dpkg --add-architecture i386
		sudo apt-get update 
		sudo apt-get install -y ia32-libs
	else
		cd /etc/apt/sources.list.d
		echo "deb http://old-releases.ubuntu.com/ubuntu/ raring main restricted universe multiverse" >ia32-libs-raring.list
		apt-get update
		apt-get install -y ia32-libs

	fi
}
configure_box()
{
	upd
	clear
	Info
	log_t "Welcome to Options menu"
	Info "- 1  -  Install main packets"
	Info "- 2  -  FastDL to Apache"
	Info "- 3  -  FastDL to Nginx"
	Info "- 4  -  Install FTP server"
	Info "- 5  -  Install Java"
	Info "- 0  -  Go to main menu"
	log_s
	Info
	read -p "Please select menu number: " case
	case $case in
		1) install_base;;
		2) install_fastdl "1";;
		3) install_fastdl "2";;
		4) install_ftp;;
		5) install_java;;
		0) menu;;
	esac
	configure_box
}
UPD="0"
upd()
{
	if [ "$UPD" = "0" ]; then
		apt-get update
		UPD="1"
	fi
}
menu()
{
	clear
	Info
	log_t "Welcome to install menu GamePL v.7"
	Info "- 1  -  Install GamePL"
	Info "- 2  -  Configure machine to games"
	Info "- 3  -  Configure machine to games (All Packets)"
	Info "- 4  -  Install Games"
	Info "- 0  -  Exit"
	log_s
	Info
	read -p "Please select menu number: " case
	case $case in
		1) install_gamepl;;   
		2) configure_box;;   
		3) install_allpack;;
		4) install_games;;
		0) exit;;
	esac
}
menu