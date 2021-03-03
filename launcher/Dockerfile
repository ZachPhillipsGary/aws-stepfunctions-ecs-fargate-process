FROM public.ecr.aws/lambda/python:3.8
COPY main.py requirements.txt /var/task/
RUN pip install -r  /var/task/requirements.txt
CMD [ "main.lambda_handler" ] 