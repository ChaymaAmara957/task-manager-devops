# Task Manager – Projet DevOps (3 LIG)

Petite application web **Flask** de gestion de tâches, utilisée comme support pour une chaîne **CI/CD** complète :
Git/GitHub → Jenkins (3 pipelines) → Docker → Smoke Test → Artefacts.

## Fonctionnalités
- Ajouter une tâche
- Afficher la liste des tâches
- Marquer une tâche comme terminée
- Supprimer une tâche
- Message lorsque la liste est vide

Les tâches sont stockées **en mémoire** (pas de base de données).

## Structure
```text
task-manager-devops/
├── app/
│   ├── app.py               # application Flask
│   ├── templates/index.html # interface
│   └── static/style.css     # style
├── tests/smoke_test.sh      # smoke test -> SMOKE TEST: PASSED / FAILED
├── Dockerfile               # multi-stage, Python paramétrable (ARG)
├── .dockerignore            # build Docker plus rapide
├── .gitattributes           # garde le script .sh en fins de ligne LF
├── requirements.txt
├── Jenkinsfile              # les 3 pipelines
└── README.md
```

## Lancer l'application

### En local (Python)
```bash
pip install -r requirements.txt
python app/app.py
# -> http://localhost:5000
```

### Avec Docker
```bash
docker build -t task-manager .
docker run -d -p 5000:5000 --name task-manager task-manager
# -> http://localhost:5000
sh tests/smoke_test.sh http://localhost:5000
docker rm -f task-manager
```

Build avec une autre version de Python :
```bash
docker build --build-arg PYTHON_VERSION=3.11 -t task-manager:py3.11 .
```

## Workflow Git
| Branche | Rôle |
|---|---|
| `main` | branche principale **protégée** (pas de push direct) |
| `dev` | branche d'intégration |
| `feature/*` | une branche par fonctionnalité |

1. `git checkout dev && git checkout -b feature/ma-fonctionnalite`
2. commit + `git push -u origin feature/ma-fonctionnalite`
3. Pull Request `feature/...` → `dev` → **Pipeline 1 (PR)**
4. Merge de la PR → push sur `dev` → **Pipeline 2 (Dev)**
5. `git tag v1.0.0 && git push origin v1.0.0` → **Pipeline 3 (Release)**

## Pipelines Jenkins
Un seul `Jenkinsfile`, utilisé par trois jobs Jenkins :

| Job | Déclencheur | Python |
|---|---|---|
| `TaskManager-1-PR` | ouverture / mise à jour d'une PR (`refs/pull/*/head`) | 3.12 |
| `TaskManager-2-Dev` | push sur `dev` | 3.12 |
| `TaskManager-3-Release` | tag `vX.Y.Z` | 3.11 **et** 3.12 en parallèle |

Stages : **Checkout → Setup → Build → Run Docker → Smoke Test → Archive Artifacts → Cleanup**

Artefacts archivés (dossier `reports/`) :
- `build-py<version>.log` : logs du `docker build`
- `smoke-py<version>.txt` : résultat du smoke test
- `container-py<version>.log` : logs de l'application
- `pipeline_report.txt` : statut de chaque stage + résultat global
- `version.txt` : version, branche/tag, commit
