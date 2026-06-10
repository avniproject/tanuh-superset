import os

# --- Secret key (injected at runtime; never commit a real value) ---
SECRET_KEY = os.getenv('SUPERSET_SECRET_KEY')

CONTENT_SECURITY_POLICY_WARNING = False

# Behind the ALB / reverse proxy
ENABLE_PROXY_FIX = True

FEATURE_FLAGS = {
    "ENABLE_TEMPLATE_PROCESSING": True,
    "TAGGING_SYSTEM": True,
    "ALLOW_FULL_CSV_EXPORT": True,
    "DASHBOARD_RBAC": True,
}

# --- Metadata DB (Superset's own application database; injected via env) ---
# NOTE: this is Superset's metadata DB, NOT the reporting data source.
DB_USER = os.getenv('SUPERSET_DB_USER')
DB_PASSWORD = os.getenv('SUPERSET_DB_PASSWORD')
DB_URL = os.getenv('SUPERSET_DB_URL')
DB_PORT = os.getenv('SUPERSET_DB_PORT')
DB_NAME = os.getenv('SUPERSET_DB_NAME')

SQLALCHEMY_DATABASE_URI = (
    "postgresql+psycopg2://" + DB_USER + ":" + DB_PASSWORD + "@" + DB_URL + ":" + DB_PORT + "/" + DB_NAME
)

# --- Tanuh branding ---
APP_NAME = "Tanuh"

THEME_DEFAULT = {
    "token": {
        "brandLogoUrl": "/static/assets/images/tanuh.png",
        "brandLogoHref": "/",
        "brandLogoAlt": "Tanuh",
    }
}

THEME_DARK = {
    "algorithm": "dark",
    "token": {
        "brandLogoUrl": "/static/assets/images/tanuh.png",
        "brandLogoHref": "/",
        "brandLogoAlt": "Tanuh",
    }
}

FAVICONS = [{"href": "/static/assets/images/tanuh.png"}]

# --- Logging ---
ENABLE_TIME_ROTATE = True
BACKUP_COUNT = 30
ROLLOVER = "midnight"
