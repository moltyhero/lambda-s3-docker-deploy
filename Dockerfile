# Use the official AWS Lambda base image for Python
FROM public.ecr.aws/lambda/python:3.9

# Install dependencies
RUN pip install boto3

# Copy function code to the container
COPY app.py ${LAMBDA_TASK_ROOT}

# Set the CMD to the Lambda handler
CMD ["app.lambda_handler"]
