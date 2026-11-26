# ---------------------------------------------------------------
# Dockerfile multi-stage pour Task Manager
#   Stage 1 (builder) : installe les dépendances Python
#   Stage 2 (runtime) : image finale légère qui lance l'application
# La version de Python est paramétrable (utile pour la parallélisation) :
#   docker build --build-arg PYTHON_VERSION=3.11 -t task-manager .
# ---------------------------------------------------------------
ARG PYTHON_VERSION=3.12

# ---------- Stage 1 : builder ----------
FROM python:${PYTHON_VERSION}-slim AS builder
WORKDIR /build
# On copie d'abord requirements.txt seul : Docker garde cette couche
# en cache tant que les dépendances ne changent pas (build plus rapide).
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ---------- Stage 2 : runtime ----------
FROM python:${PYTHON_VERSION}-slim
ARG APP_VERSION=dev
ENV APP_VERSION=${APP_VERSION} \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1
WORKDIR /app

# On récupère uniquement les paquets installés (pas les outils de build)
COPY --from=builder /install /usr/local
COPY app/ .

# Utilisateur non-root (bonne pratique de sécurité)
RUN useradd --create-home appuser
USER appuser

EXPOSE 5000
# 1 worker : les tâches sont en mémoire, il faut un seul processus
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "1", "app:app"]
