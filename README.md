# mqtt-topic-grapher

MQTT Topic Grapher

# Overview

Push messages onto MQTT every minute and magically have them rendered into MRTG charts.

# Apache Web server

URL http://127.0.0.1/mqtt-topic-grapher/

# Topic Format

grapher/$graph/$series value

## $graph format

$graph = sort\_title\_min\_max

Example: 100\_Temperature\_60\_80

### sort

Sorts the charts on the HTML display

Example 100

### title

Example: Temperature

### Minimum

Example: 60

### Maximum

Example: 80

## $series foramt

String for the particular layer

Example: Basement

## value format

A float number between min and max defined in $graph format

Example: 72.4

# Limitations

This RRD implementation requires that the data be stored every minute.  If your data is event based or does not arrive every minute please store the data in a variable and read that variable every minute.
