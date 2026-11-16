# Clés SSH autorisées sur les machines PalinGoneOS

Chaque fichier `.pub` de ce dossier est une **clé publique** autorisée à se connecter
en SSH (réseau local uniquement) au compte principal de chaque machine PalinGoneOS.

- Une clé publique peut être montrée sans danger : c'est la clé **privée**
  (`~/.ssh/id_ed25519`, jamais copiée ici) qui ouvre la porte.
- Un fichier par ordinateur d'où l'on se connecte, par exemple `dylan-thinkpad.pub`.
- Pour retirer un accès : supprimer son fichier, puis publier une nouvelle version.

Ces clés-ci sont celles de l'administrateur. Chaque utilisateur peut en plus choisir,
pour SON ordinateur seulement, qui peut s'y connecter : commande `pgos-ssh`
(`man pgos-ssh`).
