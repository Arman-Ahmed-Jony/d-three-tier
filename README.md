# Three-Tier Todo App

Simple todo app with three tiers:

| Tier | Folder | Stack |
|------|--------|--------|
| Client | `client/` | React + Vite |
| Service | `service/` | Express + Mongoose |
| Database | — | MongoDB |

## Prerequisites

- [Node.js](https://nodejs.org/) 18+
- [MongoDB](https://www.mongodb.com/docs/manual/installation/) running locally  
  (or a MongoDB Atlas connection string)

## Install

From the project root:

```bash
# Service
cd service
cp .env.example .env
npm install

# Client
cd ../client
npm install
```

## Configure

Edit `service/.env` if needed:

```
PORT=5000
MONGODB_URI=mongodb://127.0.0.1:27017/todo-app
```

For MongoDB Atlas, set `MONGODB_URI` to your cluster connection string.

## Run

Start MongoDB (if local), then open **two terminals**:

**Terminal 1 — API service**

```bash
cd service
npm run dev
```

Service: http://localhost:5000  
Health check: http://localhost:5000/api/health

**Terminal 2 — React client**

```bash
cd client
npm run dev
```

App: http://localhost:5173

The Vite dev server proxies `/api` requests to the Express service.

## API

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/todos` | List todos |
| `POST` | `/api/todos` | Create todo (`{ "title": "..." }`) |
| `PATCH` | `/api/todos/:id` | Update (`{ "completed": true }` and/or `{ "title": "..." }`) |
| `DELETE` | `/api/todos/:id` | Delete todo |

## Production build (client)

```bash
cd client
npm run build
npm run preview
```
