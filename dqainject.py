#!/usr/bin/env python

#Author:        James Holland - jholland@usgs.gov
#Copyright:     Public Domain
#Description:   This script injects a csv file into the server located in db.config
import os
import psycopg2
import csv

connString = open('db.config', 'r').readline()

hashFieldNames = ['date', 'network', 'station', 'location', 'channel', 'metric', 'value', 'hash']

injectQuery = "SELECT spInsertMetricData(%s, %s, %s, %s, %s, %s, cast(%s as double precision), E%s)"

print "Connecting to "+connString
host, user, pwd, db, port = connString.split(',')
        
conn = psycopg2.connect(host=host, user=user, password=pwd, database=db, port=port)
cursor = conn.cursor()

csv_file=open("datain.csv")
data = csv.reader(csv_file, delimiter=',', skipinitialspace=True)

for row in data:
    if row:
        params = (row[0], row[5], row[1], row[2], row[3], row[4], row[6], ("\\\\x"+row[7]))
        print injectQuery % params 
        cursor.execute(injectQuery, params)
        conn.commit()

conn.close()
