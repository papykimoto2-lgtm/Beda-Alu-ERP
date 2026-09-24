# Sanix AluExpert ERP

ERP de menuiserie aluminium — Clients, Projets/Chantiers, Devis, Factures (dont FNE), Fiches d'exécution, Configurateur, Stock multi-dépôts, Vente au comptoir, Caisse, Comptabilité SYSCOHADA.

Développé par **Sanix Africa Division Technologies**.

Le logiciel n'est lié à aucune entreprise : le nom, le logo, les coordonnées légales (RCCM, NCC), la TVA et les conditions imprimées sur les devis / factures de la structure utilisatrice se règlent dans **Paramètres → Entreprise**. Chaque structure a sa propre installation et sa propre base de données.

## Stack
- Frontend : `index.html` (Tailwind CDN + Supabase JS + Chart.js), aucun build.
- Backend : Supabase (Postgres + Auth + RLS + Edge Functions `connexion`, `gestion-utilisateurs`, `fne-proxy`).

## Installer pour une nouvelle structure
1. Créer un projet Supabase dédié à la structure (un projet par entreprise).
2. Dans Supabase → SQL Editor, exécuter **une seule fois** `sql/00_installation_complete.sql` : il crée toute la base (tables, fonctions, sécurité) et les référentiels de départ — journaux et plan comptable SYSCOHADA de base, exercice de l'année, catalogue technique du configurateur (prix indicatifs à ajuster), dépôt / caisse / point de vente principaux. Aucune donnée d'une autre entreprise n'y figure.
3. Copier `config.example.js` en `config.js` et y mettre l'URL et la clé publique (anon) du projet (Supabase → Project Settings → API).
4. Déployer les Edge Functions de `supabase/functions/` : `connexion` (sans vérification JWT : `supabase functions deploy connexion --no-verify-jwt`), `gestion-utilisateurs` et `fne-proxy` (certification FNE).
   Dans Supabase → Authentication → Sign In / Providers, **désactiver « Allow new users to sign up »** une fois le premier administrateur créé : les comptes sont ensuite créés uniquement par l'administrateur.
5. Publier le dossier (Vercel / Netlify / GitHub Pages), ouvrir l'application, « Première installation ? Créer le compte administrateur » (bouton visible seulement tant qu'aucun compte n'existe ; le premier compte devient administrateur), puis renseigner **Paramètres → Entreprise** : raison sociale, logo, RCCM / NCC, TVA, conditions des devis et factures.

Les autres scripts de `sql/` servent uniquement à mettre à jour une installation existante, étape par étape.

## Installation actuelle
Ce dépôt est déployé pour Beda Alu : `config.js` pointe vers le projet Supabase `beda-alu-erp` (org vosgeycwzrixylyhmzlv).

## Schéma
Tables : `profiles`, `clients`, `projets`, `produits`, `devis`, `devis_lignes`, `factures`, `fiches_execution`, `fiche_execution_lignes`. RLS activée (accès complet aux utilisateurs authentifiés).

## Composants : achat / vente
Chaque composant a un **prix d'achat** (`composants.prix_unitaire`, utilisé comme coût par le Configurateur) et un **prix de vente** (`composants.prix_vente`). Le bouton « 🔩 + Vendre un composant » de l'éditeur de devis ajoute une ligne liée (`devis_lignes.composant_id`) au prix de vente, avec la marge affichée. Migration : `sql/composants_prix_achat_vente.sql`.

## Vente au comptoir
Menu **Commercial → Vente au comptoir** : caisse enregistreuse pour la revente directe des composants.
- Catalogue cliquable (recherche + Entrée, filtre par famille), panier avec quantité / prix / remise par ligne, remise globale, marge estimée.
- Paiement espèces (caisse avec séance ouverte, montant reçu, monnaie à rendre), Mobile Money, carte/virement, chèque.
- Validation atomique via la RPC `vente_comptoir_valider` : vente + lignes + sorties de stock dans une seule transaction.
- Comptabilisation automatique : D trésorerie (compte de la caisse ou banque) / C ventes HT / C TVA collectée ; mouvement de caisse « ventilé » en espèces.
- Historique avec CA, marge, panier moyen et répartition par mode de paiement ; ticket 80 mm ; annulation (motif obligatoire, remise en stock, contre-passation, remboursement en caisse).
- Numérotation `VC-AAAA-00001`. Droits : module « Comptoir ». Migration : `sql/vente_comptoir.sql`.

## Multi-dépôts, points de vente et transferts
Menu **Stock → Dépôts & points de vente / Stock par dépôt / Transferts**.
- **Dépôts** (dépôt, magasin, atelier, chantier) : chacun a son propre stock (`stocks_depot`) ; `composants.stock_actuel` reste le total tous dépôts, le CMUP reste global. Un dépôt est « principal » : il reçoit les mouvements sans dépôt précisé.
- **Points de vente** : chacun est affilié à un dépôt (source du stock vendu au comptoir) et, en option, à une caisse. La caisse du comptoir choisit le point de vente (mémorisé sur le poste).
- **Transferts dépôt → dépôt** en deux temps : expédition (contrôle du disponible, sortie du dépôt de départ, statut « en transit ») puis réception (quantités reçues saisies, écarts tracés). Option « réception immédiate » pour deux dépôts sur le même site. Annulation d'un transfert en transit = retour au dépôt de départ. Bon de transfert imprimable avec signatures.
- Mouvements, inventaire et décharge des fiches d'exécution se font par dépôt.
- Droits : module « Stock ». Migration : `sql/depots_points_vente_transferts.sql` (crée le dépôt principal DEP-01 avec le stock existant et le point de vente PDV-01).

## Vente au comptoir — reçu, facture simple, facture normalisée FNE
Après chaque vente (ou plus tard depuis l'historique, bouton « Documents ») : **reçu de caisse** (ticket 80 mm), **facture simple** A4 au nom du client, ou **facture normalisée FNE** certifiée par la DGI.
- FNE : type de client B2C / B2B (NCC obligatoire) / B2G, téléphone obligatoire ; prix TTC convertis en HT selon le code TVA FNE (Paramètres → FNE) ; QR code de vérification DGI sur le ticket et la facture A4.
- Si la certification est désactivée ou non configurée : facture « PROVISOIRE — sans valeur fiscale », certifiable ensuite. Refus DGI : message conservé, nouvel essai possible.
- Annulation d'une vente certifiée : facture d'avoir FNE émise automatiquement.
- L'appel à l'API DGI passe par l'Edge Function Supabase `fne-proxy` (`supabase/functions/fne-proxy`), qui lit URL et clé dans `parametres` : le navigateur ne peut pas appeler l'API FNE directement. Migration : `sql/vente_comptoir_fne.sql`.

## Rapport périodique point de vente & caisse
Menu **Vente au comptoir → Rapport périodique** (ou bouton « Rapport » de l'historique). Période : aujourd'hui, hier, semaine, semaine dernière, mois, mois dernier ou dates libres ; un point de vente ou tous.
- Ventes : CA TTC / HT / TVA, marge, panier moyen, remises, annulations, CA par jour (graphique + tableau), encaissements par mode de paiement, par point de vente, par vendeur, articles les plus vendus, documents émis (reçus, factures simples, FNE certifiées / provisoires / refusées, avoirs).
- Caisse (de chaque point de vente) : séances (fond d'ouverture, entrées, sorties, solde théorique, compté, écart), écarts de clôture, autres entrées/sorties, et **rapprochement** ventes comptoir en espèces ↔ encaissements réellement passés en caisse (net des remboursements).
- Impression A4 avec zones de signature (caissier / responsable) et export CSV (détail des ventes + articles) pour Excel.

## Affectation des utilisateurs aux caisses et points de vente (code PIN)
Menu **Caisse → Affectations & codes PIN** (administrateurs et managers). Inspiré de la caisse Menko Immo.
- Tableau utilisateurs × caisses × points de vente : cocher qui peut utiliser quoi ; ⭐ = point de vente proposé par défaut. Une caisse ou un point de vente **sans personne cochée reste accessible à tous** ; admin et manager ont toujours accès à tout.
- Rôles : administrateur, manager, comptable, caissier(ère), commercial, technicien, utilisateur. Les nouveaux comptes sont créés « utilisateur » (le tout premier compte reste administrateur) ; seul un administrateur change un rôle.
- **Code PIN de caisse** personnel (4 chiffres), exigé à l'ouverture de séance ; stocké chiffré (bcrypt) côté serveur, jamais réaffiché ; 5 erreurs → blocage 10 minutes. Chacun peut changer son PIN (Caisse → « Mon code PIN »).
- Contrôles appliqués **dans la base** : ouverture de séance via `caisse_ouvrir_session` (affectation + PIN), mouvements de caisse et ventes au comptoir refusés hors affectation. Le fond d'ouverture reprend le solde compté à la dernière clôture ; la séance mémorise qui l'ouvre et la clôture.
- Migration : `sql/affectations_caisse_pdv.sql`.

## Utilisateurs, rôles et connexion (modèle Menko Immo)
- **Comptes créés par l'administrateur** (Paramètres → Utilisateurs) : identifiant (ex. `a.kone`), nom, e-mail facultatif, téléphone, rôle et **mot de passe provisoire** affiché une seule fois. Plus d'inscription libre.
- **Connexion par identifiant ou e-mail** via l'Edge Function `connexion` : blocage après 5 échecs sur 24 h, message du nombre de tentatives restantes, journal de chaque tentative (IP, navigateur).
- **Mot de passe** : 8 caractères minimum dont 1 majuscule, 1 chiffre, 1 caractère spécial ; changement **obligatoire** à la première connexion et après réinitialisation. Chacun peut changer le sien en cliquant sur son avatar.
- **Désactivation / réactivation** d'un compte, réinitialisation du mot de passe (débloque aussi le compte). Le dernier administrateur actif ne peut être ni rétrogradé ni désactivé.
- **Rôles & accès** : rôles (administrateur, manager, comptable, commercial, caissière, commissaire, personnalisés) avec droits voir / créer / modifier / supprimer / valider par module. Un compte « sans rôle » voit une page d'attente.
- **Sécurité & connexions** : déconnexion automatique après inactivité (30 min par défaut), bouton « Déconnecter tous les autres postes », postes connectés récemment, journal des connexions.
- Appliqué **dans la base** (RLS restrictive) : un compte désactivé, sans rôle ou devant changer son mot de passe n'accède à aucune donnée, même en appelant l'API directement.
- Migrations (installation existante) : `sql/utilisateurs_roles.sql` puis `sql/utilisateurs_auth_menko.sql`. Les comptes existants reçoivent un identifiant tiré de leur e-mail.
