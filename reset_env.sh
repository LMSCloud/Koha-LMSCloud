#!/bin/bash

koha-plack --restart paul &&
perl installer/data/mysql/updatedatabase.pl &&
service memcached restart
