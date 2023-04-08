FROM python:latest

ENV MY_DYANMODB_TABLE=MY_DYANMODB_TABLE
ENV AWS_REGION=us-west-1

# Install Dependencies
RUN \
    apt update && \
    apt upgrade -y && \
    pip install awscli && \
    pip install detect-secrets && \
    apt install jq -y && \
    apt install -y python3-pip

# Place scripts
ADD loader.py /root
ADD script.sh /root

# Installs prowler, moves scripts into prowler directory
RUN \
    git clone https://github.com/toniblyx/prowler && \
    mv root/loader.py /prowler && \
    mv root/script.sh /prowler

# Runs prowler and loads DynamoDB with loader
WORKDIR /prowler
RUN pip3 install boto3
RUN pip install prowler
CMD bash script.sh