#!/bin/bash
echo "Running Prowler Scans - Antoine Cichowicz | Github: Yris Ops"
prowler -b -f us-west-1 -M json > file.json
cp output/* prowler_report.json
echo "Loading JSON data into DynamoDB"
python loader.py