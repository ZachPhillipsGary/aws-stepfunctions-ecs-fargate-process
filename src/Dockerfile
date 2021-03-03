FROM python:buster
RUN apt-get update && \
    apt-get install -y postgresql postgresql-contrib
COPY backup.py backup.py
RUN chmod +x backup.py
RUN pip3 install boto3
RUN pip3 install --no-binary :all: psycopg2
CMD ["python", "./backup.py"]