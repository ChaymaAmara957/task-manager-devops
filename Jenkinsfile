// =====================================================================
//  Jenkinsfile - Task Manager DevOps
//  UN seul fichier pour les 3 pipelines Jenkins :
//    1) TaskManager-1-PR      : Build & Smoke sur Pull Request (vers dev)
//    2) TaskManager-2-Dev     : Build complet sur push dans dev
//    3) TaskManager-3-Release : Build versionné sur tag vX.Y.Z
//  Le type de pipeline est détecté automatiquement à partir de la
//  référence Git récupérée (origin/pr/N, origin/dev, origin/tags/vX.Y.Z).
//  Agent : Jenkins sous Windows (commandes "bat") + Docker Desktop.
// =====================================================================

// Variables partagées (statut de chaque stage + versions de Python)
STAGE_STATUS = [:]
PY_VERSIONS  = ['3.12']

// Mémorise le statut du stage courant (affiché dans le rapport final)
def mark(String status) {
    STAGE_STATUS[env.STAGE_NAME] = status
}

// Lance une commande, enregistre sa sortie dans un fichier log,
// l'affiche dans la console Jenkins et renvoie le bon code de sortie.
def runLogged(String command, String logFile) {
    bat """
${command} > "${logFile}" 2>&1
set RC=%ERRORLEVEL%
type "${logFile}"
exit /b %RC%
"""
}

// Exécute "body" pour chaque version de Python.
// Avec 2 versions (pipeline versionné), les exécutions sont PARALLÈLES.
def forEachPython(Closure body) {
    def branches = [:]
    for (v in PY_VERSIONS) {
        def pv = v
        branches["Python ${pv}"] = { body(pv) }
    }
    parallel branches
}

def imageTag(String py)      { return "task-manager:${env.APP_VERSION}-py${py}" }
def containerName(String py) { return "tm-${env.BUILD_TAG}-py${py.replace('.', '')}" }

// Supprime conteneurs et réseau de ce build (ne plante jamais)
def dockerCleanup() {
    for (v in PY_VERSIONS) {
        // On garde les logs du conteneur avant de le supprimer
        bat "if exist reports docker logs ${containerName(v)} > reports\\container-py${v}.log 2>&1 || exit /b 0"
        bat "docker rm -f ${containerName(v)} 2>nul || exit /b 0"
    }
    bat "docker network rm ${env.NET_NAME} 2>nul || exit /b 0"
    if (env.PIPELINE_TYPE == 'PR') {
        // Les images de PR sont temporaires : on les supprime
        for (v in PY_VERSIONS) {
            bat "docker rmi ${imageTag(v)} 2>nul || exit /b 0"
        }
    }
}

// Écrit le rapport du pipeline (archivé comme artefact)
def writeReport() {
    def order = ['Checkout', 'Setup', 'Build', 'Run Docker', 'Smoke Test', 'Archive Artifacts', 'Cleanup']
    def lines = []
    lines << '================ RAPPORT DE PIPELINE ================'
    lines << "Pipeline       : ${env.PIPELINE_TYPE ?: '?'}  (${env.JOB_NAME} #${env.BUILD_NUMBER})"
    lines << "Référence Git  : ${env.GIT_REF ?: '?'}"
    lines << "Commit         : ${env.GIT_COMMIT_SHORT ?: '?'}"
    lines << "Version        : ${env.APP_VERSION ?: '?'}"
    lines << "Python         : ${PY_VERSIONS.join(', ')}"
    lines << "Date           : ${new Date().toString()}"
    lines << '-----------------------------------------------------'
    for (s in order) {
        lines << "${s.padRight(20)} : ${STAGE_STATUS[s] ?: 'SKIPPED'}"
    }
    lines << '-----------------------------------------------------'
    lines << "RÉSULTAT GLOBAL : ${currentBuild.currentResult == 'SUCCESS' ? 'PASSED' : 'FAILED'}"
    lines << '====================================================='
    def text = lines.join('\r\n')
    writeFile file: 'reports/pipeline_report.txt', text: text, encoding: 'UTF-8'
    echo text
}

pipeline {
    agent any

    options {
        timestamps()
        timeout(time: 20, unit: 'MINUTES')
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
        skipDefaultCheckout(true)
    }

    stages {

        stage('Checkout') {
            steps {
                script {
                    def scmVars = checkout scm
                    env.GIT_REF = scmVars.GIT_BRANCH ?: ''
                    env.GIT_COMMIT_SHORT = (scmVars.GIT_COMMIT ?: 'unknown000').substring(0, 7)
                    echo "Référence récupérée : ${env.GIT_REF} (commit ${env.GIT_COMMIT_SHORT})"
                }
            }
            post { success { script { mark('PASSED') } }
                   failure { script { mark('FAILED') } } }
        }

        stage('Setup') {
            steps {
                script {
                    // 1) Détection du type de pipeline et de la version
                    def ref = env.GIT_REF
                    if (ref.contains('tags/')) {
                        env.PIPELINE_TYPE = 'RELEASE'
                        def tag = ref.substring(ref.lastIndexOf('/') + 1)
                        if (!tag.matches(/v\d+\.\d+\.\d+/)) {
                            error "Tag '${tag}' invalide : format attendu vX.Y.Z (ex : v1.0.0)"
                        }
                        env.APP_VERSION = tag.substring(1)        // v1.0.0 -> 1.0.0
                        PY_VERSIONS = ['3.11', '3.12']             // parallélisation
                    } else if (ref.contains('pr/')) {
                        env.PIPELINE_TYPE = 'PR'
                        env.APP_VERSION = "pr-${ref.substring(ref.lastIndexOf('/') + 1)}-b${env.BUILD_NUMBER}"
                    } else {
                        env.PIPELINE_TYPE = 'DEV'
                        env.APP_VERSION = "dev-b${env.BUILD_NUMBER}"
                    }
                    env.NET_NAME = "tm-net-${env.BUILD_TAG}"
                    currentBuild.displayName = "#${env.BUILD_NUMBER} ${env.PIPELINE_TYPE} ${env.APP_VERSION}"

                    echo "Type de pipeline : ${env.PIPELINE_TYPE}"
                    echo "Version          : ${env.APP_VERSION}"
                    echo "Python           : ${PY_VERSIONS.join(', ')}"
                }
                // 2) Préparation : dossier des rapports, fichier version, vérif Docker
                bat 'if exist reports rmdir /s /q reports'
                bat 'mkdir reports'
                writeFile file: 'reports/version.txt', text:
                    "version=${env.APP_VERSION}\r\npipeline=${env.PIPELINE_TYPE}\r\ngit_ref=${env.GIT_REF}\r\ncommit=${env.GIT_COMMIT_SHORT}\r\nbuild=${env.BUILD_NUMBER}\r\npython=${PY_VERSIONS.join(',')}\r\n"
                bat 'docker version --format "Docker Engine {{.Server.Version}}"'
                bat "docker network create ${env.NET_NAME}"
            }
            post { success { script { mark('PASSED') } }
                   failure { script { mark('FAILED') } } }
        }

        stage('Build') {
            steps {
                script {
                    forEachPython { py ->
                        echo "Construction de l'image ${imageTag(py)}"
                        runLogged("docker build --build-arg PYTHON_VERSION=${py} --build-arg APP_VERSION=${env.APP_VERSION} -t ${imageTag(py)} .",
                                  "reports\\build-py${py}.log")
                    }
                }
            }
            post { success { script { mark('PASSED') } }
                   failure { script { mark('FAILED') } } }
        }

        stage('Run Docker') {
            steps {
                script {
                    forEachPython { py ->
                        def name = containerName(py)
                        bat "docker run -d --name ${name} --network ${env.NET_NAME} ${imageTag(py)}"
                        bat "docker inspect -f \"Container ${name} running={{.State.Running}}\" ${name}"
                    }
                }
            }
            post { success { script { mark('PASSED') } }
                   failure { script { mark('FAILED') } } }
        }

        stage('Smoke Test') {
            steps {
                script {
                    forEachPython { py ->
                        def name = containerName(py)
                        // Le script tests/smoke_test.sh est exécuté dans un petit conteneur
                        // "curl" branché sur le même réseau Docker que l'application.
                        runLogged("type tests\\smoke_test.sh | docker run --rm -i --network ${env.NET_NAME} --entrypoint sh curlimages/curl -c \"tr -d '\\r' | sh -s http://${name}:5000\"",
                                  "reports\\smoke-py${py}.txt")
                    }
                }
            }
            post { success { script { mark('PASSED') } }
                   failure { script { mark('FAILED') } } }
        }

        stage('Archive Artifacts') {
            steps {
                archiveArtifacts artifacts: 'reports/**', fingerprint: true
            }
            post { success { script { mark('PASSED') } }
                   failure { script { mark('FAILED') } } }
        }

        stage('Cleanup') {
            steps {
                script { dockerCleanup() }
            }
            post { success { script { mark('PASSED') } }
                   failure { script { mark('FAILED') } } }
        }
    }

    post {
        always {
            script {
                // En cas d'échec, le stage Cleanup n'a pas tourné : on nettoie ici
                if (currentBuild.currentResult != 'SUCCESS') { dockerCleanup() }
                writeReport()
            }
            archiveArtifacts artifacts: 'reports/**', allowEmptyArchive: true
        }
        success { echo 'PIPELINE : PASSED' }
        failure { echo 'PIPELINE : FAILED - consulter les artefacts (logs de build, smoke test, rapport)' }
    }
}
