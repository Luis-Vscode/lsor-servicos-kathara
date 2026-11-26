FROM kathara/base

RUN apt-get update \
    && apt-get install -y --no-install-recommends nginx \
    && rm -rf /var/lib/apt/lists/*

COPY site/ /var/www/lsor/
COPY nginx/lsor.conf /etc/nginx/sites-available/lsor.conf

RUN rm -f /etc/nginx/sites-enabled/default \
    && ln -sf /etc/nginx/sites-available/lsor.conf /etc/nginx/sites-enabled/lsor.conf
