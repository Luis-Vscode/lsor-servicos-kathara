FROM kathara/base

RUN apt-get update \
    && apt-get install -y --no-install-recommends nmap curl openssh-client iputils-ping \
    && rm -rf /var/lib/apt/lists/*
