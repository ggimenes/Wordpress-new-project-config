#!/bin/sh

# Version = 1.3.3
# 


# --------------------
# Load Variables
# --------------------
CURRENTDIRECTORY=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
source $CURRENTDIRECTORY/config.cfg

# --------------------
# Set directory
# --------------------
cd $DIRECTORY

# --------------------
# Set project name
# --------------------
echo "What is the project name ?"
read PROJECT_NAME
while [[ -z "$PROJECT_NAME" ]]; do
    echo "Please, type your project name:"
    read PROJECT_NAME
done

# --------------------
# Create database
# --------------------
if [[ $TABLE_PREFIX == "" ]]; then
	echo "Table prefix (default : wp_)"
	read TABLE_PREFIX
	if [[ $TABLE_PREFIX == "" ]]; then
		TABLE_PREFIX="wp_"
	fi
fi

echo "Database name"
read DB_NAME

if [[ $DB_PASSWORD != "" ]]; then
	$MYSQL_PATH -u $DB_USER -p $DB_PASSWORD -e "create database $DB_NAME"
else
	$MYSQL_PATH -u $DB_USER --password="" -e "create database $DB_NAME"
fi

# --------------------
# Set FTP parmmeters for sublime SFTP mapping
# --------------------
if [[ $FTP_ENABLED == true ]]; then
	echo "If you want to configure sFTP now, please enter FTP host. Type Q to skip sFTP configuration"
	read FTP_HOST
	if [[ $FTP_HOST =~ ^[Qq]$  ]]; then
		FTP_HOST=''
	fi
	if [[ -n "$FTP_HOST" ]]; then

		ABORT_SFTP=false

		echo "FTP user ? (or Q to quit sFTP configuration)"
		read FTP_USER
		while [[ -z "$FTP_USER" ]]; do
			echo "Please, type your FTP user (or Q to quit sFTP configuration):"
			read FTP_USER
		done

		if [[ $FTP_USER =~ ^[Qq]$ ]]; then
			ABORT_SFTP=true
		fi

		if [[ $ABORT_SFTP == false ]]; then
			echo "FTP password ? (or Q to quit sFTP configuration)"
			read FTP_PASS
			while [[ -z "$FTP_PASS" ]]; do
				echo "Please, type your FTP password (or Q to quit sFTP configuration):"
				read FTP_PASS
			done
		fi

		if [[ $FTP_PASS =~ ^[Qq]$ ]]; then
			ABORT_SFTP=true
		fi

		if [[ $ABORT_SFTP == false ]]; then
			echo "FTP remote path ? (or Q to quit sFTP configuration)"
			read FTP_ROOT
			while [[ -z "$FTP_ROOT" ]]; do
				echo "Please, type your FTP remote path (or Q to quit sFTP configuration):"
				read FTP_ROOT
			done
		fi

		if [[ $FTP_ROOT =~ ^[Qq]$ ]]; then
			ABORT_SFTP=true
		fi

		# If sFTP has been aborted, set $FTP_HOST to null
		# so FTP files are not created
		if [[ $ABORT_SFTP == true ]]; then
			FTP_HOST=''
		fi

	fi
fi

# --------------------
# Function
# Download unzip and remove
# --------------------
function fetch_zip()
{
	curl -o file.zip $1
	unzip -q file.zip
	rm file.zip
}

# --------------------
# Create project directory
# --------------------
mkdir $PROJECT_NAME
PROJECT_DIR=$DIRECTORY"/"$PROJECT_NAME
cd $PROJECT_NAME

# --------------------
# Fetch Wordpress latest build
# --------------------
echo 'Download Wordpress...'
fetch_zip $WORDPRESS_URL
cp -R wordpress/* .
rm -rf wordpress && rm readme.html && rm license.txt

# --------------------
# Fetch H5BP server-config .htaccess
# --------------------
git clone https://github.com/h5bp/server-configs-apache.git
cp server-configs-apache/dist/.htaccess .htaccess
rm -rf server-configs

# --------------------
# Fetch base theme & remove default themes
# --------------------
echo 'Remove default themes and fetch your starter theme'
cd wp-content/themes/
git clone --recursive $THEME_URL $PROJECT_NAME
rm -r twentyten
rm -r twentyeleven
rm -r twentytwelve
rm -r twentythirteen
rm -r twentyfourteen
rm -r twentyfifteen
rm -r twentysixteen
rm -r twentytwenty
rm -r twentytwentyone

# --------------------
# Remove Hello Dolly plugin and fetch plugins
# --------------------
echo 'Remove Hello Dolly and fetch your plugins'
cd ../plugins/
rm hello.php

for PLUGIN in ${PLUGINS_URL[@]}
do
	fetch_zip $PLUGIN
done

# --------------------
# Create Wordpress wp-config.php
# --------------------
echo 'Create wp-config...'
cd $PROJECT_DIR
touch wp-config-local.php
echo "<?php
define( 'DB_NAME', '"$DB_NAME"' );
define( 'DB_USER', '"$DB_USER"' );
define( 'DB_PASSWORD', '"$DB_PASSWORD"' );
define( 'DB_HOST', '"$DB_HOST"' );" >wp-config-local.php
touch db.txt
echo "if ( file_exists( dirname( __FILE__ ) . '/wp-config-local.php' ) ) {
	include( dirname( __FILE__ ) . '/wp-config-local.php' );
} else {
	define( 'DB_NAME', '' );
	define( 'DB_USER', '' );
	define( 'DB_PASSWORD', '' );
	define( 'DB_HOST', '' ); // Probably 'localhost'
}" > db.txt

sed -e'
/DB_NAME/,/localhost/ c\
hello
' \
<wp-config-sample.php >wp-config-temp.php

sed '/hello/ {
r db.txt
d
}'<wp-config-temp.php >wp-config.php
mv wp-config.php wp-config-temp.php

curl -o salt.txt https://api.wordpress.org/secret-key/1.1/salt/

sed '/#@-/r salt.txt' <wp-config-temp.php >wp-config.php
mv wp-config.php wp-config-temp.php

sed "/#@+/,/#@-/d" <wp-config-temp.php >wp-config.php
mv wp-config.php wp-config-temp.php

sed s/wp_/$TABLE_PREFIX/ <wp-config-temp.php >wp-config.php

rm wp-config-temp.php
rm db.txt
rm salt.txt

if [[ $SUBLIME_ENABLED == true ]]; then
	# --------------------
	# Create Sublime Project config file
	# --------------------
	echo 'Create Sublime text 2 project file...'
	SUBLIME_PROJECT_FILE=$PROJECT_NAME".sublime-project"
	touch $SUBLIME_PROJECT_FILE
	echo '{
		"folders":
		[

			{
				"path": "./wp-content/themes/'$PROJECT_NAME'",
				"name": "My theme",
				"file_exclude_patterns":[
					"._*"
				],
				"folder_exclude_patterns": [".sass-cache"]
			},
			{
				"path": "./wp-content/plugins",
				"file_exclude_patterns":[
					"._*"
				]
			},
			{
				"path": ".",
				"name": "All website",
				"file_exclude_patterns":[
					"._*",
					"*.sublime-project",
					"*.sublime-workspace"
				],
				"folder_exclude_patterns": [".sass-cache"]
			}
		]
	}' > $SUBLIME_PROJECT_FILE
fi

# --------------------
# Create sFTP config files
# --------------------
echo 'Create FTP files...'
function create_FTP_file()
{
	touch sftp-config.json
	echo '{
	    // The tab key will cycle through the settings when first created
	    // Visit http://wbond.net/sublime_packages/sftp/settings for help
	    
	    // sftp, ftp or ftps
	    "type": "ftp",

	    "save_before_upload": true,
	    "upload_on_save": false,
	    "sync_down_on_open": false,
	    "sync_skip_deletes": false,
	    "confirm_downloads": false,
	    "confirm_sync": true,
	    "confirm_overwrite_newer": false,
	    
	    "host": "'$FTP_HOST'",
	    "user": "'$FTP_USER'",
	    "password": "'$FTP_PASS'",
	    //"port": "22",
	    
	    "remote_path": "'$1'",
	    "ignore_regexes": [
	        "\\\\.sublime-(project|workspace)", "sftp-config(-alt\\\\d?)?\\\\.json",
	        "sftp-settings\\\\.json", "/venv/", "\\\\.svn", "\\\\.hg", "\\\\.git",
	        "\\\\.bzr", "_darcs", "CVS", "\\\\.DS_Store", "Thumbs\\\\.db", "desktop\\\\.ini","wp-config-local.php"
	    ],
	    //"file_permissions": "664",
	    //"dir_permissions": "775",
	    
	    //"extra_list_connections": 0,

	    "connect_timeout": 30,
	    //"keepalive": 120,
	    //"FTP_PASSive_mode": true,
	    //"ssh_key_file": "~/.ssh/id_rsa",
	    //"sftp_flags": ["-F", "/path/to/ssh_config"],
	    
	    //"preserve_modification_times": false,
	    //"remote_time_offset_in_hours": 0,
	    //"remote_encoding": "utf-8",
	    //"remote_locale": "C",
	}' > sftp-config.json
}
if [[ $FTP_HOST != "" ]]; then
	create_FTP_file $FTP_ROOT
	cd "wp-content/themes/"$PROJECT_NAME
	create_FTP_file $FTP_ROOT"/wp-content/themes/"$PROJECT_NAME
	cd ../../plugins
	create_FTP_file $FTP_ROOT"/wp-content/plugins"
fi

if [[ $SUBLIME_ENABLED == true ]]; then
	# --------------------
	# Launch sublime project
	# --------------------
	echo 'Launch Sublime text 2'
	cd $PROJECT_DIR
	"$SUBLIME_PATH" $SUBLIME_PROJECT_FILE
fi

if [[ $CODEKIT_ENABLED == true ]]; then
	# --------------------
	# Create a new project in CodeKit
	# --------------------
	echo 'Create codekit project'
	open -a /Applications/CodeKit.app $PROJECT_DIR"/wp-content/themes/"$PROJECT_NAME
fi

# --------------------
# git init
# --------------------
echo 'git init'
git init
echo ".DS_Store
wp-config-local.php
.sass-cache" > .gitignore

# --------------------
# Launch default browser
# --------------------
echo 'Launch browser'
open $LOCAL_URL$PROJECT_NAME

echo 'Installation Complete, press enter to quit'
read
