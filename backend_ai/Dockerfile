# AI 코치 서버 배포용 Dockerfile
FROM python:3.10-slim

WORKDIR /app

# 필수 패키지 설치
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 소스 코드 복사
COPY . .

# 포트 설정 (Render 환경 대응)
ENV PORT=8000
EXPOSE 8000

# Render는 PORT 환경변수를 주입함 — 로컬 기본 8000
CMD ["sh", "-c", "exec uvicorn main:app --host 0.0.0.0 --port ${PORT:-8000}"]
