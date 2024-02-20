#! /bin/sh

### BEGIN INIT INFO
# Provides:          biblio18
# Required-Start:    $syslog $remote_fs koha-common
# Required-Stop:     $syslog $remote_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Biblio18 service
# Description:       Biblio18 service to support the equally named interlibrary union cataloge
### END INIT INFO

#
# Author:	Roger Grossmann <roger.grossmann@lmscloud.de>
#

# PATH should only include /usr/* if it runs after the mountnfs.sh script
PATH=/sbin:/usr/sbin:/bin:/usr/bin
DESC="Biblio18 Koha service"
NAME="biblio18"
SCRIPTNAME=/etc/init.d/$NAME


# Read configuration variable file if it is present
if [ -r /etc/default/$NAME ]; then
    # Debian / Ubuntu
    . /etc/default/$NAME
elif [ -r /etc/sysconfig/$NAME ]; then
    # RedHat / SuSE
    . /etc/sysconfig/$NAME
fi

# Load the VERBOSE setting and other rcS variables
. /lib/init/vars.sh

# Define LSB log_* functions.
# Depend on lsb-base (>= 3.0-6) to ensure that this file is present.
. /lib/lsb/init-functions


#
# Function that starts the biblio18 daemon/service
#
do_start()
{
    for instance in $(koha-list); do
        if [ -e "/etc/koha/sites/${instance}/Biblio18.conf" ] && [ -r "/etc/koha/sites/${instance}/Biblio18.conf" ]; then
            koha-biblio18 --start ${instance}
        fi
    done
}

# Function that stops the biblio18 daemon/service
#
do_stop()
{
    for instance in $(koha-list); do
        if [ -e "/etc/koha/sites/${instance}/Biblio18.conf" ] && [ -r "/etc/koha/sites/${instance}/Biblio18.conf" ]; then
            koha-biblio18 --stop ${instance}
        fi
    done
}

# Function that stops the biblio18 daemon/service
#
get_status()
{
    for instance in $(koha-list); do
        if [ -e "/etc/koha/sites/${instance}/Biblio18.conf" ] && [ -r "/etc/koha/sites/${instance}/Biblio18.conf" ]; then
            koha-biblio18 --status ${instance}
        fi
    done
}

case "$1" in
  start)
	do_start
    ;;
  stop)
	do_stop
    ;;
  force-reload|restart)
    do_start
    do_stop
    ;;
  status)
    get_status
    ;;
  *)
    echo "Usage: $SCRIPTNAME {start|stop|restart|force-reload}"
    exit 3
    ;;
esac

:
