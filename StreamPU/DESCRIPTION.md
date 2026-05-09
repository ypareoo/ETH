# Raw Ethernet Frame Pipeline

Ce projet implémente une chaîne de traitement permettant de générer, envoyer, recevoir et enregistrer des trames Ethernet brutes.  
Il s'appuie sur la bibliothèque **StreamPU** afin d'organiser les différentes étapes sous forme de tâches connectées entre elles.

Le programme fonctionne comme un pipeline composé de plusieurs modules :

1. Génération d'un payload
2. Encapsulation et envoi dans une trame Ethernet
3. Réception et analyse des trames sur le réseau
4. Écriture du payload reçu dans un fichier

---

# Architecture du projet

Le programme est constitué de quatre modules principaux :

## FrameGenerator

**Entrée :** aucune  
**Sorties :**
- `payload`
- `length`

Cette tâche lit le contenu du fichier `payload.txt` et le prépare pour l'envoi.

Le contenu du fichier est converti en payload binaire qui sera transmis à la tâche suivante.  
Le fichier utilisé est un `.txt`, mais ce n'est pas une contrainte technique.

---

## RawSender

**Entrées :**
- `payload`
- `length`

**Sortie :**
- `send_status` (déclencheur)

Cette tâche encapsule le payload dans une **trame Ethernet brute** en ajoutant :

- adresse MAC source
- adresse MAC destination
- Ethertype

La trame est ensuite envoyée sur l'interface réseau spécifiée.

Lorsque l'envoi est terminé, la tâche active un **signal déclencheur** pour la tâche suivante.

---

## RawReceiver

**Entrée :**
- `trigger`

**Sorties :**
- `payload`
- `length`

Une fois déclenchée, cette tâche agit comme un **analyseur réseau** :

- capture toutes les trames reçues sur l'interface
- affiche les trames détectées
- recherche une trame cible définie par une **adresse MAC spécifique**

Dès que la trame cible est détectée, son payload est extrait et transmis à la tâche suivante.

Un **timeout de 20 secondes** est appliqué pour arrêter le programme si aucune trame cible n'est reçue.

---

## PayloadWriter

**Entrées :**
- `payload`
- `length`

Cette tâche écrit le payload reçu dans le fichier :
`reception.txt`
Elle constitue la dernière étape du pipeline.

---