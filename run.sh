#!/bin/sh

##
# Run OpenStreetMap import server operations
#

# Command prefix that runs the command as the osmdata user
asosmdata="setuser osmdata"

die () {
    msg=$1
    echo "FATAL ERROR: " msg > 2
    exit
}

_startservice () {
    sv start $1 || die "Could not start $1"
}

startdb () {
    _startservice postgresql
}

initdb () {
    echo "Initialising postgresql"
    if [ -d /var/lib/postgresql/9.4/main ] && [ $( ls -A /var/lib/postgresql/9.4/main | wc -c ) -ge 0 ]
    then
        die "Initialisation failed: the directory is not empty: /var/lib/postgresql/9.4/main"
    fi

    mkdir -p /var/lib/postgresql/9.4/main && chown -R postgres /var/lib/postgresql/
    sudo -u postgres -i /usr/lib/postgresql/9.4/bin/initdb --pgdata /var/lib/postgresql/9.4/main
    ln -s /etc/ssl/certs/ssl-cert-snakeoil.pem /var/lib/postgresql/9.4/main/server.crt
    ln -s /etc/ssl/private/ssl-cert-snakeoil.key /var/lib/postgresql/9.4/main/server.key
	chmod -R 0700 /etc/ssl/certs
	chown -R postgres /etc/ssl/certs
	chmod -R 0700 /etc/ssl/private
	chown -R postgres /etc/ssl/private
}

createuser () {
    USER=osmdata
    echo "Creating user $USER"
    setuser postgres createuser -s $USER
}

createdb () {
    dbname=gis
    echo "Creating database $dbname"
    cd /var/www

    # Create the database
    setuser postgres createdb -O osmdata $dbname

    # Install the Postgis schema
    $asosmdata psql -d $dbname -f /usr/share/postgresql/9.4/contrib/postgis-2.1/postgis.sql

    $asosmdata psql -d $dbname -c 'CREATE EXTENSION HSTORE;'

    # Set the correct table ownership
    $asosmdata psql -d $dbname -c 'ALTER TABLE geometry_columns OWNER TO "osmdata"; ALTER TABLE spatial_ref_sys OWNER TO "osmdata";'

    # Add all spatial reference systems
    $asosmdata psql -d $dbname -f /usr/share/postgresql/9.4/contrib/postgis-2.1/spatial_ref_sys.sql
}

import () {
    # Find the most recent import.pbf or import.osm
    import=$( ls -1t /data/import.pbf /data/import.osm 2>/dev/null | head -1 )
    test -n "${import}" || \
        die "No import file present: expected /data/import.osm or /data/import.pbf"

    echo "Importing ${import} into gis"
    echo "$OSM_IMPORT_CACHE" | grep -P '^[0-9]+$' || \
        die "Unexpected cache type: expected an integer but found: ${OSM_IMPORT_CACHE}"

    number_processes=`nproc`

    # Limit to 8 to prevent overwhelming pg with connections
    if test $number_processes -ge 8
    then
        number_processes=8
    fi

    $asosmdata osm2pgsql --slim --hstore --cache $OSM_IMPORT_CACHE --database gis --number-processes $number_processes $import
}

dropdb () {
    echo "Dropping database"
    cd /var/www
    setuser postgres dropdb gis
}

dumpdb () {
    echo "Dumping database"
    cd /var/www
    setuser postgres pg_dump gis | gzip > /data/gis_pgdump.gz
}

cli () {
    echo "Running bash"
    cd /var/www
    exec bash
}

help () {
    cat /usr/local/share/doc/run/help.txt
}

_wait () {
    WAIT=$1
    NOW=`date +%s`
    BOOT_TIME=`stat -c %X /etc/container_environment.sh`
    UPTIME=`expr $NOW - $BOOT_TIME`
    DELTA=`expr 5 - $UPTIME`
    if [ $DELTA -gt 0 ]
    then
	sleep $DELTA
    fi
}

# Unless there is a terminal attached wait until 5 seconds after boot
# when runit will have started supervising the services.
if ! tty --silent
then
    _wait 5
fi

# Execute the specified command sequence
for arg 
do
    $arg;
done

# Unless there is a terminal attached don't exit, otherwise docker
# will also exit
if ! tty --silent
then
    # Wait forever (see
    # http://unix.stackexchange.com/questions/42901/how-to-do-nothing-forever-in-an-elegant-way).
    tail -f /dev/null
fi
