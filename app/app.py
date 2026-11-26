"""
Task Manager - petite application Flask pour le projet DevOps.

Les tâches sont stockées en mémoire (une simple liste Python) :
elles disparaissent quand l'application redémarre. C'est voulu,
pour garder le projet simple (pas de base de données).
"""
import os

from flask import Flask, redirect, render_template, request, url_for

app = Flask(__name__)

# Version de l'application : fournie par Docker/Jenkins (variable d'environnement)
APP_VERSION = os.environ.get("APP_VERSION", "dev")

# Stockage en mémoire : liste de dictionnaires {"id", "title", "done"}
tasks = []
next_id = 1


@app.route("/")
def index():
    """Affiche la liste des tâches."""
    return render_template("index.html", tasks=tasks, version=APP_VERSION)


@app.route("/add", methods=["POST"])
def add_task():
    """Ajoute une tâche (si le titre n'est pas vide)."""
    global next_id
    title = request.form.get("title", "").strip()
    if title:
        tasks.append({"id": next_id, "title": title, "done": False})
        next_id += 1
    return redirect(url_for("index"))


@app.route("/done/<int:task_id>", methods=["POST"])
def mark_done(task_id):
    """Marque une tâche comme terminée (ou la ré-ouvre si on reclique)."""
    for task in tasks:
        if task["id"] == task_id:
            task["done"] = not task["done"]
    return redirect(url_for("index"))


@app.route("/delete/<int:task_id>", methods=["POST"])
def delete_task(task_id):
    """Supprime une tâche."""
    global tasks
    tasks = [t for t in tasks if t["id"] != task_id]
    return redirect(url_for("index"))


@app.route("/health")
def health():
    """Point de contrôle utilisé par le smoke test."""
    return {"status": "ok", "version": APP_VERSION}


if __name__ == "__main__":
    # Lancement local : python app/app.py  -> http://localhost:5000
    app.run(host="0.0.0.0", port=5000, debug=True)
