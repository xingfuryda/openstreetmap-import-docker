# OpenStreetMap Import Container

This repository contains instructions for building a
[Docker](https://www.docker.io/) image containing software
for importing OpenStreetMap data into a PostgreSQL database using osm2pgsql.
It is partly based on the
[Switch2OSM instructions](http://switch2osm.org/serving-tiles/manually-building-a-tile-server-12-04/).

Based also on [geo-data/openstreetmap-tiles-docker](https://github.com/geo-data/openstreetmap-tiles-docker)

As well as providing an easy way to set up and run osm2pgsql it
also provides instructions for managing the back end database, allowing you to:

* Create the database
* Import OSM data into the database
* Drop the database

Run `docker run xingfuryda/openstreetmap-import-docker` for usage instructions.

## About

The container runs Ubuntu 14.04 (Trusty) and is based on the
[phusion/baseimage-docker](https://github.com/phusion/baseimage-docker).  It
includes:

* Postgresql 9.4
* The latest [Osm2pgsql](http://wiki.openstreetmap.org/wiki/Osm2pgsql) code (at
  the time of image creation 0.89 December 2015)

## Issues

This is a work in progress and although generally adequate it could benefit
from improvements.  Please
[submit issues](https://github.com/xingfuryda/openstreetmap-import-docker/issues)
on GitHub. Pull requests are very welcome!
