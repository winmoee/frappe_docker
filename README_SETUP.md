# ERPNext Docker Setup Guide (macOS / Apple Silicon)

This guide summarizes the steps taken to successfully deploy ERPNext on a Mac (Intel or M1/M2/M3) using `docker-compose`.

## 1. Environment Configuration

The following environment variables should be set in a `.env` file in the root directory. You can start by copying `example.env` to `.env`.

### Required `.env` Highlights
| Variable | Value | Description |
| :--- | :--- | :--- |
| `ERPNEXT_VERSION` | `latest` | Use `latest` for the most recent V16 compatible images. |
| `DB_PASSWORD` | `123` | Password for the MariaDB user. |
| `HTTP_PUBLISH_PORT` | `8080` | The port you will use to access the site (e.g., `http://localhost:8080`). |

> [!IMPORTANT]
> For Mac Apple Silicon (M1/M2/M3), ensure the `pwd.yml` uses `platform: linux/arm64` for all services.

## 2. Starting the Services

Run the following command to pull images and start the containers in the background:

```bash
docker compose -f pwd.yml up -d
```

## 3. Initializing the Site

Once the containers are running, you need to create the site and install the ERPNext application. 

**Command:**
```bash
docker compose -f pwd.yml exec backend bench new-site frontend \
    --admin-password admin \
    --db-password 123 \
    --mariadb-root-password 123 \
    --install-app erpnext \
    --force
```

*Note: Replace `frontend` with your desired site name if different.*

## 4. Fixing Frontend Styling Issues (Text-only display)

If you log in and see only text without any formatting (no CSS), this is usually due to the frontend container being unable to follow symbolic links to the assets directory.

### The Fix: Resolve Symlinks to Real Files
Run this command to replace the broken symlinks in the shared assets volume with actual file copies:

```bash
docker compose -f pwd.yml exec backend bash -c "cd sites/assets && for dir in frappe erpnext; do if [ -L \$dir ]; then echo Resolving \$dir; cp -rL \$dir \${dir}_copy && rm \$dir && mv \${dir}_copy \$dir; fi; done"
```

## 5. Daily Maintenance Commands

- **Stop Services:** `docker compose -f pwd.yml stop`
- **Start Services:** `docker compose -f pwd.yml start`
- **View Logs:** `docker compose -f pwd.yml logs -f frontend` (or `backend`)
- **Run Migrations:** `docker compose -f pwd.yml exec backend bench --site frontend migrate`
