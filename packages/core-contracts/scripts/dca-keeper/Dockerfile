# DCA keeper — AWS Lambda container image.
#
# Runs the keeper in one-shot mode (a single pass) per invocation; EventBridge
# fires it on a schedule. Built on the AWS Lambda Python base image so web3 /
# eth-account / cryptography native wheels match the Lambda runtime + arch.
#
# Build context is this directory:
#   docker build -t dca-keeper packages/core-contracts/scripts/dca-keeper
FROM public.ecr.aws/lambda/python:3.12

# Dependencies first for layer caching.
COPY requirements.txt ${LAMBDA_TASK_ROOT}/
RUN pip install --no-cache-dir -r ${LAMBDA_TASK_ROOT}/requirements.txt

# Keeper library + Lambda handler.
COPY dca_keeper.py lambda_function.py ${LAMBDA_TASK_ROOT}/

# <module>.<function>
CMD ["lambda_function.handler"]
