# ============================================================================
# Dockerfile — Willow dbt project
# ============================================================================
# Containerized dbt is the standard way to run transformations on a schedule
# (Airflow/Dagster/CI): a pinned dbt version + adapter + your project, running
# identically every time. We use uv inside the build for fast, locked installs.
#
# Build:  docker build -t willow-dbt .
# Run  :  docker run --rm willow-dbt                       # default: dbt build
#         docker run --rm willow-dbt dbt test --profiles-dir .
#         docker run --rm -v "$PWD":/app willow-dbt dbt docs generate --profiles-dir .
# ============================================================================

FROM python:3.12-slim

# uv binary from its official image.
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    # keep dbt's profile lookup inside the project
    DBT_PROFILES_DIR=/app

WORKDIR /app

# Install deps first (cached until pyproject/lock change).
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-install-project

# Copy the project and finish the env.
COPY . .
RUN uv sync --frozen

ENV PATH="/app/.venv/bin:$PATH"

# Default: build the whole project (seeds -> models -> tests -> snapshot).
# DBT_PROFILES_DIR is set above, so we don't need --profiles-dir here.
CMD ["dbt", "build"]
