# Bilan d’avancé du du projet 30/03/2026:

Partie FPGA: 

Etat du GIT avant la séance d’aujourd’hui : Communication entre le pc et le FPGA fonctionnelle, traitement simple avec un \+1 sur le payload

Git à jour à la fin de cette séance : Traitement enigma à la place du \+1, le traitement s’effectue sur le payload 

A améliorer pour la prochaine séance : reset la machine enigma à chaques trames 

Simulation vivado :  

payload d’entré : 41 41 41 41 41 41 41 41   
payload de sortie : 42 44 5a 47 4f 57 43 58 

le traitement enigma fonctionne mais il reste à faire un reset de la machine à chaques trames car chaques nouveau envoie de trame garde la config enigma decaler par les appels précédents

How to use : 

Ajouter au projet les fichier dans le dossier VERILOG du git ( ajouter les dernier ajout si besoin )  
Pour simuler : 

1) mettre tb\_eternet\_echo en top pour lancer une simulation  
2) run la simulation pendant 10000 ns   
3) Lire les resultats de la simulation dans la console   
   

Pour implémenter sur carte : 

1) mettre top\_echo en top   
2) generer le bitstream  
3) connecter avec le cable ethernet au pc la carte et suivre les instructions coté pc 

## Côté PC (interface Qt) :

le projet se décompose en 5 fichiers : 

- main.cpp  
- mainwindow.cpp  
- mainwindow.h  
- [mainwindow.ui](http://mainwindow.ui)  
- CMakeLists.txt

Il se compile dans l’application Qt creator.  
En raison de la manipulation des trames ethernet, l'exécution nécessite l’usage de sudo. L'exécutable se trouve au chemin suivant :  
/ETH/Interface\_enigma\_3/build/Desktop-Debug

Pour ouvrir l’interface graphique il faut exécuter la commande suivante :  
sudo ./Interface\_enigma\_3

Fonctionnalités disponibles sur l’interface :

- envoie d’un texte à partir du champs de texte ou du contenu d’un fichier  
- réception de trames

Pour les deux fonctionnalités, des champs pour les adresses MAC sources et destination sont disponibles afin de personnaliser respectivement l’envoie et la réception.

note : les boutons chiffrages/déchiffrages ont été désactivés pour pouvoir faire des tests en l’état actuel du projet

Objectif pour la prochaine séance : peaufiner l’interface graphique et la sauvegarde des trames reçus.

