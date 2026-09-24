# BEDA ALU ERP

ERP menuiserie aluminium (Clients, Projets/Chantiers, Devis, Factures, Fiches d'exécution, Estimation financière).

## Stack
- Frontend : `index.html` (Tailwind CDN + Supabase JS + Chart.js), aucun build.
- Backend : Supabase (Postgres + Auth + RLS), projet `beda-alu-erp` (org vosgeycwzrixylyhmzlv).

## Déploiement
Fichier statique unique — déployable sur Vercel/Netlify/GitHub Pages sans configuration.

## Première connexion
Ouvrir `index.html`, cliquer sur « Première connexion ? Créer un compte administrateur », créer le compte, se connecter.

## Schéma
Tables : `profiles`, `clients`, `projets`, `produits`, `devis`, `devis_lignes`, `factures`, `fiches_execution`, `fiche_execution_lignes`. RLS activée (accès complet aux utilisateurs authentifiés).

## Composants : achat / vente
Chaque composant a un **prix d'achat** (`composants.prix_unitaire`, utilisé comme coût par le Configurateur) et un **prix de vente** (`composants.prix_vente`). Le bouton « 🔩 + Vendre un composant » de l'éditeur de devis ajoute une ligne liée (`devis_lignes.composant_id`) au prix de vente, avec la marge affichée. Migration : `sql/composants_prix_achat_vente.sql`.
