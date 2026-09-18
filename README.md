# Three-Tier Todo App

Simple todo app with three tiers:

| Tier | Folder | Stack |
|------|--------|--------|
| Client | `client/` | React + Vite |
| Service | `service/` | Express + Mongoose |
| Database | — | MongoDB |

For **manual AWS or local VM deployment** (public frontend, private backend + DB, Nginx, PM2), see [DEPLOYMENT.md](./DEPLOYMENT.md).

## Prerequisites

- [Node.js](https://nodejs.org/) 18+
- MongoDB — either:
  - [Docker](https://www.docker.com/) (recommended for local): `docker compose up -d` from the project root
  - or a local/Atlas MongoDB and set `MONGODB_URI` in `service/.env`

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
PORT=5001
MONGODB_URI=mongodb://127.0.0.1:27017/todo-app
```

> **Note:** Port `5001` is used locally because macOS AirPlay Receiver often occupies `5000` and returns `403 Forbidden`.

For MongoDB Atlas, set `MONGODB_URI` to your cluster connection string.

## Run

Start MongoDB, then open **two terminals**.

**MongoDB (Docker):**

```bash
# from project root — start Docker Desktop first if needed
docker compose up -d
```

**Terminal 1 — API service**

```bash
cd service
npm run dev
```

Service: http://localhost:5001  
Health check: http://localhost:5001/api/health

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
