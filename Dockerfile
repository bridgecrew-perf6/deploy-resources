# Container image that runs your code
FROM nikodonoso86/base-image:latest

# Copies your code file from your action repository to the filesystem path `/` of the container
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
# RUN git clone --single-branch --branch master https://github.com/nicolasdonoso/templates.git
# RUN ls -alh

# Code file to execute when the docker container starts up (`entrypoint.sh`)
ENTRYPOINT ["/entrypoint.sh"]