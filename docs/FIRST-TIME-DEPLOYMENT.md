# ChiroERP First-Time Deployment Guide

## 🎯 Quick Start (First Time Only)

### Step 1: Build the Applications (5-10 minutes)

```powershell
# Build all microservices
.\gradlew.bat build -x test

# Or build with tests (takes longer):
.\gradlew.bat build
```

**What this does:**

-   Compiles all 8 microservices
-   Creates JVM-ready artifacts in `build/quarkus-app/`
-   Downloads dependencies (~500MB)

---

### Step 2: Start Infrastructure Services (2-3 minutes)

```powershell
# Start infrastructure first
docker-compose up -d postgresql redis kafka zookeeper minio keycloak prometheus grafana
```

**Wait for these to be healthy before proceeding:**

```powershell
# Check status
docker-compose ps

# Watch logs
docker-compose logs -f postgresql
```

---

### Step 3: Start Microservices (2-3 minutes)

```powershell
# After infrastructure is ready, start microservices
docker-compose up -d core-platform analytics-intelligence commerce customer-relationship financial-management logistics-transportation operations-service supply-chain-manufacturing
```

---

### Step 4: Verify Deployment

```powershell
# Run comprehensive tests
.\scripts\test-deployment.ps1

# Or check manually
docker-compose ps
docker stats
```

---

## 🔧 Current Issue: Build Required

### What Happened?

The deployment failed with:

```
"/build/quarkus-app/quarkus": not found
```

**Root Cause:** The Quarkus applications weren't built yet. Docker tried to copy build artifacts that don't exist.

### Solution:

**Run this command first:**

```powershell
.\gradlew.bat build -x test
```

This will:

1. ✅ Compile all 8 microservices
2. ✅ Create necessary JVM artifacts
3. ✅ Prepare for Docker image building

---

## 📋 Complete Deployment Workflow

### First-Time Setup (Do Once)

1. **Install Prerequisites**

    - ✅ Docker Desktop (already installed)
    - ✅ JDK 21 (check: `java -version`)
    - ✅ Gradle (bundled with gradlew)

2. **Build Applications**

    ```powershell
    .\gradlew.bat clean build -x test
    ```

    Expected time: 5-10 minutes

3. **Start Infrastructure**

    ```powershell
    docker-compose up -d postgresql redis kafka zookeeper minio keycloak
    ```

    Expected time: 2-3 minutes

4. **Verify Infrastructure**

    ```powershell
    # PostgreSQL should be ready
    docker-compose logs postgresql | Select-String "database system is ready"

    # All infrastructure healthy
    docker-compose ps | Where-Object { $_ -match "Up" }
    ```

5. **Start Microservices**

    ```powershell
    docker-compose up -d
    ```

    Expected time: 2-3 minutes

6. **Verify Everything**
    ```powershell
    .\scripts\test-deployment.ps1
    ```

---

### Subsequent Deployments (Quick)

After the first time, you can start everything at once:

```powershell
# Start all services
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f
```

---

## 🐛 Troubleshooting

### Issue: Gradle Build Fails

**Check Java Version:**

```powershell
java -version  # Should be JDK 21
```

**Clean and Rebuild:**

```powershell
.\gradlew.bat clean
.\gradlew.bat build -x test
```

### Issue: Out of Memory During Build

**Increase Gradle memory:**
Edit `gradle.properties` and add:

```properties
org.gradle.jvmargs=-Xmx4g -XX:MaxMetaspaceSize=1g
```

### Issue: Docker Build Fails

**Check build artifacts exist:**

```powershell
# Should see quarkus-app directory
Get-ChildItem services/core-platform/build/
```

**If missing, rebuild:**

```powershell
.\gradlew.bat :services:core-platform:build -x test
```

### Issue: Services Won't Start

**Check logs:**

```powershell
docker-compose logs core-platform
docker-compose logs postgresql
```

**Restart specific service:**

```powershell
docker-compose restart core-platform
```

---

## 📊 Build Size Expectations

### Gradle Build

-   **Download size:** ~500 MB (dependencies)
-   **Build artifacts:** ~200 MB (all 8 services)
-   **Build time:** 5-10 minutes (first time)
-   **Subsequent builds:** 1-2 minutes (cached)

### Docker Images

-   **Infrastructure:** ~2 GB (PostgreSQL, Kafka, etc.)
-   **Microservices:** ~1.5 GB (8 services)
-   **Total:** ~3.5 GB disk space needed

---

## ⚡ Quick Commands Reference

### Build Commands

```powershell
# Build everything
.\gradlew.bat build -x test

# Build specific service
.\gradlew.bat :services:core-platform:build

# Clean build
.\gradlew.bat clean build

# Show build tasks
.\gradlew.bat tasks
```

### Docker Commands

```powershell
# Start all
docker-compose up -d

# Start specific services
docker-compose up -d postgresql redis keycloak

# Stop all
docker-compose down

# Stop and remove volumes
docker-compose down -v

# View logs
docker-compose logs -f <service-name>

# Restart service
docker-compose restart <service-name>

# Rebuild and start
docker-compose up -d --build
```

### Status Commands

```powershell
# Check containers
docker-compose ps

# Check resources
docker stats

# Run tests
.\scripts\test-deployment.ps1

# Monitor resources
.\scripts\monitor-resources.ps1
```

---

## 🎓 Understanding the Build Process

### Gradle Build Phases

1. **Dependency Resolution**

    - Downloads Quarkus, Kotlin, and other dependencies
    - Creates local Maven cache (~/.gradle)

2. **Compilation**

    - Compiles Kotlin code to JVM bytecode
    - Processes Quarkus annotations

3. **Packaging**
    - Creates quarkus-app structure
    - Bundles dependencies
    - Prepares for JVM deployment

### Docker Build Phases

1. **Base Image**

    - Pulls Red Hat UBI OpenJDK 21

2. **Copy Artifacts**

    - Copies build/quarkus-app/ to container

3. **Configuration**
    - Sets up user permissions
    - Configures runtime

---

## 🚀 Optimal Deployment Strategy

### For Development (Your Current Setup)

1. Build once: `.\gradlew.bat build -x test`
2. Start infrastructure: `docker-compose up -d postgresql redis kafka keycloak`
3. Wait 60 seconds
4. Start microservices: `docker-compose up -d`
5. Monitor: `.\scripts\monitor-resources.ps1`

### For Testing

1. Build with tests: `.\gradlew.bat build`
2. Start all: `docker-compose up -d`
3. Run health checks: `.\scripts\test-deployment.ps1`

### For Production

1. Build optimized: `.\gradlew.bat build -Dquarkus.package.type=fast-jar`
2. Use production secrets (not .env defaults)
3. Configure monitoring and backups
4. Set up CI/CD pipeline

---

## 📝 Next Steps After Successful Build

Once `.\gradlew.bat build` completes:

1. ✅ **Verify Build Artifacts**

    ```powershell
    Get-ChildItem services/*/build/quarkus-app/
    ```

2. ✅ **Start Infrastructure**

    ```powershell
    docker-compose up -d postgresql redis kafka zookeeper keycloak minio
    ```

3. ✅ **Wait for Infrastructure (60 seconds)**

    ```powershell
    Start-Sleep -Seconds 60
    docker-compose logs postgresql | Select-String "ready"
    ```

4. ✅ **Start Microservices**

    ```powershell
    docker-compose up -d
    ```

5. ✅ **Monitor Startup**

    ```powershell
    .\scripts\monitor-resources.ps1
    ```

6. ✅ **Test Health Endpoints**
    ```powershell
    .\scripts\test-deployment.ps1
    ```

---

## 💡 Pro Tips

1. **Speed Up Builds**

    - Enable Gradle daemon (already on by default)
    - Use `--parallel` flag for parallel builds
    - Enable build cache

2. **Reduce Docker Image Size**

    - Use `.dockerignore` to exclude unnecessary files
    - Multi-stage builds (already configured)
    - Alpine-based images where possible

3. **Monitor During Build**

    ```powershell
    # In separate terminal
    Get-Process gradle | Select-Object CPU, WorkingSet
    ```

4. **Save Time on Rebuilds**
    - Only rebuild changed services
    - Use Docker layer caching
    - Keep Gradle daemon running

---

## ⏱️ Expected Timeline (First-Time Deployment)

| Step                    | Duration      | Description                   |
| ----------------------- | ------------- | ----------------------------- |
| 1. Gradle build         | 5-10 min      | Compile all microservices     |
| 2. Infrastructure start | 2-3 min       | PostgreSQL, Kafka, etc.       |
| 3. Microservices start  | 2-3 min       | Build Docker images           |
| 4. Health checks        | 1-2 min       | Wait for ready state          |
| **Total**               | **10-18 min** | **Complete first deployment** |

**Subsequent deployments:** 3-5 minutes (everything cached)

---

## 📞 Getting Help

If you encounter issues:

1. Check this guide's troubleshooting section
2. Review logs: `docker-compose logs <service>`
3. Check docs: `/docs/TESTING-GUIDE.md`
4. Verify resources: `docker stats`
5. Clean slate: `docker-compose down -v && .\gradlew.bat clean`

---

**Current Status:** Gradle build is running. Wait for it to complete, then continue with docker-compose deployment.
