# Manual Deployment Guide — 3-Tier Todo App

This guide maps this repository to a **manual 3-tier deployment** assignment.


| Layer    | Code       | Runtime              | Network     |
| -------- | ---------- | -------------------- | ----------- |
| Frontend | `client/`  | Nginx (static build) | **Public**  |
| Backend  | `service/` | Node.js + PM2        | **Private** |
| Database | MongoDB    | `mongod`             | **Private** |


**Rule of thumb:** the browser only talks to the frontend. The frontend’s Nginx proxies `/api` to the private backend. The backend talks to MongoDB on the private network. Backend and DB are never exposed to the public internet.

```
Internet
   |
   v
Public Subnet / Public VM
   |
Frontend + Nginx  (public IP or tunnel)
   |  proxy /api
   v
Private Subnet / Private VM
   |
Backend + PM2     (private IP only)
   |
   v
Private Subnet / Private VM
   |
MongoDB           (private IP only)
```

---



## Checklist (both AWS and local VMs)

Use this as your submission checklist.

### Architecture

- [ ] Three separate hosts (FE / BE / DB)
- [ ] Frontend reachable from outside
- [ ] Backend has **no** public access on port 5000
- [ ] Database has **no** public IP / no public MongoDB port
- [ ] Frontend → Backend connectivity works (via private network or VPC)
- [ ] Backend → Database connectivity works



### App

- [ ] MongoDB installed and listening on private IP only
- [ ] Backend `.env` points `MONGODB_URI` at the DB private IP
- [ ] Backend running under PM2
- [ ] Frontend built with `npm run build`
- [ ] Nginx serves `client/dist` and proxies `/api` to backend



### Security

- [ ] Security groups / firewall documented (who → whom → port)
- [ ] Only frontend allows inbound 80 (and 443 if used)
- [ ] Backend allows inbound 5000 **only from frontend**
- [ ] MongoDB allows inbound 27017 **only from backend**

---



## Environment variables



### Backend (`service/.env` on the private backend host)

```bash
PORT=5000
MONGODB_URI=mongodb://<DB_PRIVATE_IP>:27017/todo-app
```

Examples:

```bash
# AWS private DB instance
MONGODB_URI=mongodb://10.0.3.10:27017/todo-app

# Local VM private network
MONGODB_URI=mongodb://192.168.56.30:27017/todo-app
```

Copy from the example file:

```bash
cd service
cp .env.example .env
# then edit MONGODB_URI
```



### Frontend

No public API URL is required if Nginx proxies `/api` (recommended). The React app already calls `/api/todos`, so the browser hits the same host as the UI.

Optional (only if you choose **not** to use an Nginx proxy): build with an absolute API URL — that would expose or require a reachable backend URL and is **not** recommended for this assignment.

### Database

No app `.env` on the DB host. Configure MongoDB bind address and firewall instead (see below).

---



## Software installation (client, server, MongoDB)

Do this on each host after SSH. Use **Ubuntu 22.04+**. Private hosts need a NAT Gateway (AWS) or extra NAT NIC (local VMs) so `apt`/`curl` can reach the internet.

### 0. Get the project onto FE and BE hosts

```bash
# Option A — git (needs outbound HTTPS or SSH to GitHub)
sudo apt update && sudo apt install -y git
git clone <YOUR_REPO_URL> d-three-tier
cd d-three-tier

# Option B — copy from your laptop
# scp -i key.pem -r ./d-three-tier ubuntu@<HOST>:/home/ubuntu/
```

The **database host does not need** this repo — only MongoDB.

---

### 1. Install Node.js + npm (frontend + backend hosts)

Install **Node.js 20 LTS** (includes `npm`) on both the **client** and **server** machines.

```bash
sudo apt update
sudo apt install -y ca-certificates curl gnupg

curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

node -v   # v20.x
npm -v
```

**Alternative (nvm):**

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
source ~/.bashrc
nvm install 20
nvm use 20
node -v && npm -v
```

---

### 2. Install MongoDB (database host only)

Install on the **DB** machine. Then bind to the private IP so the backend can connect (not only `127.0.0.1`).

**Ubuntu 22.04 (MongoDB 7.0):**

```bash
sudo apt update
sudo apt install -y curl gnupg

curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc \
  | sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor

echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" \
  | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list

sudo apt update
sudo apt install -y mongodb-org

sudo systemctl enable mongod
sudo systemctl start mongod
sudo systemctl status mongod
```

**Allow remote connections from the backend (required):**

```bash
# Find this host's private IP, e.g. 10.0.3.10 or 192.168.56.30
ip -4 addr show

# Edit config
sudo nano /etc/mongod.conf
```

Set:

```yaml
net:
  port: 27017
  bindIp: 127.0.0.1,<DB_PRIVATE_IP>
```

Example: `bindIp: 127.0.0.1,10.0.3.10`

```bash
sudo systemctl restart mongod

# Must show the private IP (or 0.0.0.0), not only 127.0.0.1
sudo ss -tlnp | grep 27017

# Local smoke test
mongosh --eval 'db.runCommand({ ping: 1 })'
```

If `ss` only shows `127.0.0.1:27017`, the backend **cannot** connect and you will see `ECONNREFUSED` from other hosts — even if the security group allows port 27017.

---

### 3. Install and run the backend / server (`service/`)

On the **backend** host (Node.js already installed):

```bash
cd ~/d-three-tier/service   # or your clone path
npm install

cp .env.example .env
nano .env
```

`service/.env` on a deployed private network:

```bash
PORT=5000
MONGODB_URI=mongodb://<DB_PRIVATE_IP>:27017/todo-app
```

Examples:

```bash
MONGODB_URI=mongodb://10.0.3.10:27017/todo-app
MONGODB_URI=mongodb://192.168.56.30:27017/todo-app
```

Install PM2 and start the API:

```bash
sudo npm install -g pm2

pm2 start src/index.js --name todo-api
pm2 save
pm2 startup
# run the command that PM2 prints (enables start on reboot)

pm2 status
pm2 logs todo-api --lines 50

curl http://127.0.0.1:5000/api/health
# expect: {"status":"ok"}
```

From the **frontend** host, confirm private access:

```bash
curl http://<BE_PRIVATE_IP>:5000/api/health
```

---

### 4. Install and run the client / frontend (`client/` + Nginx)

On the **frontend** host (Node.js already installed):

```bash
cd ~/d-three-tier/client
npm install
npm run build
# static files land in client/dist
```

Install Nginx:

```bash
sudo apt update && sudo apt install -y nginx
```

Configure Nginx (adjust path/IP as needed):

```bash
sudo nano /etc/nginx/sites-available/todo
```

```nginx
server {
    listen 80;
    server_name _;

    root /home/ubuntu/d-three-tier/client/dist;
    index index.html;

    location /api/ {
        proxy_pass http://<BE_PRIVATE_IP>:5000/api/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

Enable and start:

```bash
sudo ln -sf /etc/nginx/sites-available/todo /etc/nginx/sites-enabled/todo
sudo rm -f /etc/nginx/sites-enabled/default

sudo nginx -t
sudo systemctl enable nginx
sudo systemctl restart nginx

curl -I http://127.0.0.1/
curl http://127.0.0.1/api/health
```

---

### Install checklist by host


| Host | Install |
|------|---------|
| **Database** | MongoDB only → bind private IP → SG/firewall allows BE → `27017` |
| **Backend** | Node.js + npm → `service/` `npm install` → `.env` → PM2 |
| **Frontend** | Node.js + npm → `client/` `npm install` + `npm run build` → Nginx + `/api` proxy |

---



## Path A — AWS deployment



### A1. VPC networking (manual)

Create (console or CLI — values below are examples):


| Resource                  | Example                                                 |
| ------------------------- | ------------------------------------------------------- |
| VPC CIDR                  | `10.0.0.0/16`                                           |
| Public subnet (AZ-a)      | `10.0.1.0/24` — Frontend                                |
| Private subnet app (AZ-a) | `10.0.2.0/24` — Backend                                 |
| Private subnet db (AZ-a)  | `10.0.3.0/24` — MongoDB                                 |
| Internet Gateway          | Attach to VPC                                           |
| NAT Gateway               | In **public** subnet (for BE outbound installs/updates) |
| Public route table        | `0.0.0.0/0` → IGW                                       |
| Private route table       | `0.0.0.0/0` → NAT Gateway                               |


Associate:

- Public subnet → public route table  
- Both private subnets → private route table



### A2. Security groups


| SG            | Inbound   | Source                   | Purpose              |
| ------------- | --------- | ------------------------ | -------------------- |
| `sg-frontend` | TCP 22    | Your IP                  | SSH                  |
| `sg-frontend` | TCP 80    | `0.0.0.0/0`              | HTTP                 |
| `sg-frontend` | TCP 443   | `0.0.0.0/0`              | HTTPS (optional)     |
| `sg-backend`  | TCP 22    | `sg-frontend` or bastion | SSH via jump         |
| `sg-backend`  | TCP 5000  | `sg-frontend`            | API from Nginx only  |
| `sg-database` | TCP 22    | `sg-backend` or bastion  | SSH via jump         |
| `sg-database` | TCP 27017 | `sg-backend`             | MongoDB from BE only |


Outbound: allow all (default) so instances can use NAT for packages.

### A3. EC2 instances


| Role     | Subnet                | Public IP | SG            |
| -------- | --------------------- | --------- | ------------- |
| Frontend | Public `10.0.1.0/24`  | **Yes**   | `sg-frontend` |
| Backend  | Private `10.0.2.0/24` | **No**    | `sg-backend`  |
| Database | Private `10.0.3.0/24` | **No**    | `sg-database` |


Use **Ubuntu 22.04**. Note private IPs after launch (e.g. BE `10.0.2.20`, DB `10.0.3.10`).

SSH to private hosts via the frontend (bastion):

```bash
# From your laptop → frontend
ssh -i key.pem ubuntu@<FRONTEND_PUBLIC_IP>

# From frontend → backend / db
ssh -i key.pem ubuntu@10.0.2.20
ssh -i key.pem ubuntu@10.0.3.10
```

(Copy your key to the frontend host securely, or use SSH agent forwarding.)

### A4. Database host

Follow **§2. Install MongoDB** above. Use this host’s private IP in `bindIp` (e.g. `127.0.0.1,10.0.3.10`).

```bash
sudo systemctl status mongod
sudo ss -tlnp | grep 27017
mongosh --eval 'db.runCommand({ ping: 1 })'
```

From the **backend** host, test:

```bash
nc -vz 10.0.3.10 27017
# optional, if mongosh is installed on BE:
# mongosh --host 10.0.3.10 --eval 'db.runCommand({ ping: 1 })'
```



### A5. Backend host (PM2)

Follow **§1. Install Node.js** and **§3. Install and run the backend** above.

```bash
cd /path/to/d-three-tier/service
npm install
cp .env.example .env
```

`service/.env`:

```bash
PORT=5000
MONGODB_URI=mongodb://10.0.3.10:27017/todo-app
```

Start with PM2:

```bash
pm2 start src/index.js --name todo-api
pm2 save
pm2 startup
# run the command PM2 prints to enable start on reboot

pm2 status
curl http://127.0.0.1:5000/api/health
```

Confirm from the **frontend** host (replace BE private IP):

```bash
curl http://10.0.2.20:5000/api/health
# should return {"status":"ok"}
```

Confirm from the **public internet** that port 5000 is **not** reachable on the frontend public IP (and backend has no public IP).

### A6. Frontend host (Nginx)

Follow **§1. Install Node.js** and **§4. Install and run the client** above.

Build the client on the FE host (or build elsewhere and copy `dist/`):

```bash
cd /path/to/d-three-tier/client
npm install
npm run build
```

Install Nginx and point it at `dist`, proxying API to the private backend:

```bash
sudo apt update && sudo apt install -y nginx
```

Example site config (`/etc/nginx/sites-available/todo`):

```nginx
server {
    listen 80;
    server_name _;

    root /path/to/d-three-tier/client/dist;
    index index.html;

    location /api/ {
        proxy_pass http://10.0.2.20:5000/api/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

Enable and reload:

```bash
sudo ln -s /etc/nginx/sites-available/todo /etc/nginx/sites-enabled/todo  # Debian/Ubuntu
sudo nginx -t
sudo systemctl enable nginx
sudo systemctl restart nginx
```

Open `http://<FRONTEND_PUBLIC_IP>/` in a browser. Create a todo — it should hit `/api` via Nginx → private backend → private MongoDB.

### A7. AWS verification


| Test                            | Expected         |
| ------------------------------- | ---------------- |
| Browser → `http://<public-ip>/` | UI loads         |
| Browser → add/list todos        | Works            |
| `curl http://<public-ip>:5000`  | Fails / filtered |
| Public scan of DB `27017`       | Not reachable    |
| BE → DB `27017`                 | OK               |
| FE → BE `5000`                  | OK               |


---



## Path B — Local VM deployment

Use VirtualBox, VMware, UTM, or similar. Three VMs on a **host-only / private** network, with the frontend also reachable externally via **ngrok** or **Cloudflare Tunnel**.

### B1. Suggested VM layout


| VM      | Role             | Example private IP | Extra              |
| ------- | ---------------- | ------------------ | ------------------ |
| `vm-fe` | Frontend + Nginx | `192.168.56.10`    | Tunnel to internet |
| `vm-be` | Backend + PM2    | `192.168.56.20`    | Private only       |
| `vm-db` | MongoDB          | `192.168.56.30`    | Private only       |


Networking tips:

- Give all three VMs a shared private network (e.g. VirtualBox Host-Only `192.168.56.0/24`).
- Optionally give `vm-fe` NAT as well so it can download packages and run a tunnel.
- Do **not** publish BE/DB ports on the host’s public interface.



### B2. Firewall (ufw example)

**Frontend (**`vm-fe`**):**

```bash
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw enable
```

**Backend (**`vm-be`**):**

```bash
sudo ufw default deny incoming
sudo ufw allow from 192.168.56.10 to any port 22
sudo ufw allow from 192.168.56.10 to any port 5000
sudo ufw enable
```

**Database (**`vm-db`**):**

```bash
sudo ufw default deny incoming
sudo ufw allow from 192.168.56.20 to any port 22
sudo ufw allow from 192.168.56.20 to any port 27017
sudo ufw enable
```



### B3. Database VM

Follow **§2. Install MongoDB**. Set `bindIp: 127.0.0.1,192.168.56.30`, then restart `mongod`.

Test from backend VM:

```bash
nc -vz 192.168.56.30 27017
```



### B4. Backend VM

Follow **§1** and **§3**. Then:

```bash
cd service
npm install
```

`service/.env`:

```bash
PORT=5000
MONGODB_URI=mongodb://192.168.56.30:27017/todo-app
```

```bash
pm2 start src/index.js --name todo-api
pm2 save
pm2 startup
curl http://127.0.0.1:5000/api/health
```

From frontend VM:

```bash
curl http://192.168.56.20:5000/api/health
```



### B5. Frontend VM + Nginx

Follow **§1** and **§4**. Then:

```bash
cd client
npm install
npm run build
```

Nginx config — same as AWS, but proxy to the BE private IP:

```nginx
location /api/ {
    proxy_pass http://192.168.56.20:5000/api/;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
}
```

Serve `client/dist` on port 80. Verify on the private network:

```bash
curl http://192.168.56.10/
curl http://192.168.56.10/api/health
```



### B6. Expose only the frontend (tunnel)

Pick one.

#### Option: ngrok

On `vm-fe` (after Nginx is up on port 80):

```bash
# install ngrok, then:
ngrok http 80
```

Share the `https://....ngrok-free.app` URL. Do **not** tunnel port 5000 or 27017.

#### Option: Cloudflare Tunnel

On `vm-fe`:

```bash
# install cloudflared, login, then e.g.:
cloudflared tunnel --url http://localhost:80
```

Or create a named tunnel in the Cloudflare Zero Trust dashboard pointing to `http://localhost:80`.

### B7. Local VM verification


| Test                                               | Expected                      |
| -------------------------------------------------- | ----------------------------- |
| Tunnel URL opens UI                                | OK                            |
| Todos create/list via tunnel                       | OK                            |
| From another machine on LAN, BE `:5000` without FE | Blocked / not routed publicly |
| DB `:27017` from FE VM                             | Should fail (only BE allowed) |
| DB `:27017` from BE VM                             | OK                            |


---



## Nginx ↔ backend contract (important)

This app’s client uses relative paths like `/api/todos`.


| Environment               | How `/api` reaches Express                                   |
| ------------------------- | ------------------------------------------------------------ |
| Local dev (`npm run dev`) | Vite proxy → `localhost:5001` (avoids macOS AirPlay on 5000) |
| Deployed                  | Nginx `location /api/` → `http://<BE_PRIVATE_IP>:5000`       |


Do not open backend port 5000 to `0.0.0.0/0`. On macOS local dev, use `5001` — AirPlay Receiver often binds `5000` and returns `403`.

---



## Quick command reference

```bash
# Backend
cd service && npm install
pm2 start src/index.js --name todo-api
pm2 logs todo-api
pm2 restart todo-api

# Frontend build
cd client && npm install && npm run build

# Health checks
curl http://127.0.0.1:5000/api/health          # on BE
curl http://<BE_PRIVATE_IP>:5000/api/health    # from FE
curl http://<FE_HOST>/api/health               # via Nginx
```

---



## What to document for the assignment

Include screenshots or notes of:

1. Network diagram (subnets / VMs and IPs)
2. Security group or firewall rules table
3. `pm2 status` on backend
4. Nginx config showing `/api` proxy to private IP
5. Browser working via public IP or tunnel
6. Proof that backend/DB are not publicly reachable

---



## Troubleshooting


| Problem                             | Check                                                           |
| ----------------------------------- | --------------------------------------------------------------- |
| UI loads, API fails                 | Nginx `proxy_pass` IP/port; BE SG allows FE; `pm2 status`       |
| Backend cannot connect to Mongo     | `MONGODB_URI` IP; Mongo `bindIp`; DB SG allows BE only          |
| `ECONNREFUSED` on FE → BE           | Backend down, wrong private IP, or firewall                     |
| Blank page after deploy             | Wrong Nginx `root` (must be `client/dist`); run `npm run build` |
| Works on private IP, not via tunnel | Tunnel target must be FE `:80`, not BE                          |


