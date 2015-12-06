## -*- docker-image-name: "xingfuryda/openstreetmap-tiles-docker:latest" -*-

##
# The OpenStreetMap Tile Server
#
# This creates an image with osm2pgsql as described at
# <http://switch2osm.org/serving-tiles/manually-building-a-tile-server-12-04/>.
#
# forked from geo-data/openstreetmap-tiles-docker

FROM phusion/baseimage:0.9.17
MAINTAINER xingfuryda

# Set the locale. This affects the encoding of the Postgresql template
# databases.
ENV LANG C.UTF-8
RUN update-locale LANG=C.UTF-8

# Ensure `add-apt-repository` is present
RUN apt-get update -y
RUN apt-get install -y software-properties-common python-software-properties

RUN apt-get install -y libboost-dev libboost-filesystem-dev libboost-program-options-dev libboost-python-dev libboost-regex-dev libboost-system-dev libboost-thread-dev

# Install remaining dependencies
RUN apt-get install -y subversion git-core tar unzip wget bzip2 build-essential autoconf libtool libxml2-dev libgeos-dev libpq-dev libbz2-dev munin-node munin libprotobuf-c0-dev protobuf-c-compiler libprotobuf-dev protobuf-compiler pkg-config libfreetype6-dev libpng12-dev libtiff4-dev libicu-dev libgdal-dev libcairo-dev libcairomm-1.0-dev apache2 apache2-dev libagg-dev liblua5.2-dev ttf-unifont

RUN apt-get install -y autoconf apache2-dev libtool libxml2-dev libbz2-dev libgeos-dev libgeos++-dev libproj-dev gdal-bin libgdal1-dev mapnik-utils python-mapnik libmapnik-dev

# Install postgresql and postgis
RUN locale-gen en_US.UTF-8
RUN echo 'deb http://apt.postgresql.org/pub/repos/apt/ trusty-pgdg main' | tee /etc/apt/sources.list.d/pgdg.list
RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
RUN apt-get update
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y postgresql-9.4-postgis postgresql-contrib postgresql-server-dev-9.4

# Install osm2pgsql
RUN cd /tmp && git clone git://github.com/openstreetmap/osm2pgsql.git
RUN cd /tmp/osm2pgsql && \
    ./autogen.sh && \
    ./configure && \
    make && make install

## Install the Mapnik library
RUN cd /tmp && git clone git://github.com/mapnik/mapnik
RUN cd /tmp/mapnik && \
    git checkout 2.2.x && \
    python scons/scons.py configure INPUT_PLUGINS=all OPTIMIZATION=3 SYSTEM_FONTS=/usr/share/fonts/truetype/ && \
    python scons/scons.py && \
    python scons/scons.py install && \
    ldconfig

# Verify that Mapnik has been installed correctly
RUN python -c 'import mapnik'

# Ensure the osmdata user can connect to the gis database
RUN sed -i -e 's/local   all             all                                     peer/local gis osmdata peer/' /etc/postgresql/9.4/main/pg_hba.conf

# Tune postgresql
ADD postgresql.conf.sed /tmp/
RUN sed --file /tmp/postgresql.conf.sed --in-place /etc/postgresql/9.4/main/postgresql.conf

# Define the application logging logic
ADD syslog-ng.conf /etc/syslog-ng/conf.d/local.conf
RUN rm -rf /var/log/postgresql

# Create a `postgresql` `runit` service
ADD postgresql /etc/sv/postgresql
RUN update-service --add /etc/sv/postgresql

# Clean up APT when done
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Expose the webserver and database ports
EXPOSE 5432

# We need the volume for importing data from
VOLUME ["/data"]

# Set the osm2pgsql import cache size in MB. Used in `run import`.
ENV OSM_IMPORT_CACHE 800

# Add the README
ADD README.md /usr/local/share/doc/

# Add the help file
RUN mkdir -p /usr/local/share/doc/run
ADD help.txt /usr/local/share/doc/run/help.txt

# Add the entrypoint
ADD run.sh /usr/local/sbin/run
ENTRYPOINT ["/sbin/my_init", "--", "/usr/local/sbin/run"]

# Default to showing the usage text
CMD ["help"]
