# doculaboration-service
The full stack solution for doculaboration project

## Clone the doculaboration repository
`git clone https://github.com/AsifKHasan/doculaboration.git`

Overwrite in case of any filename conflict.

# doculaboration - Documentation Collaboration
CRDT (gsheet, etc.) based documentation collaboration pipeline to generate editable (docx, odt, etc.) and printable (pdf, etc.) output from input data

* *gsheet-to-json* is for generating json output from gsheet data. The output json is meant to be fed as input for document generation components of the pipeline
* *json-to-docx* is for generating docx (WordML) documents
* *json-to-odt* is for generating odt (OpenOffice Text) documents
* *json-to-latex* is for generating LaTex for generating printable outputs
* *json-to-context* is for generating ConTeXt for generating printable outputs

## Quick Start

### Development Mode
```bash
# Start backend services only
make dev

# In another terminal, start frontend
make frontend-dev
```

### Production Mode
```bash
# Start everything with Nginx
make prod
```

### Access Points
- **Application**: http://localhost (production) or http://localhost:4200 (development)
- **API**: http://localhost/api (production) or http://localhost:9001 (development)
- **RabbitMQ Management**: http://localhost:15672 (guest/guest)

## Architecture

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Nginx     │    │   React     │    │   FastAPI   │
│   (Port 80) │────│  Frontend   │    │   Backend   │
│             │    │ (Port 4200) │    │ (Port 9001) │
└─────────────┘    └─────────────┘    └─────────────┘
                                              │
                   ┌─────────────┐    ┌─────────────┐
                   │   Celery    │    │    Redis    │
                   │   Workers   │────│   & RabbitMQ│
                   └─────────────┘    └─────────────┘
```

## Available Commands

```bash
make help          # Show all available commands
make dev           # Start development environment
make prod          # Start production environment
make stop          # Stop all services
make clean         # Clean up containers and images
make logs          # Show logs from all services
make scale-workers # Scale workers to 3 instances
```

## Manual Setup (Legacy)

1. cd to ```d:\projects``` (for Windows) or ```~/projects``` (for Linux)
2. run ```git clone https://github.com/AsifKHasan/doculaboration.git```
3. cd to ```D:\projects\doculaboration``` (for Windows) or ```~/projects/doculaboration``` (for Linux)
4. run command ```pip install -r requirements.txt --upgrade```. See if there is any error or not.

## (optional) update all python packages
```
pip list --outdated --format=freeze | grep -v '^\-e' | cut -d = -f 1  | xargs -n1 pip install -U
```

