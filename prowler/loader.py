from __future__ import print_function
import boto3
import json
import decimal
import os

awsRegion = os.environ['AWS_REGION']
prowlerDynamoDBTable = os.environ['MY_DYANMODB_TABLE']

dynamodb = boto3.resource('dynamodb', region_name=awsRegion)

table = dynamodb.Table(prowlerDynamoDBTable)

with open('prowler_report.json') as json_file:
    findings = json.load(json_file, parse_float = decimal.Decimal)
    for finding in findings:
        CheckID = finding['CheckID']
        CheckTitle = finding['CheckTitle']
        Status = finding['Status']
        Notes = finding['Notes']
        if Notes == "":
            Notes = "N/A"

        print("Adding finding:", CheckID, CheckTitle)

        table.put_item(
           Item={
               'CheckID': CheckID,
               'CheckTitle': CheckTitle,
               'Status': Status,
               'Notes': Notes,
            }
        )