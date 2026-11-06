FROM python:3.13-slim

WORKDIR /app

# Cài đặt các thư viện cần thiết để build bcrypt
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

COPY pyproject.toml .

RUN pip install --no-cache-dir .

COPY src/ ./src/

# Môi trường Database lưu ở thư mục /data riêng biệt nhằm dễ mount volume bảo vệ dữ liệu SQLite
ENV PYTHONPATH=/app/src
ENV DATABASE_URL="sqlite:////data/totp_sync.db"

# Khởi tạo thư mục DB
RUN mkdir -p /data

EXPOSE 8000

CMD ["sh", "-c", "uvicorn server.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
