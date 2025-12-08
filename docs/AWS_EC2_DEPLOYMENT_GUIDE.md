# AWS EC2 Deployment Guide - Step by Step

**EC2 Instance Details:**
- **Instance ID:** `i-00748607a814c98d2`
- **Public IPv4:** `16.171.154.81`
- **Private IPv4:** `172.31.42.115`
- **Public DNS:** `ec2-16-171-154-81.eu-north-1.compute.amazonaws.com`
- **Region:** `eu-north-1`
- **API Gateway URL:** `https://peyru94f1e.execute-api.eu-north-1.amazonaws.com`

---

## Step 1: Connect to EC2 via SSH

### On Windows (PowerShell with OpenSSH):

```powershell
# Make sure your .pem key has correct permissions (if using WSL/Git Bash)
# In PowerShell, navigate to where your .pem key is located

ssh -i C:\path\to\your-key.pem ubuntu@16.171.154.81
```

**What to expect:**
- First time: You'll see a message about host authenticity, type `yes`
- If successful, you'll see: `ubuntu@ip-172-31-42-115:~$`

**Troubleshooting:**
- If you get "Permission denied (publickey)": Check that your .pem key path is correct
- If you get "Connection timeout": Check Security Group allows SSH (port 22) from your IP

---

## Step 2: Install Docker + Docker Compose

Once connected to EC2, run these commands:

```bash
# Update package list
sudo apt-get update

# Upgrade existing packages
sudo apt-get upgrade -y

# Install Docker
curl -fsSL https://get.docker.com | sudo sh

# Add ubuntu user to docker group (so you don't need sudo)
sudo usermod -aG docker ubuntu
```

**Important:** You need to disconnect and reconnect for the group change to take effect:

```bash
# Exit SSH
exit

# Reconnect
ssh -i C:\path\to\your-key.pem ubuntu@16.171.154.81
```

**Verify Docker is installed:**

```bash
docker version
docker compose version
# If the above doesn't work, try:
docker-compose version
```

You should see Docker version information. If you see "permission denied", you didn't reconnect after adding yourself to the docker group.

---

## Step 3: Copy Project to EC2

You have two options:

### Option A: Clone from GitHub/GitLab (Recommended)

**On EC2:**

```bash
cd ~
git clone https://github.com/your-username/your-repo.git backend
cd backend
```

**Note:** If your repo is private, you'll need to:
- Set up SSH keys on EC2, OR
- Use a personal access token in the URL

### Option B: Upload from Local Machine

**On your local machine (in PowerShell):**

```powershell
# Navigate to your project root
cd C:\path\to\PDM

# Create a zip (excluding node_modules, .git, etc.)
# You might want to create a .zip manually or use:
Compress-Archive -Path * -DestinationPath projeto.zip -Force
```

**Then upload:**

```powershell
scp -i C:\path\to\your-key.pem projeto.zip ubuntu@16.171.154.81:~/
```

**Back on EC2:**

```bash
cd ~
unzip projeto.zip -d backend
cd backend
```

**Verify you have the files:**

```bash
ls
# You should see: docker-compose.yml, backend/, Frontend/, etc.
```

---

## Step 4: Prepare Environment Variables

**On EC2, in the project root:**

```bash
# Copy the example env file
cp backend/env.example backend/.env

# Edit the .env file
nano backend/.env
```

### Key Things to Configure in `.env`:

1. **Database Password:**
   ```
   POSTGRES_PASSWORD=your-strong-password-here
   ```
   Generate a strong password (not "postgres"!)

2. **JWT Secret:**
   ```
   JWT_SECRET=your-very-long-random-secret-key-here
   ```
   Generate a long random string (not the default!)

3. **Node Environment:**
   ```
   NODE_ENV=production
   ```

4. **OTP Base URL:**
   ```
   OTP_BASE_URL=http://otp:8080
   ```
   Note: No `/otp` suffix - the backend will append `/routers/default/index/graphql`

5. **Mapbox API Key:**
   ```
   MAPBOX_API_KEY=your-actual-mapbox-token
   ```

6. **Database URL:**
   ```
   DATABASE_URL=postgresql://postgres:your-strong-password-here@postgres:5432/sustainable_transport?schema=public
   ```
   Use the same password as POSTGRES_PASSWORD

7. **Other API Keys:**
   - `METRO_LISBOA_CLIENT_ID` (if you have it)
   - `METRO_LISBOA_CLIENT_SECRET` (if you have it)
   - `WATHER_API_KEY` (if you have it)
   - `TRANSPORT_API_KEY` (if you have it)

**Save and exit nano:**
- Press `Ctrl+O` (write out)
- Press `Enter` (confirm filename)
- Press `Ctrl+X` (exit)

---

## Step 5: Review docker-compose.yml

**On EC2:**

```bash
nano docker-compose.yml
```

### Things to Check:

1. **Backend port is exposed:**
   ```yaml
   backend:
     ports:
       - "3000:3000"
   ```

2. **Backend binds to 0.0.0.0:**
   - Check `backend/src/main.ts` - it should have `await app.listen(port, '0.0.0.0')`
   - This is already correct in your codebase ✅

3. **Volumes point to correct paths:**
   ```yaml
   volumes:
     - ./EXTERNALS/otp/build:/var/opentripplanner
   ```
   Make sure `./EXTERNALS/otp/build` exists on EC2 (or create it)

4. **Environment variables:**
   - The docker-compose.yml should use environment variables from `.env`
   - Or you can hardcode them (less secure)

5. **Production mode:**
   - Backend should use `NODE_ENV=production`
   - Backend command should be `npm run start:prod` (not `start:dev`)

**Exit nano:** `Ctrl+X`

---

## Step 6: Create Required Directories

**On EC2:**

```bash
# Make sure EXTERNALS directory exists (for OTP data)
mkdir -p EXTERNALS/otp/build

# If you have OTP build data, you'll need to copy it here
# For now, OTP will try to load from this directory
```

**Note:** If you don't have OTP build data yet, OTP might fail to start. You can:
- Copy your local `EXTERNALS/otp/build` to EC2, OR
- Comment out the OTP service temporarily, OR
- Let OTP start and it will create an empty router (won't work for routing, but won't crash)

---

## Step 7: Build and Start Services

**On EC2, in project root:**

```bash
# Pull any pre-built images (optional)
docker compose pull

# Build services that need building (backend)
docker compose build

# Start all services in detached mode
docker compose up -d
```

**What this does:**
- `-d` runs containers in the background
- Services start in dependency order (postgres → redis → backend)

**Check if containers are running:**

```bash
docker compose ps
```

You should see all services with status "Up":
- `sustainable_transport_db` (postgres)
- `sustainable_transport_redis` (redis)
- `sustainable_transport_mongo` (mongo)
- `sustainable_transport_api` (backend)
- `otp` (OpenTripPlanner)

---

## Step 8: Check Logs

**View backend logs:**

```bash
docker compose logs backend -f
```

**What to look for:**
- ✅ `🚀 Sustainable Transport API running on port 3000`
- ✅ No error messages
- ✅ Database connection successful

**View all logs:**

```bash
docker compose logs -f
```

**Exit logs:** Press `Ctrl+C`

---

## Step 9: Run Database Migrations

**On EC2:**

```bash
# Enter the backend container
docker compose exec backend sh

# Inside the container, run migrations
npx prisma migrate deploy

# If you need to generate Prisma client
npx prisma generate

# Exit container
exit
```

**Alternative (one-liner):**

```bash
docker compose exec backend npx prisma migrate deploy
```

---

## Step 10: Test from Your Local Machine

**In your browser or using curl:**

```bash
# Health check
curl http://16.171.154.81:3000/health

# Or open in browser:
http://16.171.154.81:3000/health
```

**Expected response:**
```json
{
  "status": "ok",
  "timestamp": "2025-01-12T..."
}
```

**Test another endpoint:**

```bash
curl http://16.171.154.81:3000/gbfs/systems
```

---

## Step 11: Configure Security Group

**If you can't connect (connection timeout):**

1. Go to AWS Console → EC2 → Instances
2. Select your instance: `i-00748607a814c98d2`
3. Click "Security" tab
4. Click on the Security Group link
5. Click "Edit inbound rules"
6. Add rule:
   - **Type:** Custom TCP
   - **Port:** 3000
   - **Source:** 0.0.0.0/0 (or your IP for security)
   - **Description:** Backend API
7. Click "Save rules"

**Also ensure SSH (port 22) is allowed from your IP**

---

## Step 12: API Gateway Configuration

**Important:** The API Gateway is already configured to proxy to your EC2:

- **API Gateway URL:** `https://peyru94f1e.execute-api.eu-north-1.amazonaws.com`
- **EC2 Backend:** `http://ec2-16-171-154-81.eu-north-1.compute.amazonaws.com:3000`

**How it works:**
- Request to: `https://peyru94f1e.../auth/login`
- Proxies to: `http://ec2-16-171-154-81...:3000/auth/login`

**Test API Gateway:**

```bash
curl https://peyru94f1e.execute-api.eu-north-1.amazonaws.com/health
```

**Note:** You don't need to put the API Gateway URL in `.env` - it's handled by AWS API Gateway configuration.

---

## Step 13: Verify Everything Works

**Check all services:**

```bash
# On EC2
docker compose ps
```

All should show "Up" status.

**Test endpoints:**

```bash
# Health
curl http://16.171.154.81:3000/health

# GBFS systems
curl http://16.171.154.81:3000/gbfs/systems

# Routes (if OTP is working)
curl "http://16.171.154.81:3000/routes/plan?from=38.7223,-9.1393&to=38.7369,-9.1428"
```

---

## Troubleshooting

### Backend won't start

```bash
# Check logs
docker compose logs backend

# Common issues:
# - Database connection failed → Check DATABASE_URL in .env
# - Port already in use → Check if something else is using port 3000
# - Missing dependencies → Rebuild: docker compose build backend
```

### Database connection errors

```bash
# Check postgres is running
docker compose ps postgres

# Check postgres logs
docker compose logs postgres

# Verify DATABASE_URL in .env matches docker-compose.yml
```

### OTP not working

```bash
# Check OTP logs
docker compose logs otp

# OTP needs build data in EXTERNALS/otp/build
# If missing, OTP will start but won't have routing data
```

### Can't connect from outside

1. Check Security Group allows port 3000
2. Check backend is listening on 0.0.0.0 (not localhost)
3. Check EC2 instance is running

### Container keeps restarting

```bash
# Check why it's restarting
docker compose ps
docker compose logs backend

# Common causes:
# - Application crash (check logs)
# - Health check failing
# - Out of memory
```

---

## Next Steps After Deployment

1. **Set up monitoring** (CloudWatch, Sentry, etc.)
2. **Set up automated backups** for database
3. **Configure domain name** (optional)
4. **Set up SSL certificate** (if using a domain)
5. **Configure auto-restart** on EC2 reboot (docker-compose already has `restart: unless-stopped`)

---

## Quick Reference Commands

```bash
# View logs
docker compose logs -f backend

# Restart a service
docker compose restart backend

# Stop everything
docker compose down

# Start everything
docker compose up -d

# Rebuild and restart
docker compose up -d --build

# Check container status
docker compose ps

# Execute command in container
docker compose exec backend sh

# View resource usage
docker stats
```

---

## Important Notes

1. **Don't commit `.env` to git** - it contains secrets
2. **Change default passwords** - especially JWT_SECRET and POSTGRES_PASSWORD
3. **Backend must bind to 0.0.0.0** - already done ✅
4. **API Gateway URL doesn't go in .env** - it's configured in AWS
5. **OTP build data** - Make sure you have the OTP graph files in `EXTERNALS/otp/build`

---

## Summary Checklist

- [ ] Connected to EC2 via SSH
- [ ] Docker and Docker Compose installed
- [ ] Project copied to EC2
- [ ] `.env` file created with production values
- [ ] `docker-compose.yml` reviewed
- [ ] Required directories created (`EXTERNALS/otp/build`)
- [ ] Services built and started (`docker compose up -d`)
- [ ] Database migrations run (`npx prisma migrate deploy`)
- [ ] Health check works (`curl http://16.171.154.81:3000/health`)
- [ ] Security Group allows port 3000
- [ ] API Gateway tested (`curl https://peyru94f1e.../health`)

---

**Ready to deploy?** Follow these steps one by one, and let me know if you encounter any issues!

