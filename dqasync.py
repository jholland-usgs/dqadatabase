#!/usr/bin/env python

#Author:        James Holland - jholland@usgs.gov
#Copyright:     Public Domain
#Description:   This script is used to synchronize dqa databases.
#               It generates a CSV of differing data that can be injected.

import argparse
import datetime
import time
import urllib
import urllib2
import csv
from threading import Lock
from threading import Thread
from Queue import Queue

#Function Definitions
def date_type(date):
    try:
        return datetime.datetime.strptime(date, "%Y-%m-%d")
    except ValueError:
        try:
            return datetime.datetime.strptime(date, "%Y-%j")
        except ValueError:
            raise argparse.ArgumentTypeError("".join("Invalid date: \"", date, "\""))

def makeKey(row):
    return row['date']+row['network']+row['station']+row['location']+row['channel']+row['metric']

def printRow(row):
    listRow = [row['date'], row['network'], row['station'], row['location'], row['channel'], row['metric'], row['value'], row['hash']]
    printOut = ', '.join(listRow) + "\r\n"
    with printLock: #multithreading print can jack things up.
        print printOut,

def dateRange(startDate, endDate):
    endDate = endDate + datetime.timedelta(1)
    for day in range(int ((endDate - startDate).days)):
        yield (startDate + datetime.timedelta(day))

def getAndPrintDate():
    while True:
        if fetchQueue.empty() == True:
            return
        #Get next queued date
        date = fetchQueue.get(block=True)
        params = urllib.urlencode({"cmd": "hash",
            "network": args.network,
            "station": args.station,
            "location": args.location,
            "channel": args.channel,
            "metric": args.metric,
            "sdate": date,
            "edate": date,
            "format": "CSV"})


        destDict = {}

#Destination hash get
        if(args.destination in aliases):
            site = aliases[args.destination]
        else:
            site = args.destination

        fullsite = site + "/cgi-bin/dqaget.py?"+params
        response = urllib2.urlopen(fullsite)
        reader = csv.DictReader(response, fieldnames=hashFieldNames, delimiter=",", skipinitialspace=True)
        for row in reader:
            if(row['hash'] != None and row['value'] != None):
                destDict[makeKey(row)] = row['hash']+row['value']

#Source hash get
        if(args.source in aliases):
            site = aliases[args.source]
        else:
            site = args.source

        fullsite = site + "/cgi-bin/dqaget.py?"+params
        response = urllib2.urlopen(fullsite)

        reader = csv.DictReader(response, fieldnames=hashFieldNames, delimiter=",", skipinitialspace=True)
        for row in reader:
            if(row['hash'] != None and row['value'] != None):
                if(destDict.get(makeKey(row)) != row['hash']+row['value']):
                    printRow(row)

        fetchQueue.task_done()

def main():

#Parse dates one by one to prevent timeouts.
#Fill date queue first
    for date in dateRange(args.begin, args.end):
        fetchQueue.put(date)
#Start Threads
    for thread in range(numThreads):
        dThread = Thread(target = getAndPrintDate)
        dThread.start()
    fetchQueue.join()




#Globals
hashFieldNames = ['date', 'network', 'station', 'location', 'channel', 'metric', 'value', 'hash']

parser = argparse.ArgumentParser(prog="dqasync.py")

aliases = {"prod": "https://igskgacgvmaslwb.cr.usgs.gov/dqa", "dev": "https://igskgacgvmaslwb.cr.usgs.gov/dqadev"}

parser.add_argument("--source", help="use website alias or full url. Aliases: prod and dev", required=True)
parser.add_argument("--destination", help="use website alias or full url. Aliases: prod and dev", required=True)
parser.add_argument("-n", "--network", help="network identifier, EG: -n IU", default="%")
parser.add_argument("-s", "--station", help="station identifier, EG: -s ANMO", default="%")
parser.add_argument("-l", "--location", help="location identifier, EG: -l 00", default="%")
parser.add_argument("-c", "--channel", help="channel identifier, EG: -c BH%%", default="%")
parser.add_argument("-m", "--metric", help="metric name, EG: -m AvailabilityMetric", default="%")
parser.add_argument("-b", "--begin", help="start date EG: 2014-02-15 Default: Current date", type=date_type, default=time.strftime("%Y-%m-%d"))
parser.add_argument("-e", "--end", help="end date EG: 2014-02-15 Default: Current date", type=date_type, default=time.strftime("%Y-%m-%d"))

args = parser.parse_args()

fetchQueue = Queue()
numThreads = 10
printLock = Lock()

if __name__ == '__main__':
    main()
