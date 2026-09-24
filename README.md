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

## Mode hors ligne (offline-first)
L'application continue de fonctionner quand internet est coupé :
- **Ouverture sans connexion** : l'application est gardée sur l'appareil (service worker `sw.js`, installable comme une application — `manifest.webmanifest`). Une session ouverte reste active hors ligne.
- **Consultation** : chaque écran déjà ouvert sur l'appareil reste consultable (dernières données reçues, gardées dans le navigateur).
- **Saisies hors ligne** (clients, prospects, devis, modifications, suppressions…) et **ventes au comptoir** : enregistrées sur l'appareil dans une file d'attente, visibles aussitôt dans les listes, puis envoyées automatiquement dans l'ordre au retour du réseau. Une vente hors ligne reçoit un code provisoire `VCH-AAAA-XXXXXXX` (conservé ensuite) ; son écriture comptable et son mouvement de caisse sont créés à la synchronisation.
- **Indicateur** dans l'en-tête : En ligne / Hors ligne · N en attente / erreurs. Un clic affiche la file d'attente et les opérations refusées par le serveur (réessayer ou abandonner).
- **Sécurité** : hors ligne, l'inactivité **verrouille** la session (déverrouillage par le mot de passe, vérifié sur une empreinte PBKDF2 gardée sur l'appareil) au lieu de déconnecter. Les données gardées sont effacées à la déconnexion ; les saisies non envoyées sont conservées.
- **Nécessitent une connexion** : se connecter, codes PIN et ouverture de caisse, transferts de stock, gestion des comptes, certification FNE.
- Migration : `sql/hors_ligne.sql` (la vente au comptoir accepte l'identifiant et le code générés sur l'appareil).

## Chantiers : caisse et stock rattachés au chantier d'un client
- **Caisse** : chaque bon d'entrée / de sortie peut être rattaché à un chantier — choisir le **client**, puis **un de ses chantiers** (présélectionné s'il n'en a qu'un en cours ; une caisse de chantier propose son chantier par défaut). Modifiable ensuite (✏️). La ventilation comptable du bon crée une écriture rattachée au même chantier.
- **Stock** : un mouvement (sortie de matériaux, retour, achat livré sur chantier…) se rattache de la même façon ; colonne et filtre « Chantier » dans Stock → Mouvements. Les sorties faites depuis une fiche d'exécution sont rattachées automatiquement au chantier de la fiche.
- **Fiche du projet** : section « Suivi du chantier » — dépenses et encaissements de caisse, matériaux sortis (valorisés au CMUP), coût direct suivi, et bouton « Sortie de stock pour ce chantier ».
- Migration : `sql/chantiers_caisse_stock.sql` (colonnes `projet_id`, reprise des caisses de chantier et des sorties de fiches d'exécution existantes).

## Tableau de bord — Cockpit (structure Menko Immo)
L'accueil reprend la structure du tableau de bord de Menko Immo, adaptée à la menuiserie aluminium. Onglets (affichés selon les droits du rôle) : **🎛️ Cockpit** (écran d'accueil) · 📊 Vue générale · 💰 Finance & Trésorerie · 🎯 Commercial · 🏗️ Chantiers · 📦 Stock · 🛒 Comptoir · ⚠️ Alertes.
- **Cockpit, le tableau de bord qui travaille** : il ne décrit pas seulement l'activité, il prescrit le geste suivant.
  - *Briefing* du jour en langage naturel et première action recommandée ;
  - *cartes d'encours* : reste à encaisser, échu > 30 jours, devis acceptés à facturer, pipeline, comptoir du jour ;
  - *file d'actions priorisée* : relancer une facture impayée (📞 appel, 💬 WhatsApp pré-rédigé, ✓ relance faite), clôturer une caisse restée ouverte, facturer un devis accepté, certifier une facture FNE, chantier en retard, réapprovisionner, ventiler la caisse, relancer un devis sans réponse, réceptionner un transfert, contacter un prospect, saisies hors ligne refusées. Chaque action se reporte (🌙 demain) ou s'ignore (✕) — choix propre au poste ;
  - *Pouls de l'activité* : courbe des encaissements 30 jours (factures + comptoir), 7 derniers jours, tendance, espèces en caisse ;
  - *Santé par domaine* (0-100) : recouvrement, caisse, commercial, chantiers, stock, données — avec la cause dominante ;
  - *💬 Partager* la file d'actions (WhatsApp) et *📊 Bulletin* de pilotage imprimable.
- Les autres onglets détaillent : encaissements mensuels et ancienneté des impayés, devis par statut et performance par commercial, chantiers par étape et en retard, stock sous le seuil et valeur immobilisée, ventes et marge du comptoir, alertes par domaine.

## Circuit de validation DG de la caisse (modèle Menko Immo)
- Un **bon d'entrée / de sortie** ou un **transfert entre caisses** est d'abord une **demande** (n° `DV-AAAA-00001`) : il **n'entre dans le solde qu'une fois approuvé**.
- **Qui valide** : le DG (administrateur, plafond illimité — y compris ses propres bons) ou un délégué ayant le droit « valider » du module Caisse **et** un plafond de rôle couvrant le montant (Paramètres → Rôles & accès → Plafond de validation). Au-delà : « 🔒 Plafond insuffisant ».
- **Rejet motivé**, visible par l'auteur ; l'auteur suit ses demandes, confirme la **remise physique des fonds** (💰 Décaisser) et **imprime le bon** (uniquement après validation : visa DG, signatures).
- **Caisse → Validations (DG)** : file des demandes en attente (badge dans le menu), mes demandes, historique des décisions, lien vers les écritures à viser. Le **Cockpit** place « Valider N demande(s) de caisse » en tête de la file d'actions du DG ; l'auteur y voit ses demandes rejetées et les fonds à remettre. Bouton « 📲 Prévenir le DG (WhatsApp) » à la création.
- **Mode** (sur la page Validations, pour les administrateurs) : *Tous les bons (règle DG, par défaut)*, *Au-delà du plafond de l'auteur*, *Circuit désactivé*.
- Contrôlé **dans la base** : un bon manuel ou un transfert ne peut pas être inséré directement ; seule la fonction de validation crée le mouvement (numéro BE/BS attribué à la validation). Le montant d'un bon validé n'est modifiable que par un validateur dont le plafond le couvre. Les ventes au comptoir, remboursements et encaissements de factures restent immédiats. Clôture de séance : avertissement s'il reste des demandes en attente.
- Migration : `sql/validation_dg.sql` (aussi dans `00_installation_complete.sql`).

## Configurateur d'ouvrage — catalogue étendu (aluminium & inox)
- **85 ouvrages** (8 historiques + 77 nouveaux) en **10 familles** : fenêtres (française 1/2/3 vantaux, oscillo-battant, soufflet, projetant à l'italienne, basculant, pivotant, fixe, composé, imposte, guillotine) ; coulissants (baies 2/3/4/6 vantaux, 2-3 rails, 1 vantail + fixe, levant-coulissant, porte pliante accordéon) ; portes (entrée, tiercée, 2 vantaux, porte-fenêtre, va-et-vient, pivot désaxée, service tôlée, ensemble d'entrée) ; façades (mur-rideau VEP / VEC, vitrine, cloison de bureau, verrière d'atelier, châssis filant) ; fermetures (volet roulant, garage enroulable, rideau métallique, grille maillée, moustiquaire, sectionnelle, volet persienné, persienne, BSO, brise-soleil, claustra) ; pergolas bioclimatiques, toiture fixe, carport, auvents ; garde-corps alu / inox (barreaux, lisses, câbles, verre sur sabot ou à pinces, tôle perforée), rampe d'escalier, main courante murale, clôture de piscine ; portails battants / coulissants, portillon, clôture, grille de défense ; douche (walk-in, pivotante, coulissante, angle) ; bardage composite ACM.
- **📚 Catalogue** avec vignettes, recherche et filtres par famille ; menu « Type d'ouvrage » groupé par famille. Chaque ouvrage a ses **paramètres propres** (sens, imposte, allège, remplissage, soubassement, serrure, trame, lames, manœuvre, pente, fixation, avancée, modules…).
- Un **moteur par nature d'ouvrage** (châssis, enroulable, sectionnelle, lames, pergola, portail, garde-corps, douche, habillage) calcule la nomenclature (débit des barres, remplissage, quincaillerie par ouverture) et une géométrie unique réutilisée par la **vue de face à l'échelle** (symboles d'ouverture normalisés : triangle pointe côté ferrage / axe, flèches de coulissement), le **plan de fabrication** (coupe adaptée : dormant/ouvrant, coffre et diamètre d'enroulement, lames, vue en plan de pergola, cadre de portail, poteau + fixation, cassette ACM), la **3D** et les vignettes.
- **Contrôles techniques** affichés : garde-corps NF P01-012 (H ≥ 1,00 m, 0,90 m en rampant, vide ≤ 110 mm, lisses ≤ 110 / 180 mm, zone de 600 mm), piscine NF P90-306 (≥ 1,10 m), verre de sécurité sur les portes, largeurs de vantail, poids des coulissants, enroulement dans le coffre, portées de pergola, taux d'utilisation des plaques ACM, inox 316 en bord de mer.
- Composants (≈ 124 codes, prix indicatifs FCFA modifiables) : `sql/catalogue_ouvrages.sql` (aussi dans `00_installation_complete.sql`).

## Brouillard de caisse, ventilation des mouvements et ticket Z : trois états distincts
- **📖 Brouillard de caisse** (Caisse → Brouillard de caisse) : journal chronologique d'une caisse, séance par séance — report du fond d'ouverture, chaque pièce (heure, n°, libellé, chantier, entrée, sortie, **solde progressif**), totaux, solde théorique, espèces comptées et **écart**. Contrôle du report (fond d'ouverture ≠ comptage de la veille). Ventes au comptoir regroupées (option) ; colonne « Compta » indiquant seulement si la pièce est ventilée. Impression A4 (caissier, contrôleur, visa DG) et CSV.
- **📒 Ventilation des mouvements** (Comptabilité → Contrôle → Ventilation caisse, ancien « Brouillards caisse ») : imputation de chaque mouvement de caisse sur un compte de contrepartie et génération de l'écriture (règles, ventilation automatique).
- **🧾 Ticket Z** (Vente au comptoir → Ticket Z) : clôture **numérotée et définitive** d'un point de vente (`Z-PDV-00001` journalier, `ZP-…` périodique) : ventes, remises, HT/TVA, annulations, règlements par mode, documents émis, caisse espèces (fond, ventes, autres flux, théorique, compté, écart), articles, vendeurs, **grand total perpétuel**. Format ticket 80 mm. **Lecture X** = mêmes totaux sans numéro ni clôture. Réédition = **DUPLICATA** compté ; alerte si des ventes ont changé après l'émission. Numérotation et totaux de contrôle calculés par le serveur (`ticket_z_emettre`), pas d'écriture directe dans `tickets_z`.
- **📊 État périodique** (ancien « Rapport périodique ») : analyse détaillée d'une période (CA, marge, jours, articles, vendeurs, caisses).
- Migration : `sql/tickets_z.sql` (aussi dans `00_installation_complete.sql`).

## Comptabilité SYSCOHADA révisé — plan arborescent et comptabilisation automatique
- **Plan comptable SYSCOHADA révisé (2017)** : environ 510 comptes de référence, classes 1 à 8 ; comptes principaux (2 chiffres), divisionnaires (3) et sous-comptes utiles (4011, 4111, 4431, 4452, 6032, 6042…). **Arborescence par préfixe**, sur le modèle de Menko Immo : 401 → 4011 → 40110001. Un compte qui a des sous-comptes est un **regroupement** : il totalise ses sous-comptes et n'est plus imputable, ce qui est contrôlé en base (`trg_compta_lignes_imputable`).
- **Écran Plan comptable** :
  - classes dépliables ;
  - badges « regroupement », « propre à l'entité » et « mouvementé » ;
  - soldes cumulés par sous-arbre ;
  - recherche qui affiche aussi les comptes parents ;
  - bouton **＋ sous-compte** qui propose le code libre suivant ; le nouveau compte hérite de la classe et de la nature de son parent ;
  - **audit** : comptes par défaut, caisses ou écritures pointant sur un regroupement ;
  - import CSV (export Sage accepté : colonnes *Numéro* / *Intitulé*).
- **Reprise du plan d'origine** : chaque ancien code à 6 chiffres est fusionné dans son compte révisé, par exemple 571000 → 571, 512000 → 521 (banques), 701000 → 701, 443000 → 4431, 401000 → 4011, 411000 → 4111 ; 421000 et 422000 sont remis dans le bon sens ; 110000/120000/129000 → 121/131/139. Les écritures, caisses, ventilations, règles et comptes par défaut suivent. Les comptes propres à l'entité sont conservés.
- **Comptabilisation automatique** (Comptabilité → ⚡ Automatismes, pour rattraper les pièces sans écriture) :

  | Opération | Écriture générée |
  |---|---|
  | Facture émise | D 4111 / C 702 + C 4431 |
  | Facture annulée | Contre-passation automatique |
  | Encaissement | Trésorerie selon le mode (571 caisse, 521 banque, 552 Mobile Money, chèques) / C 4111 |
  | Vente au comptoir | Trésorerie / 701 + 4431 |
  | Achat de stock | 602 ou 6041 selon la famille / 4011 |
  | Bon de caisse avec compte d'imputation (choisi ou déduit des règles), y compris après validation du DG | Écriture générée à l'enregistrement |
  | Transfert entre caisses | 585 des deux côtés |
  | Écart de clôture de caisse | 658 / 758 |
  | Variation des stocks (inventaire) | 3x / 6032-6033, stock valorisé au CMUP |
  | Clôture de l'exercice | Classes 6, 7, 8 → 131 / 139, puis à-nouveaux des classes 1 à 5 |

  Une réservation empêche la double comptabilisation d'un même mouvement.
- **États** :
  - balance hiérarchique (classe, compte principal, divisionnaire, détail) ;
  - grand livre d'un compte ou d'un regroupement, avec ses sous-comptes ;
  - **Bilan** (AD… BZ / CA… DZ) et **Compte de résultat** (TA… XI : marge commerciale, valeur ajoutée, EBE, résultats d'exploitation, financier, HAO et net) au format SYSCOHADA système normal, imprimables. Les tiers et la trésorerie sont classés selon le sens de leur solde.
- **Comptes par défaut** (Paramètres → Comptabilité) regroupés par thème, avec les codes révisés : caisse, banque, Mobile Money, chèques, virements, clients, ventes d'ouvrages, ventes au comptoir, TVA, fournisseurs, achats, stocks, variations, écarts.
- Migration : `sql/syscohada_revise.sql` (aussi dans `00_installation_complete.sql`).

## Synchronisation local (IndexedDB) ↔ cloud (Supabase), multi-appareils
Écran **Paramètres → 🔄 Synchro**.
- **Envoi** : la file d'attente des saisies faites hors ligne part vers Supabase.
- **Réception** : chaque élément (table) est copié entièrement sur le poste, dans un miroir IndexedDB. Hors ligne, tout écran lit cette copie, **même un écran jamais ouvert sur ce poste**. Les filtres, le tri, la pagination et les relations simples sont appliqués localement.
- **État de la synchronisation (envoi ↔ réception)** : le nombre d'enregistrements **local ↔ cloud**, élément par élément, avec l'un de ces états :
  - ✅ À jour ;
  - ⬆️ n à envoyer ;
  - ⬇️ n à recevoir ;
  - « en trop sur ce poste » (supprimé dans le cloud) ;
  - accès refusé.

  L'écran affiche aussi la date de la dernière réception par élément, les dates du dernier envoi et de la dernière réception, et des totaux.
- **Boutons** :
  - « Synchroniser maintenant » (envoi puis réception) ;
  - « Envoyer local → cloud » ;
  - « Tout récupérer cloud → local » ;
  - « Recevoir » un seul élément ;
  - **🔍 Détail**, qui liste les identifiants présents d'un seul côté ;
  - « File d'attente ».
- **Synchronisation automatique** (désactivable sur le poste) : à l'ouverture de session puis toutes les 30 minutes. La copie locale est effacée à la déconnexion.

## Photos des produits et composants — vente au comptoir
- **Où ajouter une photo** : dans la fiche **Composant** et dans la fiche **Produit**, par l'un de ces moyens :
  - « 🖼️ Choisir une photo » ;
  - « 📷 Prendre une photo » (appareil photo du téléphone) ;
  - glisser-déposer ;
  - Ctrl+V.
- **Compression sur l'appareil** :
  - une **miniature carrée d'environ 240 px (quelques Ko)** est rangée dans la fiche (`composants.photo`, `produits.photo`) ;
  - un **grand format d'environ 1 000 px** est rangé dans `photos_articles`, chargé seulement pour l'agrandir.
- **Catalogues** Composants et Produits : vignettes (grille et liste) ; cliquer sur une vignette l'agrandit.
- **Vente au comptoir** :
  - catalogue **en photos**, avec le prix, le stock du dépôt et un bandeau « Rupture » ;
  - bouton 🔍 pour agrandir la photo ;
  - bouton « Vue compacte / Vue photos » ;
  - miniature dans le panier.
- **Produits et ouvrages vendables au comptoir** : option « Proposé à la vente au comptoir » et prix de vente dans la fiche produit. La vente passe sans mouvement de stock ; le coût est le coût matériel du produit.
- Migration : `sql/photos_articles.sql` (aussi dans `00_installation_complete.sql`).

## Moteur d'impression — en-tête entreprise et QR code de sécurité logiciel
- **Un seul moteur pour tous les documents imprimés** :
  - devis, factures, reçus et tickets de caisse ;
  - bons de caisse et bons de transfert ;
  - fiches client, fournisseur et d'exécution, estimations ;
  - **états périodiques** : point de vente, brouillard de caisse, ticket Z et lecture X, états comptables SYSCOHADA, bulletin de pilotage ;
  - **n'importe quelle page** de l'application, avec le bouton 🖨 du bandeau.
- **En-tête entreprise** : logo, raison sociale, slogan, forme juridique et capital, RCCM, NCC, régime fiscal, centre des impôts, adresse, boîte postale et contacts.
  - Trois présentations au choix : complet, centré ou compact ; couleur au choix.
  - Sous l'en-tête, le **niveau d'émission** : entreprise › point de vente, caisse ou dépôt.
- **Pied de page légal** : identité juridique et fiscale, banque/RIB et mentions libres.
- **Réglages** : Paramètres → 🖨 Impression (avec aperçu et page de test). Les tickets se règlent en 80 mm ou 58 mm.
- **QR code de sécurité logiciel**, distinct du QR code FNE de la DGI :
  - chaque document reçoit un **code d'authenticité** unique (`SX-XXXX-XXXX-XXXX`) ;
  - il reçoit aussi une **signature HMAC** calculée par le serveur avec une clé secrète propre à la base (`securite_documents_cle`, jamais exposée).
- **Registre des documents imprimés** : table `documents_imprimes`.
  - Une réimpression à l'identique garde son code : **impression n° 2, 3… (duplicata)**.
  - Un document dont les données changent reçoit un nouveau code.
- **Vérification sans compte** : le QR ouvre `index.html?verif=CODE.SIGNATURE`.
  - La page affiche « Document authentique » avec type, numéro, montant, tiers, date et nombre d'impressions, pour comparaison avec le papier.
  - Sinon elle affiche « Signature invalide », « Code inconnu » ou « Document révoqué ».
  - La vérification est aussi possible dans Paramètres → 🖨 Impression.
- **Révocation** d'un document (administrateur ou manager) : depuis le registre.
- **QR code FNE (DGI)** : il reste imprimé à part sur les factures certifiées, avec la mention « QR CODE FNE — DGI ». Les QR sont désormais dessinés dans l'application (impression possible hors ligne).
- **Hors ligne** : un code provisoire `LOC-…`, non vérifiable en ligne, est imprimé.
- **Installation** : exécuter `sql/impressions_securite.sql` (section 15 de `00_installation_complete.sql`).

## Inventaire physique — état d'inventaire et justification des écarts
- **Saisie** (Stock → Inventaire) :
  - par dépôt, avec la date, le responsable du comptage et le contrôleur ;
  - recherche et filtres, y compris « Écarts non justifiés » ;
  - valeur de chaque écart au CMUP, avec le total des excédents, des manquants et l'écart net.
- **Justification obligatoire de chaque écart** : un motif normalisé et un commentaire (le commentaire est obligatoire pour « Autre »). Les motifs proposés dépendent du sens de l'écart :
  - casse, vol, perte, péremption, chutes de découpe, consommation non saisie, sortie non saisie ;
  - réception fournisseur non saisie ;
  - transfert non saisi, erreur de saisie, erreur de comptage, erreur d'unité.
- **Blocage de la validation** : tant qu'un écart n'est pas justifié, la validation est refusée. L'application affiche les lignes concernées ; le serveur applique le même contrôle.
- **Brouillon** : les saisies sont gardées sur l'appareil jusqu'à la validation. Recharger la page ou couper la connexion ne fait rien perdre.
- **Feuille de comptage** imprimable : comptage à l'aveugle, sans le stock système, classée par famille avec l'emplacement.
- **Validation atomique** (`inventaire_valider`) :
  - l'inventaire reçoit un numéro **INV-AAAA-NNNN** ;
  - chaque ligne est figée : stock système au moment de la validation, quantité comptée, écart, CMUP, valeur, justification ;
  - les mouvements de stock « inventaire » portent le code de l'inventaire et le motif.
- **États d'inventaire** (Stock → États d'inventaire) :
  - liste des inventaires ;
  - détail avec indicateurs : articles, écarts, fiabilité, valeur théorique et réelle, excédents, manquants, net ;
  - synthèse **par motif** et **par famille** ;
  - détail des écarts et de leurs justifications.
- **Impression** : état des écarts ou état complet, avec en-tête entreprise, sous-totaux par famille, signatures et QR code de sécurité.
- **Justification après validation** : un administrateur ou un manager peut compléter ou corriger une justification (`inventaire_justifier`). La modification est tracée et ne change pas le stock.
- **Comptabilité** (inventaire intermittent SYSCOHADA) : la valeur réelle des stocks est reprise à la clôture (variation des stocks, journal INV).
- **Installation** : exécuter `sql/inventaires.sql` (section 16 de `00_installation_complete.sql`).

## Familles d'articles et unités de mesure (référentiels paramétrables)
- **Où** : Composants → **Familles & unités**, ou Paramètres → 🗂 Familles & unités.
- **Trois onglets** :
  - familles de **composants / consommables** : icône, couleur, ordre, **compte de stock SYSCOHADA** (321 profilés et panneaux, 322 vitrages, 323 fournitures, 331 consommables) ;
  - familles de **produits / ouvrages**, aussi utilisées par les réalisations et le site public ;
  - **unités de mesure** des composants.
- **Création rapide** depuis une fiche composant, produit ou réalisation : « ➕ Nouvelle famille… » et « ➕ Nouvelle unité… » dans les listes déroulantes.
- **Renommer une famille renomme ses articles**. Une famille utilisée ne se supprime pas : on la **fusionne** dans une autre (🔀) ou on la **désactive**.
- **Une famille présente dans les données mais absente du référentiel n'est plus jamais masquée.** Un bandeau propose de l'ajouter au référentiel.
- **Comptabilité** : le compte de stock vient du réglage de la famille, et non plus d'une déduction à partir de son nom. Un article de type « Consommable » va toujours en 331.
- **Unités** : la contrainte CHECK figée des composants est remplacée par une clé étrangère vers `unites_mesure`. Une unité utilisée ne peut pas être supprimée.
- **Installation** : exécuter `sql/familles_referentiels.sql` (section 17 de `00_installation_complete.sql`).

## Revue des données codées en dur (septembre 2026)
**Défaut corrigé** : les familles de composants « Motorisation » et « Panneau », créées par le catalogue d'ouvrages, n'étaient pas dans la liste codée en dur de l'application.
- Leurs articles (13 par base) n'apparaissaient ni dans le catalogue groupé ni au comptoir.
- Ouvrir puis enregistrer un de ces articles le basculait dans une autre famille.
- Le passage au référentiel corrige ces trois points.

**Rendu paramétrable dans cette version**

| Donnée | Avant | Maintenant |
|---|---|---|
| Familles de composants (icône, couleur) | `COMPOSANT_FAMILLES`, `COMPOSANT_FAM_ICONS/COLORS` | table `familles_articles` |
| Familles de produits et de réalisations | `PRODUIT_FAMILLES`, `FAMILLE_ICONS/COLORS` (et une copie dans le site public) | table `familles_articles` |
| Compte de stock d'une famille | déduit du nom de la famille (« vitr », « profil »…) | réglage de la famille |
| Unités des composants | liste fixe + contrainte CHECK en base | table `unites_mesure` |

**Déjà paramétrable** (rien à changer) :
- société, logo, TVA et conditions des documents ;
- comptes comptables par défaut, plan comptable, journaux ;
- FNE (clé, URL, taxe par défaut) ;
- moteur d'impression ;
- catégories de clients et de devis ;
- dépôts, caisses, points de vente, affectations ;
- rôles, droits et plafonds ;
- règles de ventilation de caisse ;
- prix des composants par standing ;
- portail client.

**Volontairement figé** (le code dépend de ces valeurs, ou elles sont réglementaires) :
- **statuts et étapes de cycle de vie** : projets, devis, factures, transferts, ventes, caisse, tickets Z ;
- **types de mouvements de stock** et **modes de paiement**, liés aux journaux comptables et à la correspondance FNE ;
- **FNE** : modèles B2C, B2B et B2G, codes de taxe TVA à TVAD (nomenclature DGI) ;
- **SYSCOHADA révisé** : classes, rubriques du bilan et du compte de résultat (réglementaire) ;
- **unités des produits** (unité, m², ml) : elles pilotent le calcul du prix des ouvrages ;
- **types d'article** (Composant / Consommable) et **standings** (économique, standard, premium) : ils pilotent la comptabilité et le chiffrage.

**À traiter plus tard** (recommandations)
1. **Prix de secours du configurateur** (`OUV_PRIX_HISTO`) : des prix unitaires codés en dur servent si un composant est absent du catalogue. Risque de devis au mauvais prix. Il faudrait plutôt signaler le composant manquant.
2. **Catalogue technique du configurateur** (séries de profilés, vitrages, finitions RAL : `CATALOGUE_SYSTEMES/VITRAGES/FINITIONS`) : à passer en tables pour ajouter une série ou une teinte sans développement.
3. **Motifs d'écart d'inventaire** : ils sont définis deux fois, dans l'application (`INV_MOTIFS`) et dans la base (`inventaire_motif_libelle`). À passer en table si la liste doit évoluer.
4. **Types de dépôts** (dépôt, magasin, atelier, chantier) : contrainte CHECK, à passer en référentiel si besoin.
5. **Sauvegarde JSON** : les inventaires, les tickets Z et le registre des documents imprimés ne sont pas dans l'export. Ils sont protégés en écriture et ne peuvent donc pas être réimportés tels quels. Il faudrait un export en lecture seule de ces journaux.

## Valorisation du stock — valeur d'achat, CA prévisionnel et marge
- **Où** : Stock → **Valorisation du stock**.
- **Par article** :
  - quantité ;
  - coût unitaire : CMUP, à défaut le prix d'achat du catalogue, signalé « estimé » ;
  - **valeur d'achat** ;
  - prix de vente et **CA prévisionnel** ;
  - **marge brute HT** et taux de marge ;
  - classe ABC ;
  - date de la dernière sortie.
- **Totaux** :
  - valeur d'achat du stock ;
  - CA prévisionnel TTC et HT ;
  - marge brute prévisionnelle et taux ;
  - coefficient moyen (prix de vente HT ÷ coût).
- **Données utiles en plus** :
  - stock sans prix de vente, exclu du CA et de la marge ;
  - articles à marge négative ;
  - **stock dormant** (plus de 90 jours sans sortie) ;
  - anomalies : stocks négatifs, coûts estimés ;
  - classes **ABC** : A = 80 % de la valeur, B = 15 %, C = 5 %.
- **Filtres** : lieu de stock, famille, type, standing, stock (en stock / tout / négatif), prix de vente (avec / sans), marge (négative, sous 20 %, 20 % ou plus), classe ABC, dormant, recherche.
- **Regroupement** : par famille, lieu de stock, type, standing, ou liste simple. **Tri** : valeur, CA, marge, taux, quantité, désignation.
- **Synthèses** par famille, **par lieu de stock** et par classe ABC.
- **Prix TTC** : les prix de vente du catalogue sont considérés comme TTC (comme au comptoir). La marge est calculée sur le HT (TTC ÷ (1 + TVA)). Une case permet de les traiter comme des prix HT.
- **Sorties** :
  - **impression** A4 paysage, avec en-tête, filtres appliqués, indicateurs, synthèses, détail regroupé avec sous-totaux, signatures et QR de sécurité ;
  - **Excel (CSV)** ;
  - **📤 WhatsApp / e-mail** : le document est généré en **PDF**. Sur téléphone, il est joint directement via le partage de l'appareil. Sur ordinateur, il est téléchargé et WhatsApp Web ou la messagerie s'ouvrent avec un message résumé prérempli ; le PDF est à joindre. Le dernier numéro et la dernière adresse utilisés sont mémorisés.
- **Réutilisable** : la génération PDF et l'envoi (`impGenererPdf`, `impOuvrirEnvoi`) font partie du moteur d'impression et pourront servir aux autres documents.

## Application installable — PC, smartphone et tablette
L'ERP est une **application web progressive (PWA)** : elle s'installe comme un logiciel, sans magasin d'applications.
- Une fois installée, elle a son icône et sa fenêtre propre, s'ouvre en plein écran, **fonctionne hors ligne** et se met à jour automatiquement.
- **Bouton 📲 « Installer l'application »** : sur l'écran de connexion, dans le bandeau et en bas du menu. Il est masqué si l'application est déjà installée.
  - **PC Windows / Mac / Linux** (Chrome, Edge) et **Android** (Chrome, Edge, Samsung Internet) : le bouton ouvre l'invite d'installation du navigateur. On peut aussi passer par l'icône d'installation de la barre d'adresse ou le menu ⋮ → « Installer l'application ».
  - **iPhone / iPad** (Safari ; Chrome et Edge depuis iOS 16.4) : le bouton affiche la marche à suivre, Partager ⬆️ → « Sur l'écran d'accueil ». Mac avec Safari 17+ : Fichier → « Ajouter au Dock ».
  - **Firefox** ne permet pas l'installation : utilisez Chrome ou Edge.
- **Raccourcis** (appui long ou clic droit sur l'icône) : Vente au comptoir, Nouveau devis, Inventaire, Valorisation du stock. Ils s'appuient sur l'adresse `?page=…`, qui ouvre la page demandée après la connexion.
- **Mises à jour** : l'application vérifie chaque heure s'il existe une nouvelle version. Un bandeau propose alors « Recharger », sans jamais recharger de force pendant une saisie.
- **Fichiers** :
  - `manifest.webmanifest` : identifiant, icônes PNG 192/512 standard et « maskable » (Android), raccourcis, `display_override`, `launch_handler` ;
  - `icons/` : `apple-touch-icon.png` 180 px pour iOS, favicon ;
  - balises iOS et Android dans `index.html` ;
  - `sw.js` : met les icônes en cache.
- **Petits écrans** : les icônes secondaires du bandeau (impression, messages) sont masquées sur téléphone pour garder le titre de la page visible.

## Inventaire : enregistrer, reprendre, imprimer (révision)
- **Brouillon enregistré sur le serveur** (💾 « Enregistrer le brouillon ») :
  - l'inventaire reçoit tout de suite son numéro INV-AAAA-NNNN ;
  - le stock n'est **pas** modifié ;
  - on le reprend sur **n'importe quel appareil** : bandeau « Brouillon(s) enregistré(s) » sur l'écran de saisie, ou « Reprendre » depuis les États d'inventaire ;
  - on peut l'abandonner.
  - Les saisies restent aussi sauvegardées automatiquement sur l'appareil.
- **Inventaire partiel ou complet** :
  - par défaut, l'inventaire est **partiel** : seuls les articles **comptés ✓** (quantité saisie, ou « ✓ Marquer comptés les articles affichés » pour confirmer un stock) sont enregistrés et ajustés ; les autres articles ne sont pas touchés ;
  - la case « Inventaire complet du dépôt » inclut tous les articles, les non-comptés étant confirmés à leur stock système ;
  - filtres « Articles comptés » et « Articles non comptés ».
- **Justification en lot** : un motif et un commentaire s'appliquent d'un coup à tous les écarts non justifiés affichés. Un nouveau motif **« Stock initial / reprise de stock »** sert à la mise en place du stock d'un dépôt.
- **Impression** :
  - **🖨 État provisoire** depuis l'écran de saisie, avant validation, avec le filigrane « PROVISOIRE » ;
  - après validation, une fenêtre propose l'état des écarts, l'état complet ou l'envoi ;
  - les états indiquent « partiel (n articles comptés sur N) » ou « complet ».
- **Envoi 📤 WhatsApp / e-mail** de l'état d'inventaire en PDF, depuis la liste et le détail.
- **Régularisation des ajustements hors registre** : les ajustements « inventaire » passés sans être rattachés à un inventaire (saisie unitaire, ou poste resté sur une ancienne version) sont signalés dans les États d'inventaire.
  - « Régulariser » (administrateur ou manager) crée l'inventaire enregistré correspondant, imprimable et justifié, **sans retoucher le stock**.
- **Installation** : exécuter `sql/inventaires_brouillons.sql` (section 18 de `00_installation_complete.sql`).

## Achats & approvisionnement — commandes fournisseur, réceptions, commandes internes
Menu **Approvisionnement → Achats & commandes**.
- **Bon de commande fournisseur** (BC-AAAA-NNNN) :
  - saisie : fournisseur, dépôt de livraison, dates, référence du devis fournisseur, conditions, chantier ;
  - lignes avec prix HT et remise, frais, TVA, totaux HT et TTC ;
  - statuts : brouillon → envoyée → partiellement reçue → reçue, ou soldée (le reste est abandonné) ou annulée ;
  - impression avec le montant en lettres, et **envoi du PDF au fournisseur** par WhatsApp ou e-mail (numéro et adresse du fournisseur préremplis).
- **Réception** (BR-AAAA-NNNN) depuis une commande (reste à recevoir prérempli, réceptions partielles suivies) ou **sans commande** :
  - chaque réception **augmente le stock du dépôt choisi** au prix d'achat, et le coût moyen pondéré (CMUP) est recalculé ;
  - le mouvement « entrée » porte la référence BR ;
  - l'achat est comptabilisé : journal AC, comptes d'achat selon la famille des articles, crédit fournisseur ;
  - bon de réception imprimable.
  - Une quantité reçue supérieure au reste commandé est refusée.
- **Commande interne** (CI-AAAA-NNNN) : un dépôt, magasin, atelier ou chantier demande des articles à un autre dépôt.
  - Cycle : brouillon → soumise → **validée** (administrateur ou manager) ou refusée → **servie** par un **transfert de stock**.
  - Au service, le stock sort du dépôt fournisseur. Il entre au dépôt demandeur tout de suite (réception immédiate) ou à la réception du transfert.
  - Service partiel possible, et solde de la commande.
- **Alertes stock** : « Commander les ruptures » prérempli un bon de commande fournisseur avec les articles sous le seuil, au niveau du stock maximum (ou 2 × le minimum). « Demander à un autre dépôt » crée une commande interne.
- **Installation** : exécuter `sql/achats_commandes.sql` (section 19 de `00_installation_complete.sql`).

## Journal des mouvements de stock
Stock → **Journal des mouvements** : tous les mouvements (réceptions, ventes, sorties chantier, transferts, inventaires, ajustements).
- **Filtres** : période (du / au), dépôt, type, entrées ou sorties, famille, article, utilisateur, chantier, pièce ou référence (BR-, INV-, TR-…).
- **Indicateurs** : nombre de mouvements, entrées et sorties **en valeur**, variation nette.
- **Synthèses** par type et par dépôt.
- **Détail** : pièce cliquable (bon de réception, inventaire, transfert), prix unitaire, valeur, stock du dépôt après le mouvement, auteur.
- **Sorties** : impression A4 paysage, Excel (CSV), envoi PDF par WhatsApp ou e-mail.

## Centre de validation — Direction générale & hiérarchie autorisée (modèle Menko Immo)
Menu **✅ Validations** (en haut du menu, badge = demandes que **vous** pouvez décider) : une seule page pour tout ce qui attend une décision.
- **Types de demandes** : bons d'entrée / de sortie et transferts de **caisse** (circuit DG existant), **bons de commande fournisseur** au-delà d'un seuil, **commandes internes** entre dépôts.
- **⏳ En attente** : filtres par type avec badges, ancienneté, palier requis ; boutons **Valider / Rejeter** (motif obligatoire), ou **🔒 réservé à la hiérarchie** si votre rôle ne couvre pas le montant. Les plus anciennes en tête.
- **🗂️ Historique des décisions** : filtres période, type, décision (validées / rejetées / annulées), personne, recherche ; valideur et délai de décision ; export Excel.
- **📊 État périodique par type** : soumises, validées, rejetées, en attente (nombre et montant), taux de validation et délai moyen, par type et par valideur ; impression A4 (en-tête entreprise + QR de sécurité), PDF par WhatsApp / e-mail, Excel.
- **🏛️ Hiérarchie & seuils** :
  - **paliers par montant** (modèle : N+1 au-delà de 1 000 000, Direction N+2 au-delà de 5 000 000, DG / PDG au-delà de 20 000 000) : au-delà d'un seuil, seul un rôle de niveau suffisant décide. Inactifs par défaut ; bouton « Modèle 1 M / 5 M / 20 M » ;
  - **seuil des bons de commande** (500 000 FCFA TTC par défaut) : au-delà, la commande est **soumise à validation** ; elle ne peut être envoyée au fournisseur ni réceptionnée avant validation. Un décideur habilité la valide en la marquant envoyée. Une hausse du montant après validation annule la validation ;
  - **mode du circuit de caisse** ;
  - tableau **« qui peut décider quoi »** : droit « valider » par module, plafond et niveau de chaque rôle, montant maximal décidable.
- **Règle de décision** (contrôlée aussi dans la base, fonction `peut_valider`) : droit « valider » du module (Caisse ou Stock) **et** plafond du rôle couvrant le montant **et** niveau de rôle au moins égal au palier. L'administrateur (DG) passe tous les paliers.
- Commandes fournisseur : bandeau de validation sur la fiche (soumise / validée / rejetée avec motif) et filtre « 🔐 En attente de validation » dans la liste.
- Migration : `sql/validations_hierarchie.sql` (section 20 de `00_installation_complete.sql`).

## Portail client — refonte visuelle
Paramètres → 🌐 Portail client génère toujours un fichier HTML unique et autonome (aucune dépendance à héberger côté ERP), mais avec un design entièrement revu :
- Typographie **Plus Jakarta Sans**, en-tête « verre dépoli » collant en haut de page, favicon et titre d'onglet générés dynamiquement (monogramme aux couleurs de l'entreprise).
- **Section d'accueil** avec bandeau dégradé, badge, accroche et indicateurs (nombre de réalisations publiées, sur-mesure, délai de réponse).
- **Cartes de savoir-faire et galerie de réalisations** avec effet de survol, zoom léger sur les photos.
- **Bouton WhatsApp flottant** persistant (si un numéro est renseigné), pastille animée.
- **Espace client** : formulaire de connexion repensé (avatar, champs modernisés), suivi de chantier en **frise verticale** (étapes franchies, étape en cours mise en évidence, étapes à venir), devis et factures avec **badges de statut colorés**.
- Aucun changement de logique : mêmes champs de configuration (nom, slogan, couleur, coordonnées, réseaux sociaux, à propos), même RPC `portail_lookup`, même fichier généré côté client.

## Portail client — vitrine complète (produits, portfolio filtrable, mot du DG)
Le portail devient un vrai site vitrine, avec les commodités d'un site moderne :
- **Onglet 📦 Produits** : catalogue des gammes fabriquées (photo + nom + famille, sans prix), alimenté automatiquement par les produits **ayant une photo** (Produits → fiche du produit). Filtres par famille.
- **Réalisations** enrichies : filtres par famille, et **visionneuse plein écran** (lightbox) avec navigation précédent/suivant, clavier (← → Échap), titre, famille et description — réutilisée pour le catalogue produits.
- **« Comment nous travaillons »** : quatre étapes numérotées (devis gratuit, fabrication sur-mesure, pose, suivi en ligne) sur la page d'accueil.
- **Bandeau d'appel à l'action** (« Prêt à démarrer votre projet ? ») avant le pied de page.
- **Le mot du DG** : nouvelle rubrique dans Paramètres → Portail client — photo, nom, fonction et message de la direction, affichés en citation sur la page « À propos » (masquée si aucun message n'est renseigné).
- **Référencement** : balises Open Graph (titre, description, image) et méta-description mises à jour dynamiquement, en plus du favicon et du titre d'onglet déjà générés automatiquement.
- Migration : `sql/portail_dg.sql` (colonnes `portail_dg_nom/titre/message/photo` sur `parametres`), copiée en section 21 de `00_installation_complete.sql`.

## Portail « toujours à jour » — `portail-unique.html` (modèle Menko Immo)
Deux façons de générer le site, depuis Paramètres → 🌐 Portail client :
- **🔗 « portail-unique.html » (recommandé)** : ne fige **aucune donnée métier** — juste la connexion Supabase. À chaque visite, la page interroge en direct la fonction publique `portail_donnees_publiques()` (lecture seule, SECURITY DEFINER, jamais de données internes). **Un seul dépôt suffit** : toute modification faite dans l'ERP (réalisations, produits, mot du DG, coordonnées, activation) apparaît aussitôt sur le site, sans régénérer ni redéposer le fichier. C'est ce fichier qu'on connecte à un dépôt GitHub → déploiement Vercel automatique (`git push` sur `main` → site à jour ; le contenu, lui, est déjà à jour en continu grâce à la RPC).
- **📤 Instantané (.html)** : comportement précédent, données figées au moment de la génération — utile pour un envoi ponctuel ou un hébergement sans dépôt automatisé, mais à régénérer et redéposer à chaque changement de contenu.
- La case **« Portail actif »** est désormais réellement respectée par les deux formats : décochée, le site public affiche « momentanément indisponible » sans exposer la moindre donnée (auparavant seul le portail de connexion client (`portail_lookup`) la respectait).
- Migration : `sql/portail_public.sql` (fonction `portail_donnees_publiques()`, accessible en lecture par `anon`), copiée en section 22 de `00_installation_complete.sql`.
- Déploiement : `public-site/portail-unique.html` — dossier dédié, pensé pour un **projet Vercel séparé** de l'ERP (qui reste protégé par SSO), avec la protection désactivée sur ce projet précis puisque le site est public par nature.

## Revue de sécurité — accès au portail par code client + téléphone
Constat : `portail_lookup(code, téléphone)` est appelable par n'importe qui (public), sans authentification. Or les codes clients sont **séquentiels** (`C-1`, `C-2`, `C-3`…), donc triviaux à énumérer, et le téléphone n'est comparé que sur ses **8 derniers chiffres** (tolérance de saisie volontaire, conservée). Sans limite d'appels, un script automatisé pouvait donc parcourir tous les codes et essayer des numéros jusqu'à tomber juste, exposant les projets, devis et factures de chaque client — une vraie fuite de données personnelles et financières.
- **Corrigé** : limite globale anti-parcours (30 appels/minute, tous codes confondus) + verrou par code (5 échecs en 15 min → blocage 30 min, y compris avec le bon numéro tant que le verrou tient). Un autre code client n'est jamais affecté par le verrou d'un autre.
- Aucun changement du format de réponse ni de la tolérance de saisie pour un utilisateur légitime (message dédié « Trop de tentatives » uniquement en cas de blocage).
- Migration : `sql/portail_securite.sql` (table `portail_tentatives`, fonction `portail_lookup` durcie), section 23 de `00_installation_complete.sql`.

## Envoyer le code d'accès au portail (WhatsApp / e-mail)
Fiche client (bouton dans le formulaire) et liste des clients (menu ⚙) : **📲 Envoyer le code d'accès**.
- Compose un message prêt à l'emploi (lien du portail, code client, rappel du numéro enregistré) et ouvre WhatsApp et/ou l'e-mail du client — jamais de mot de passe envoyé, seulement le rappel des deux informations déjà exigées par `portail_lookup` (durci par le verrou anti-énumération).
- Nécessite l'**URL du portail** (Paramètres → Portail client → « URL du portail en ligne ») ; sinon le bouton redirige vers ce réglage.
- Avertit avant l'envoi si le portail n'est pas encore **activé**.
- Migration : `sql/portail_url.sql` (colonne `portail_url` sur `parametres`), section 24 de `00_installation_complete.sql`.
