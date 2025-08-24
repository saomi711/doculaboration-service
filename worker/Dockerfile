FROM python:3.9-slim

# Same OS packages as the API container (plus any you need for the script)
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    poppler-utils \
    libreoffice \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# install python deps (same as API, plus Celery)
COPY worker/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# copy everything – the script is part of the repo
COPY worker/app ./app

# Copy scripts and directories to current working directory
COPY odt-from-gsheet.sh ./odt-from-gsheet.sh
COPY all-formats-from-gsheet.sh ./all-formats-from-gsheet.sh
RUN chmod +x ./odt-from-gsheet.sh ./all-formats-from-gsheet.sh

COPY gsheet-to-json ./gsheet-to-json
COPY json-to-odt ./json-to-odt
COPY json-to-docx ./json-to-docx


# the worker entrypoint
CMD ["celery", "-A", "app.celery_worker", "worker", "--loglevel=info"]