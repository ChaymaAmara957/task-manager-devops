#!/bin/sh
# ---------------------------------------------------------------
# Smoke test : vérifie rapidement que l'application fonctionne.
# Usage : sh tests/smoke_test.sh <URL>     (ex: http://localhost:5000)
# Code de sortie 0 = PASSED, 1 = FAILED (Jenkins s'en sert pour le statut)
# ---------------------------------------------------------------
URL="${1:-http://localhost:5000}"
MAX_TRIES=15
FAILED=0

echo "=== Smoke test sur $URL ==="

# 1) Attendre que le conteneur/l'application démarre
i=1
until curl -s -o /dev/null "$URL/health"; do
    if [ "$i" -ge "$MAX_TRIES" ]; then
        echo "[FAIL] L'application ne répond pas après $MAX_TRIES essais"
        echo "SMOKE TEST: FAILED"
        exit 1
    fi
    echo "Attente du démarrage... ($i/$MAX_TRIES)"
    i=$((i + 1))
    sleep 2
done
echo "[OK] L'application a démarré"

# 2) Vérifier un code HTTP 200
check_status() {
    code=$(curl -s -o /dev/null -w "%{http_code}" "$URL$1")
    if [ "$code" = "200" ]; then
        echo "[OK] GET $1 -> HTTP $code"
    else
        echo "[FAIL] GET $1 -> HTTP $code (attendu 200)"
        FAILED=1
    fi
}
check_status "/"
check_status "/health"

# 3) Vérifier que la page principale affiche bien l'application
if curl -s "$URL/" | grep -q "Task Manager"; then
    echo "[OK] La page principale contient 'Task Manager'"
else
    echo "[FAIL] Le titre 'Task Manager' est absent de la page principale"
    FAILED=1
fi

# 4) Vérifier une fonctionnalité : ajouter une tâche puis la retrouver dans la page
code=$(curl -s -o /dev/null -w "%{http_code}" -d "title=tache-smoke-test" "$URL/add")
if [ "$code" = "302" ]; then
    echo "[OK] POST /add -> HTTP $code (redirection vers la liste)"
else
    echo "[FAIL] POST /add -> HTTP $code (attendu 302)"
    FAILED=1
fi
code=$(curl -s -o /tmp/page.html -w "%{http_code}" "$URL/")
if [ "$code" = "200" ] && grep -q "tache-smoke-test" /tmp/page.html; then
    echo "[OK] La tâche ajoutée apparaît dans la liste (HTTP $code)"
else
    echo "[FAIL] La liste avec une tâche ne s'affiche pas correctement (HTTP $code)"
    FAILED=1
fi

# Résultat final
if [ "$FAILED" -eq 0 ]; then
    echo "SMOKE TEST: PASSED"
    exit 0
else
    echo "SMOKE TEST: FAILED"
    exit 1
fi
