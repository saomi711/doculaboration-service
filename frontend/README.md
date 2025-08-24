# Doculaboration Frontend

A React TypeScript frontend for the Doculaboration document processing system.

## Features

- Document name input field
- Process button with loading states
- Real-time processing status with progress bar
- Streaming status updates during processing
- Download functionality for completed documents
- Clean, responsive UI with Tailwind CSS

## Getting Started

1. Install dependencies:
```bash
npm install
```

2. Start the development server:
```bash
npm start
```

3. Open [http://localhost:3000](http://localhost:3000) to view it in the browser.

## Available Scripts

- `npm start` - Runs the app in development mode
- `npm run build` - Builds the app for production
- `npm test` - Launches the test runner
- `npm run eject` - Ejects from Create React App (one-way operation)

## Technology Stack

- React 18
- TypeScript
- Tailwind CSS
- Create React App

## Integration

This frontend is designed to work with the existing Doculaboration backend API. Update the API endpoints in the DocumentProcessor component to match your backend URLs.
## Po
rt Configuration

To avoid conflicts with other applications, this setup uses the following ports:
- **Frontend (Development)**: http://localhost:3002
- **Backend API (Development)**: http://localhost:9001
- **Full Application (Production)**: http://localhost:9000
- **RabbitMQ Management**: http://localhost:15672
- **Redis**: localhost:6379

## Development Setup

1. **Start backend services**:
```bash
./scripts/dev.sh
```

2. **Start frontend in development mode**:
```bash
cd frontend
npm install
npm run start:dev
```

The frontend will be available at `http://localhost:3002` and will connect to the backend API at `http://localhost:9001`.

## Production Setup

1. **Start all services with Nginx**:
```bash
./scripts/prod.sh
```

The complete application will be available at `http://localhost:9000` with Nginx handling load balancing and serving both frontend and backend.

## Architecture

- **Nginx**: Reverse proxy and load balancer on port 9000
- **React Frontend**: Served through Nginx or standalone on port 3002
- **FastAPI Backend**: Accessible through Nginx or directly on port 9001
- **Celery Workers**: Background task processing
- **Redis**: Task results and caching
- **RabbitMQ**: Message broker for Celery