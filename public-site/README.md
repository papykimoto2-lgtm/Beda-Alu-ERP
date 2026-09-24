# Portail client BEDA ALU — site public

Ce dossier contient l'export statique du portail client généré depuis l'ERP
(Paramètres → 🌐 Portail client → « Générer le site + portail »).

**Ce n'est pas du code applicatif** : `index.html` est un instantané des données
au moment de la génération (réalisations publiées, produits photographiés,
mot du DG, coordonnées…). Il doit être **régénéré et redéposé ici** à chaque
mise à jour de ces contenus — il ne se met pas à jour tout seul.

Déployé séparément de l'ERP (projet Vercel dédié, racine = `public-site/`)
pour ne pas hériter de la protection SSO de l'outil interne.
