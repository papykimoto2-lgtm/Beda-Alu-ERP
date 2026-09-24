-- ============================================================================
-- Sanix AluExpert ERP — INSTALLATION COMPLÈTE D'UNE NOUVELLE STRUCTURE
-- © Sanix Africa Division Technologies
-- ============================================================================
-- À exécuter UNE FOIS, dans l'éditeur SQL d'un projet Supabase NEUF et VIDE
-- (Supabase → SQL Editor → coller ce fichier → Run).
-- Crée toute la base de l'application : tables, contraintes, fonctions, déclencheurs,
-- règles de sécurité (RLS), et les référentiels de départ (journaux, plan comptable
-- SYSCOHADA de base, catalogue technique du configurateur, dépôt / caisse / point de vente).
-- Aucune donnée d'une autre entreprise n'est incluse.
--
-- Généré à partir de la base de référence ; équivaut à l'ensemble des scripts de sql/
-- (qui restent pour mettre à jour une installation existante).
-- Ensuite : déployer les Edge Functions de supabase/functions/ (connexion, gestion-utilisateurs,
-- fne-proxy), créer config.js, créer le premier compte (administrateur) puis remplir Paramètres → Entreprise.
-- ============================================================================

create extension if not exists pgcrypto with schema extensions;
set check_function_bodies = off;   -- les fonctions se référencent entre elles : ordre de création libre

-- ---------------------------------------------------------------------------
-- 1. Compteurs de numérotation et tables
-- ---------------------------------------------------------------------------
create sequence if not exists public.clients_code_seq;
create sequence if not exists public.devis_code_seq;
create sequence if not exists public.factures_code_seq;
create sequence if not exists public.fiches_code_seq;
create sequence if not exists public.fournisseurs_code_seq;
create sequence if not exists public.projets_code_seq;
create sequence if not exists public.prospects_code_seq;

create table if not exists public.caisse_affectations (
  caisse_id uuid not null,
  user_id uuid not null,
  created_at timestamp with time zone default now() not null
);
create table if not exists public.caisse_mouvements (
  id uuid default gen_random_uuid() not null,
  session_id uuid not null,
  caisse_id uuid not null,
  numero text,
  date_mouvement date not null,
  type text not null,
  montant numeric(14,2) not null,
  motif text not null,
  beneficiaire text,
  piece_ref text,
  statut text default 'a_ventiler'::text not null,
  compte_ventile text,
  ecriture_id uuid,
  transfert_id uuid,
  created_by uuid,
  created_at timestamp with time zone default now() not null
);
create table if not exists public.caisse_mouvements_audit (
  id uuid default gen_random_uuid() not null,
  mouvement_id uuid,
  caisse_id uuid,
  numero text,
  action text not null,
  donnees jsonb,
  details jsonb,
  user_email text,
  created_at timestamp with time zone default now() not null
);
create table if not exists public.caisse_pins (
  user_id uuid not null,
  pin_hash text not null,
  echecs integer default 0 not null,
  bloque_jusqu timestamp with time zone,
  defini_par uuid,
  updated_at timestamp with time zone default now() not null
);
create table if not exists public.caisse_regles_ventilation (
  id uuid default gen_random_uuid() not null,
  mot_cle text not null,
  compte_code text not null,
  created_at timestamp with time zone default now() not null
);
create table if not exists public.caisse_sessions (
  id uuid default gen_random_uuid() not null,
  caisse_id uuid not null,
  date_session date not null,
  fond_ouverture numeric(14,2) default 0 not null,
  fond_cloture_theorique numeric(14,2),
  fond_cloture_reel numeric(14,2),
  ecart numeric(14,2),
  statut text default 'ouverte'::text not null,
  ouverte_par text,
  ouverte_le timestamp with time zone default now() not null,
  cloturee_par text,
  cloturee_le timestamp with time zone,
  ecart_ecriture_id uuid,
  ouverte_par_id uuid,
  cloturee_par_id uuid
);
create table if not exists public.caisses (
  id uuid default gen_random_uuid() not null,
  nom text not null,
  projet_id uuid,
  compte_code text default '571000'::text not null,
  responsable text,
  actif boolean default true not null,
  created_at timestamp with time zone default now() not null
);
create table if not exists public.client_categories (
  id uuid default gen_random_uuid() not null,
  nom text not null,
  created_at timestamp with time zone default now() not null
);
create table if not exists public.clients (
  id uuid default gen_random_uuid() not null,
  code text default ('C-'::text || (nextval('clients_code_seq'::regclass))::text) not null,
  civilite text default 'Monsieur'::text,
  nom text not null,
  prenoms text,
  entreprise text,
  telephone text,
  email text,
  pays text default 'Côte d''Ivoire'::text,
  commune text,
  quartier text,
  categorie text default 'Particulier'::text,
  adresse text,
  source text,
  commercial text,
  created_at timestamp with time zone default now() not null,
  created_by uuid,
  ncc text,
  rccm text,
  regime_fiscal text,
  latitude numeric,
  longitude numeric
);
create table if not exists public.composants (
  id uuid default gen_random_uuid() not null,
  nom text not null,
  type text default 'Composant'::text not null,
  famille text default 'Autre'::text not null,
  unite text default 'unite'::text not null,
  prix_unitaire numeric default 0 not null,
  reference text,
  created_at timestamp with time zone default now() not null,
  created_by uuid,
  code text,
  stock_actuel numeric default 0 not null,
  stock_min numeric default 0 not null,
  stock_max numeric,
  emplacement text,
  cmup numeric default 0 not null,
  standing text default 'standard'::text not null,
  prix_vente numeric
);
create table if not exists public.compta_comptes (
  code text not null,
  libelle text not null,
  classe smallint not null,
  nature text not null,
  actif boolean default true not null,
  created_at timestamp with time zone default now() not null
);
create table if not exists public.compta_ecritures (
  id uuid default gen_random_uuid() not null,
  ref text not null,
  exercice_annee integer not null,
  date_ecriture date not null,
  journal_code text not null,
  piece text,
  libelle text not null,
  projet_id uuid,
  source text default 'manuel'::text not null,
  source_type text,
  source_id uuid,
  valide_le timestamp with time zone,
  valide_par text,
  contre_passation_de uuid,
  created_by uuid,
  created_at timestamp with time zone default now() not null
);
create table if not exists public.compta_exercices (
  id uuid default gen_random_uuid() not null,
  annee integer not null,
  date_debut date not null,
  date_fin date not null,
  statut text default 'ouvert'::text not null,
  cloture_le timestamp with time zone,
  cloture_par text,
  created_at timestamp with time zone default now() not null
);
create table if not exists public.compta_journaux (
  code text not null,
  libelle text not null
);
create table if not exists public.compta_lignes (
  id uuid default gen_random_uuid() not null,
  ecriture_id uuid not null,
  compte_code text not null,
  libelle text,
  sens text not null,
  montant numeric(14,2) not null,
  tiers_type text,
  tiers_id uuid
);
create table if not exists public.depots (
  id uuid default gen_random_uuid() not null,
  code text not null,
  nom text not null,
  type text default 'depot'::text not null,
  adresse text,
  commune text,
  responsable text,
  telephone text,
  est_principal boolean default false not null,
  actif boolean default true not null,
  created_at timestamp with time zone default now() not null
);
create table if not exists public.devis (
  id uuid default gen_random_uuid() not null,
  code text default ('DVS-'::text || (nextval('devis_code_seq'::regclass))::text) not null,
  libelle text,
  client_id uuid not null,
  projet_id uuid,
  date_creation date default CURRENT_DATE not null,
  date_echeance date,
  statut text default 'en_attente'::text not null,
  categorie text,
  commercial text,
  lieu_affaire text,
  pays text default 'Côte d''Ivoire'::text,
  commune text,
  quartier text,
  reduction numeric default 0 not null,
  autre_frais numeric default 0 not null,
  total numeric default 0 not null,
  created_at timestamp with time zone default now() not null,
  created_by uuid,
  racine_id uuid not null,
  version_number integer default 1 not null,
  is_current boolean default true not null
);
create table if not exists public.devis_categories (
  id uuid default gen_random_uuid() not null,
  nom text not null,
  created_at timestamp with time zone default now() not null
);
create table if not exists public.devis_lignes (
  id uuid default gen_random_uuid() not null,
  devis_id uuid not null,
  piece text default 'Non renseigné'::text not null,
  produit_id uuid,
  titre text not null,
  largeur numeric default 0 not null,
  hauteur numeric default 0 not null,
  quantite numeric default 1 not null,
  remise_pct numeric default 0 not null,
  prix_unitaire numeric default 0 not null,
  total numeric default 0 not null,
  ordre integer default 0 not null,
  created_at timestamp with time zone default now() not null,
  cout_materiel_pct numeric default 60 not null,
  composant_id uuid
);
create table if not exists public.factures (
  id uuid default gen_random_uuid() not null,
  code text default ('FCT-'::text || (nextval('factures_code_seq'::regclass))::text) not null,
  devis_id uuid,
  client_id uuid not null,
  date_facture date default CURRENT_DATE not null,
  total numeric default 0 not null,
  statut text default 'en_attente'::text not null,
  created_at timestamp with time zone default now() not null,
  created_by uuid,
  type_facture text default 'simple'::text not null,
  fne_reference text,
  fne_statut text
);
create table if not exists public.fiche_execution_lignes (
  id uuid default gen_random_uuid() not null,
  fiche_id uuid not null,
  devis_ligne_id uuid,
  piece text default 'Non renseigné'::text not null,
  produit text not null,
  largeur_commande numeric,
  hauteur_commande numeric,
  largeur_mesuree numeric,
  hauteur_mesuree numeric,
  fabrication_alu text default ''::text,
  fabrication_vitrage text default ''::text,
  pose_alu text default ''::text,
  pose_vitrage text default ''::text,
  controle_re text default ''::text,
  controle_termine text default ''::text,
  commentaires text default ''::text,
  ordre integer default 0 not null
);
create table if not exists public.fiches_execution (
  id uuid default gen_random_uuid() not null,
  code text default ('FE-'::text || (nextval('fiches_code_seq'::regclass))::text) not null,
  devis_id uuid not null,
  projet_id uuid,
  commercial text,
  lieu_affaire text,
  date_visite date,
  responsable_chantier text,
  statut text default 'en_attente'::text not null,
  created_at timestamp with time zone default now() not null,
  created_by uuid,
  updated_at timestamp with time zone default now() not null,
  mesure_prise_par uuid,
  mesure_prise_le timestamp with time zone,
  fabrication_lancee_par uuid,
  fabrication_lancee_le timestamp with time zone
);
create table if not exists public.fournisseurs (
  id uuid default gen_random_uuid() not null,
  code text default ('F-'::text || (nextval('fournisseurs_code_seq'::regclass))::text) not null,
  nom text not null,
  contact_principal text,
  telephone text,
  email text,
  pays text default 'Côte d''Ivoire'::text,
  commune text,
  quartier text,
  categorie text default 'Matériaux'::text,
  adresse text,
  created_at timestamp with time zone default now() not null,
  created_by uuid,
  ncc text,
  rccm text,
  regime_fiscal text
);
create table if not exists public.mouvements_stock (
  id uuid default gen_random_uuid() not null,
  composant_id uuid not null,
  type text not null,
  quantite numeric not null,
  prix_unitaire numeric,
  stock_apres numeric not null,
  cmup_apres numeric not null,
  motif text,
  reference text,
  created_at timestamp with time zone default now() not null,
  created_by uuid,
  depot_id uuid,
  transfert_id uuid,
  stock_depot_apres numeric
);
create table if not exists public.paiements (
  id uuid default gen_random_uuid() not null,
  facture_id uuid not null,
  date_paiement date default CURRENT_DATE not null,
  montant numeric(14,2) not null,
  mode text not null,
  caisse_id uuid,
  reference text,
  ecriture_id uuid,
  created_by uuid,
  created_at timestamp with time zone default now() not null
);
create table if not exists public.parametres (
  id uuid default gen_random_uuid() not null,
  raison_sociale text default ''::text not null,
  rccm text,
  ncc text,
  regime_fiscal text default 'reel_simplifie'::text,
  tva_pct numeric default 18 not null,
  adresse text,
  email text,
  telephone text,
  site_web text,
  whatsapp text,
  logo_base64 text,
  derniere_sauvegarde timestamp with time zone,
  updated_at timestamp with time zone default now() not null,
  fne_actif boolean default false not null,
  fne_environnement text default 'test'::text not null,
  fne_api_key text,
  fne_url_test text default 'http://54.247.95.108/ws'::text,
  fne_url_prod text,
  fne_point_vente text default '1'::text,
  fne_etablissement text default 'Principal'::text,
  portail_actif boolean default false not null,
  portail_nom text,
  portail_slogan text,
  portail_couleur text default '#1D3557'::text not null,
  site_a_propos text,
  site_facebook text,
  site_instagram text,
  comptes_defaut jsonb default '{}'::jsonb not null,
  fne_taxe_defaut text default 'TVA'::text not null,
  conditions_documents text
);
create table if not exists public.point_vente_affectations (
  point_vente_id uuid not null,
  user_id uuid not null,
  par_defaut boolean default false not null,
  created_at timestamp with time zone default now() not null
);
create table if not exists public.points_vente (
  id uuid default gen_random_uuid() not null,
  code text not null,
  nom text not null,
  depot_id uuid not null,
  caisse_id uuid,
  adresse text,
  responsable text,
  telephone text,
  actif boolean default true not null,
  created_at timestamp with time zone default now() not null
);
create table if not exists public.produits (
  id uuid default gen_random_uuid() not null,
  nom text not null,
  unite text default 'm2'::text not null,
  prix_vente numeric default 0 not null,
  cout_materiel numeric default 0 not null,
  created_at timestamp with time zone default now() not null,
  cout_materiel_pct numeric default 60 not null,
  config_json jsonb,
  alu_ml numeric,
  glass_m2 numeric,
  famille text default 'Autre'::text not null
);
create table if not exists public.profiles (
  id uuid not null,
  nom_complet text,
  role text default 'utilisateur'::text not null,
  created_at timestamp with time zone default now() not null,
  latitude numeric,
  longitude numeric,
  position_updated_at timestamp with time zone
);
create table if not exists public.projets (
  id uuid default gen_random_uuid() not null,
  code text default ('CH-'::text || (nextval('projets_code_seq'::regclass))::text) not null,
  libelle text not null,
  client_id uuid,
  date_debut date,
  date_fin date,
  pays text default 'Côte d''Ivoire'::text,
  commune text,
  quartier text,
  categorie text default 'Habitation'::text,
  source text,
  responsable text,
  description text,
  created_at timestamp with time zone default now() not null,
  created_by uuid,
  etape text default 'en_attente'::text not null,
  latitude numeric,
  longitude numeric
);
create table if not exists public.prospects (
  id uuid default gen_random_uuid() not null,
  code text default ('P-'::text || (nextval('prospects_code_seq'::regclass))::text) not null,
  civilite text default 'Monsieur'::text,
  nom text not null,
  prenoms text,
  entreprise text,
  telephone text,
  email text,
  pays text default 'Côte d''Ivoire'::text,
  commune text,
  quartier text,
  statut text default 'nouveau'::text not null,
  source text,
  commercial text,
  notes text,
  created_at timestamp with time zone default now() not null,
  created_by uuid,
  latitude numeric,
  longitude numeric
);
create table if not exists public.realisations (
  id uuid default gen_random_uuid() not null,
  titre text not null,
  description text,
  famille text,
  photo_base64 text,
  ordre integer default 0 not null,
  publie boolean default true not null,
  created_at timestamp with time zone default now() not null,
  created_by uuid
);
create table if not exists public.stocks_depot (
  depot_id uuid not null,
  composant_id uuid not null,
  quantite numeric default 0 not null
);
create table if not exists public.transferts_stock (
  id uuid default gen_random_uuid() not null,
  code text,
  depot_source_id uuid not null,
  depot_destination_id uuid not null,
  statut text default 'brouillon'::text not null,
  motif text,
  notes_reception text,
  date_expedition timestamp with time zone,
  date_reception timestamp with time zone,
  expedie_par text,
  recu_par text,
  annule_par text,
  created_by uuid,
  created_at timestamp with time zone default now() not null
);
create table if not exists public.transferts_stock_lignes (
  id uuid default gen_random_uuid() not null,
  transfert_id uuid not null,
  composant_id uuid not null,
  quantite_envoyee numeric not null,
  quantite_recue numeric,
  cmup numeric,
  ordre integer default 0 not null
);
create table if not exists public.ventes_comptoir (
  id uuid default gen_random_uuid() not null,
  code text,
  date_vente date default CURRENT_DATE not null,
  client_id uuid,
  client_nom text,
  client_telephone text,
  sous_total numeric default 0 not null,
  remise numeric default 0 not null,
  total numeric default 0 not null,
  cout_total numeric default 0 not null,
  mode_paiement text default 'espece'::text not null,
  montant_recu numeric,
  monnaie_rendue numeric,
  reference_paiement text,
  caisse_id uuid,
  statut text default 'validee'::text not null,
  ecriture_id uuid,
  motif_annulation text,
  annulee_le timestamp with time zone,
  annulee_par text,
  vendeur text,
  created_by uuid,
  created_at timestamp with time zone default now() not null,
  point_vente_id uuid,
  depot_id uuid,
  fne_statut text,
  fne_reference text,
  fne_token text,
  fne_invoice_id text,
  fne_template text,
  fne_client_nom text,
  fne_client_ncc text,
  fne_client_telephone text,
  fne_client_email text,
  fne_certifiee_le timestamp with time zone,
  fne_erreur text,
  fne_reponse jsonb,
  fne_avoir_reference text,
  fne_avoir_token text,
  facture_imprimee_le timestamp with time zone,
  client_ncc text,
  client_adresse text
);
create table if not exists public.ventes_comptoir_lignes (
  id uuid default gen_random_uuid() not null,
  vente_id uuid not null,
  composant_id uuid,
  designation text not null,
  unite text,
  quantite numeric not null,
  prix_unitaire numeric default 0 not null,
  prix_achat numeric default 0 not null,
  remise_pct numeric default 0 not null,
  total numeric default 0 not null,
  ordre integer default 0 not null
);

-- ---------------------------------------------------------------------------
-- 2. Clés primaires, unicités, contrôles, clés étrangères, index
-- ---------------------------------------------------------------------------
alter table public.caisse_affectations add constraint caisse_affectations_pkey PRIMARY KEY (caisse_id, user_id);
alter table public.caisse_mouvements add constraint caisse_mouvements_pkey PRIMARY KEY (id);
alter table public.caisse_mouvements_audit add constraint caisse_mouvements_audit_pkey PRIMARY KEY (id);
alter table public.caisse_pins add constraint caisse_pins_pkey PRIMARY KEY (user_id);
alter table public.caisse_regles_ventilation add constraint caisse_regles_ventilation_pkey PRIMARY KEY (id);
alter table public.caisse_sessions add constraint caisse_sessions_pkey PRIMARY KEY (id);
alter table public.caisses add constraint caisses_pkey PRIMARY KEY (id);
alter table public.client_categories add constraint client_categories_pkey PRIMARY KEY (id);
alter table public.clients add constraint clients_pkey PRIMARY KEY (id);
alter table public.composants add constraint composants_pkey PRIMARY KEY (id);
alter table public.compta_comptes add constraint compta_comptes_pkey PRIMARY KEY (code);
alter table public.compta_ecritures add constraint compta_ecritures_pkey PRIMARY KEY (id);
alter table public.compta_exercices add constraint compta_exercices_pkey PRIMARY KEY (id);
alter table public.compta_journaux add constraint compta_journaux_pkey PRIMARY KEY (code);
alter table public.compta_lignes add constraint compta_lignes_pkey PRIMARY KEY (id);
alter table public.depots add constraint depots_pkey PRIMARY KEY (id);
alter table public.devis add constraint devis_pkey PRIMARY KEY (id);
alter table public.devis_categories add constraint devis_categories_pkey PRIMARY KEY (id);
alter table public.devis_lignes add constraint devis_lignes_pkey PRIMARY KEY (id);
alter table public.factures add constraint factures_pkey PRIMARY KEY (id);
alter table public.fiche_execution_lignes add constraint fiche_execution_lignes_pkey PRIMARY KEY (id);
alter table public.fiches_execution add constraint fiches_execution_pkey PRIMARY KEY (id);
alter table public.fournisseurs add constraint fournisseurs_pkey PRIMARY KEY (id);
alter table public.mouvements_stock add constraint mouvements_stock_pkey PRIMARY KEY (id);
alter table public.paiements add constraint paiements_pkey PRIMARY KEY (id);
alter table public.parametres add constraint parametres_pkey PRIMARY KEY (id);
alter table public.point_vente_affectations add constraint point_vente_affectations_pkey PRIMARY KEY (point_vente_id, user_id);
alter table public.points_vente add constraint points_vente_pkey PRIMARY KEY (id);
alter table public.produits add constraint produits_pkey PRIMARY KEY (id);
alter table public.profiles add constraint profiles_pkey PRIMARY KEY (id);
alter table public.projets add constraint projets_pkey PRIMARY KEY (id);
alter table public.prospects add constraint prospects_pkey PRIMARY KEY (id);
alter table public.realisations add constraint realisations_pkey PRIMARY KEY (id);
alter table public.stocks_depot add constraint stocks_depot_pkey PRIMARY KEY (depot_id, composant_id);
alter table public.transferts_stock add constraint transferts_stock_pkey PRIMARY KEY (id);
alter table public.transferts_stock_lignes add constraint transferts_stock_lignes_pkey PRIMARY KEY (id);
alter table public.ventes_comptoir add constraint ventes_comptoir_pkey PRIMARY KEY (id);
alter table public.ventes_comptoir_lignes add constraint ventes_comptoir_lignes_pkey PRIMARY KEY (id);
alter table public.client_categories add constraint client_categories_nom_key UNIQUE (nom);
alter table public.clients add constraint clients_code_key UNIQUE (code);
alter table public.composants add constraint composants_code_standing_key UNIQUE (code, standing);
alter table public.compta_ecritures add constraint compta_ecritures_ref_key UNIQUE (ref);
alter table public.compta_exercices add constraint compta_exercices_annee_key UNIQUE (annee);
alter table public.depots add constraint depots_code_key UNIQUE (code);
alter table public.devis add constraint devis_code_key UNIQUE (code);
alter table public.devis_categories add constraint devis_categories_nom_key UNIQUE (nom);
alter table public.factures add constraint factures_code_key UNIQUE (code);
alter table public.fiches_execution add constraint fiches_execution_code_key UNIQUE (code);
alter table public.fournisseurs add constraint fournisseurs_code_key UNIQUE (code);
alter table public.points_vente add constraint points_vente_code_key UNIQUE (code);
alter table public.projets add constraint projets_code_key UNIQUE (code);
alter table public.prospects add constraint prospects_code_key UNIQUE (code);
alter table public.transferts_stock add constraint transferts_stock_code_key UNIQUE (code);
alter table public.ventes_comptoir add constraint ventes_comptoir_code_key UNIQUE (code);
alter table public.caisse_mouvements add constraint caisse_mouvements_montant_check CHECK ((montant > (0)::numeric));
alter table public.caisse_mouvements add constraint caisse_mouvements_statut_check CHECK ((statut = ANY (ARRAY['a_ventiler'::text, 'ventile'::text])));
alter table public.caisse_mouvements add constraint caisse_mouvements_type_check CHECK ((type = ANY (ARRAY['entree'::text, 'sortie'::text])));
alter table public.caisse_mouvements_audit add constraint caisse_mouvements_audit_action_check CHECK ((action = ANY (ARRAY['modification'::text, 'suppression'::text])));
alter table public.caisse_sessions add constraint caisse_sessions_statut_check CHECK ((statut = ANY (ARRAY['ouverte'::text, 'cloturee'::text])));
alter table public.composants add constraint composants_standing_check CHECK ((standing = ANY (ARRAY['economique'::text, 'standard'::text, 'premium'::text])));
alter table public.composants add constraint composants_type_check CHECK ((type = ANY (ARRAY['Composant'::text, 'Consommable'::text])));
alter table public.composants add constraint composants_unite_check CHECK ((unite = ANY (ARRAY['unite'::text, 'ml'::text, 'm2'::text, 'kg'::text, 'litre'::text, 'boite'::text, 'cartouche'::text])));
alter table public.compta_comptes add constraint compta_comptes_classe_check CHECK (((classe >= 1) AND (classe <= 9)));
alter table public.compta_comptes add constraint compta_comptes_nature_check CHECK ((nature = ANY (ARRAY['actif'::text, 'passif'::text, 'charge'::text, 'produit'::text, 'autre'::text])));
alter table public.compta_ecritures add constraint compta_ecritures_source_check CHECK ((source = ANY (ARRAY['manuel'::text, 'auto'::text])));
alter table public.compta_exercices add constraint compta_exercices_statut_check CHECK ((statut = ANY (ARRAY['ouvert'::text, 'cloture'::text])));
alter table public.compta_lignes add constraint compta_lignes_montant_check CHECK ((montant > (0)::numeric));
alter table public.compta_lignes add constraint compta_lignes_sens_check CHECK ((sens = ANY (ARRAY['D'::text, 'C'::text])));
alter table public.compta_lignes add constraint compta_lignes_tiers_type_check CHECK ((tiers_type = ANY (ARRAY['client'::text, 'fournisseur'::text])));
alter table public.depots add constraint depots_type_check CHECK ((type = ANY (ARRAY['depot'::text, 'magasin'::text, 'atelier'::text, 'chantier'::text])));
alter table public.devis add constraint devis_statut_check CHECK ((statut = ANY (ARRAY['en_attente'::text, 'en_cours'::text, 'accepte'::text, 'refuse'::text, 'annule'::text])));
alter table public.factures add constraint factures_fne_statut_check CHECK ((fne_statut = ANY (ARRAY['certifiee'::text, 'provisoire'::text, 'echec'::text])));
alter table public.factures add constraint factures_statut_check CHECK ((statut = ANY (ARRAY['en_attente'::text, 'payee_partielle'::text, 'payee'::text, 'annulee'::text])));
alter table public.factures add constraint factures_type_facture_check CHECK ((type_facture = ANY (ARRAY['simple'::text, 'fne'::text])));
alter table public.fiches_execution add constraint fiches_execution_statut_check CHECK ((statut = ANY (ARRAY['en_attente'::text, 'en_cours'::text, 'termine'::text])));
alter table public.mouvements_stock add constraint mouvements_stock_type_check CHECK ((type = ANY (ARRAY['entree'::text, 'sortie'::text, 'ajustement'::text, 'inventaire'::text, 'transfert'::text])));
alter table public.paiements add constraint paiements_mode_check CHECK ((mode = ANY (ARRAY['espece'::text, 'banque'::text, 'mobile_money'::text, 'cheque'::text])));
alter table public.paiements add constraint paiements_montant_check CHECK ((montant > (0)::numeric));
alter table public.parametres add constraint parametres_fne_environnement_check CHECK ((fne_environnement = ANY (ARRAY['test'::text, 'production'::text])));
alter table public.parametres add constraint parametres_fne_taxe_defaut_check CHECK ((fne_taxe_defaut = ANY (ARRAY['TVA'::text, 'TVAB'::text, 'TVAC'::text, 'TVAD'::text])));
alter table public.produits add constraint produits_unite_check CHECK ((unite = ANY (ARRAY['m2'::text, 'ml'::text, 'unite'::text])));
alter table public.profiles add constraint profiles_role_check CHECK ((role = ANY (ARRAY['admin'::text, 'manager'::text, 'comptable'::text, 'caissier'::text, 'commercial'::text, 'technicien'::text, 'utilisateur'::text])));
alter table public.projets add constraint projets_etape_check CHECK ((etape = ANY (ARRAY['en_attente'::text, 'mesure_disponible'::text, 'pret_fabrication'::text, 'fabrication_en_cours'::text, 'installation_en_cours'::text, 'termine'::text, 'annule'::text])));
alter table public.prospects add constraint prospects_statut_check CHECK ((statut = ANY (ARRAY['nouveau'::text, 'contacte'::text, 'qualifie'::text, 'gagne'::text, 'perdu'::text])));
alter table public.transferts_stock add constraint transferts_stock_check CHECK ((depot_source_id <> depot_destination_id));
alter table public.transferts_stock add constraint transferts_stock_statut_check CHECK ((statut = ANY (ARRAY['brouillon'::text, 'en_transit'::text, 'recu'::text, 'annule'::text])));
alter table public.transferts_stock_lignes add constraint transferts_stock_lignes_quantite_envoyee_check CHECK ((quantite_envoyee > (0)::numeric));
alter table public.ventes_comptoir add constraint ventes_comptoir_fne_statut_check CHECK ((fne_statut = ANY (ARRAY['certifiee'::text, 'provisoire'::text, 'erreur'::text])));
alter table public.ventes_comptoir add constraint ventes_comptoir_mode_paiement_check CHECK ((mode_paiement = ANY (ARRAY['espece'::text, 'mobile_money'::text, 'banque'::text, 'cheque'::text])));
alter table public.ventes_comptoir add constraint ventes_comptoir_statut_check CHECK ((statut = ANY (ARRAY['validee'::text, 'annulee'::text])));
alter table public.ventes_comptoir_lignes add constraint ventes_comptoir_lignes_quantite_check CHECK ((quantite > (0)::numeric));
alter table public.caisse_affectations add constraint caisse_affectations_caisse_id_fkey FOREIGN KEY (caisse_id) REFERENCES caisses(id) ON DELETE CASCADE;
alter table public.caisse_affectations add constraint caisse_affectations_user_id_fkey FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;
alter table public.caisse_mouvements add constraint caisse_mouvements_caisse_id_fkey FOREIGN KEY (caisse_id) REFERENCES caisses(id) ON DELETE CASCADE;
alter table public.caisse_mouvements add constraint caisse_mouvements_compte_ventile_fkey FOREIGN KEY (compte_ventile) REFERENCES compta_comptes(code);
alter table public.caisse_mouvements add constraint caisse_mouvements_ecriture_id_fkey FOREIGN KEY (ecriture_id) REFERENCES compta_ecritures(id) ON DELETE SET NULL;
alter table public.caisse_mouvements add constraint caisse_mouvements_session_id_fkey FOREIGN KEY (session_id) REFERENCES caisse_sessions(id) ON DELETE CASCADE;
alter table public.caisse_pins add constraint caisse_pins_user_id_fkey FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;
alter table public.caisse_regles_ventilation add constraint caisse_regles_ventilation_compte_code_fkey FOREIGN KEY (compte_code) REFERENCES compta_comptes(code);
alter table public.caisse_sessions add constraint caisse_sessions_caisse_id_fkey FOREIGN KEY (caisse_id) REFERENCES caisses(id) ON DELETE CASCADE;
alter table public.caisse_sessions add constraint caisse_sessions_cloturee_par_id_fkey FOREIGN KEY (cloturee_par_id) REFERENCES profiles(id) ON DELETE SET NULL;
alter table public.caisse_sessions add constraint caisse_sessions_ecart_ecriture_id_fkey FOREIGN KEY (ecart_ecriture_id) REFERENCES compta_ecritures(id) ON DELETE SET NULL;
alter table public.caisse_sessions add constraint caisse_sessions_ouverte_par_id_fkey FOREIGN KEY (ouverte_par_id) REFERENCES profiles(id) ON DELETE SET NULL;
alter table public.caisses add constraint caisses_compte_code_fkey FOREIGN KEY (compte_code) REFERENCES compta_comptes(code);
alter table public.caisses add constraint caisses_projet_id_fkey FOREIGN KEY (projet_id) REFERENCES projets(id) ON DELETE SET NULL;
alter table public.clients add constraint clients_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);
alter table public.composants add constraint composants_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);
alter table public.compta_ecritures add constraint compta_ecritures_contre_passation_de_fkey FOREIGN KEY (contre_passation_de) REFERENCES compta_ecritures(id) ON DELETE SET NULL;
alter table public.compta_ecritures add constraint compta_ecritures_journal_code_fkey FOREIGN KEY (journal_code) REFERENCES compta_journaux(code);
alter table public.compta_ecritures add constraint compta_ecritures_projet_id_fkey FOREIGN KEY (projet_id) REFERENCES projets(id) ON DELETE SET NULL;
alter table public.compta_lignes add constraint compta_lignes_compte_code_fkey FOREIGN KEY (compte_code) REFERENCES compta_comptes(code);
alter table public.compta_lignes add constraint compta_lignes_ecriture_id_fkey FOREIGN KEY (ecriture_id) REFERENCES compta_ecritures(id) ON DELETE CASCADE;
alter table public.devis add constraint devis_client_id_fkey FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE RESTRICT;
alter table public.devis add constraint devis_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);
alter table public.devis add constraint devis_projet_id_fkey FOREIGN KEY (projet_id) REFERENCES projets(id) ON DELETE SET NULL;
alter table public.devis add constraint devis_racine_id_fkey FOREIGN KEY (racine_id) REFERENCES devis(id);
alter table public.devis_lignes add constraint devis_lignes_composant_id_fkey FOREIGN KEY (composant_id) REFERENCES composants(id) ON DELETE SET NULL;
alter table public.devis_lignes add constraint devis_lignes_devis_id_fkey FOREIGN KEY (devis_id) REFERENCES devis(id) ON DELETE CASCADE;
alter table public.devis_lignes add constraint devis_lignes_produit_id_fkey FOREIGN KEY (produit_id) REFERENCES produits(id) ON DELETE SET NULL;
alter table public.factures add constraint factures_client_id_fkey FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE RESTRICT;
alter table public.factures add constraint factures_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);
alter table public.factures add constraint factures_devis_id_fkey FOREIGN KEY (devis_id) REFERENCES devis(id) ON DELETE SET NULL;
alter table public.fiche_execution_lignes add constraint fiche_execution_lignes_devis_ligne_id_fkey FOREIGN KEY (devis_ligne_id) REFERENCES devis_lignes(id) ON DELETE SET NULL;
alter table public.fiche_execution_lignes add constraint fiche_execution_lignes_fiche_id_fkey FOREIGN KEY (fiche_id) REFERENCES fiches_execution(id) ON DELETE CASCADE;
alter table public.fiches_execution add constraint fiches_execution_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);
alter table public.fiches_execution add constraint fiches_execution_devis_id_fkey FOREIGN KEY (devis_id) REFERENCES devis(id) ON DELETE CASCADE;
alter table public.fiches_execution add constraint fiches_execution_fabrication_lancee_par_fkey FOREIGN KEY (fabrication_lancee_par) REFERENCES auth.users(id);
alter table public.fiches_execution add constraint fiches_execution_mesure_prise_par_fkey FOREIGN KEY (mesure_prise_par) REFERENCES auth.users(id);
alter table public.fiches_execution add constraint fiches_execution_projet_id_fkey FOREIGN KEY (projet_id) REFERENCES projets(id) ON DELETE SET NULL;
alter table public.fournisseurs add constraint fournisseurs_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);
alter table public.mouvements_stock add constraint mouvements_stock_composant_id_fkey FOREIGN KEY (composant_id) REFERENCES composants(id) ON DELETE CASCADE;
alter table public.mouvements_stock add constraint mouvements_stock_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);
alter table public.mouvements_stock add constraint mouvements_stock_depot_id_fkey FOREIGN KEY (depot_id) REFERENCES depots(id) ON DELETE RESTRICT;
alter table public.mouvements_stock add constraint mouvements_stock_transfert_id_fkey FOREIGN KEY (transfert_id) REFERENCES transferts_stock(id) ON DELETE SET NULL;
alter table public.paiements add constraint paiements_caisse_id_fkey FOREIGN KEY (caisse_id) REFERENCES caisses(id) ON DELETE SET NULL;
alter table public.paiements add constraint paiements_ecriture_id_fkey FOREIGN KEY (ecriture_id) REFERENCES compta_ecritures(id) ON DELETE SET NULL;
alter table public.paiements add constraint paiements_facture_id_fkey FOREIGN KEY (facture_id) REFERENCES factures(id) ON DELETE CASCADE;
alter table public.point_vente_affectations add constraint point_vente_affectations_point_vente_id_fkey FOREIGN KEY (point_vente_id) REFERENCES points_vente(id) ON DELETE CASCADE;
alter table public.point_vente_affectations add constraint point_vente_affectations_user_id_fkey FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;
alter table public.points_vente add constraint points_vente_caisse_id_fkey FOREIGN KEY (caisse_id) REFERENCES caisses(id) ON DELETE SET NULL;
alter table public.points_vente add constraint points_vente_depot_id_fkey FOREIGN KEY (depot_id) REFERENCES depots(id) ON DELETE RESTRICT;
alter table public.profiles add constraint profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public.projets add constraint projets_client_id_fkey FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE SET NULL;
alter table public.projets add constraint projets_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);
alter table public.prospects add constraint prospects_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);
alter table public.realisations add constraint realisations_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);
alter table public.stocks_depot add constraint stocks_depot_composant_id_fkey FOREIGN KEY (composant_id) REFERENCES composants(id) ON DELETE CASCADE;
alter table public.stocks_depot add constraint stocks_depot_depot_id_fkey FOREIGN KEY (depot_id) REFERENCES depots(id) ON DELETE RESTRICT;
alter table public.transferts_stock add constraint transferts_stock_depot_destination_id_fkey FOREIGN KEY (depot_destination_id) REFERENCES depots(id) ON DELETE RESTRICT;
alter table public.transferts_stock add constraint transferts_stock_depot_source_id_fkey FOREIGN KEY (depot_source_id) REFERENCES depots(id) ON DELETE RESTRICT;
alter table public.transferts_stock_lignes add constraint transferts_stock_lignes_composant_id_fkey FOREIGN KEY (composant_id) REFERENCES composants(id) ON DELETE RESTRICT;
alter table public.transferts_stock_lignes add constraint transferts_stock_lignes_transfert_id_fkey FOREIGN KEY (transfert_id) REFERENCES transferts_stock(id) ON DELETE CASCADE;
alter table public.ventes_comptoir add constraint ventes_comptoir_caisse_id_fkey FOREIGN KEY (caisse_id) REFERENCES caisses(id) ON DELETE SET NULL;
alter table public.ventes_comptoir add constraint ventes_comptoir_client_id_fkey FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE SET NULL;
alter table public.ventes_comptoir add constraint ventes_comptoir_depot_id_fkey FOREIGN KEY (depot_id) REFERENCES depots(id) ON DELETE SET NULL;
alter table public.ventes_comptoir add constraint ventes_comptoir_ecriture_id_fkey FOREIGN KEY (ecriture_id) REFERENCES compta_ecritures(id) ON DELETE SET NULL;
alter table public.ventes_comptoir add constraint ventes_comptoir_point_vente_id_fkey FOREIGN KEY (point_vente_id) REFERENCES points_vente(id) ON DELETE SET NULL;
alter table public.ventes_comptoir_lignes add constraint ventes_comptoir_lignes_composant_id_fkey FOREIGN KEY (composant_id) REFERENCES composants(id) ON DELETE SET NULL;
alter table public.ventes_comptoir_lignes add constraint ventes_comptoir_lignes_vente_id_fkey FOREIGN KEY (vente_id) REFERENCES ventes_comptoir(id) ON DELETE CASCADE;

CREATE INDEX idx_caisse_mvt_caisse ON public.caisse_mouvements USING btree (caisse_id);
CREATE INDEX idx_caisse_mvt_session ON public.caisse_mouvements USING btree (session_id);
CREATE INDEX idx_caisse_mvt_statut ON public.caisse_mouvements USING btree (statut);
CREATE INDEX idx_caisse_audit_mvt ON public.caisse_mouvements_audit USING btree (mouvement_id);
CREATE INDEX idx_caisse_sessions_caisse ON public.caisse_sessions USING btree (caisse_id);
CREATE INDEX clients_nom_idx ON public.clients USING btree (nom);
CREATE INDEX idx_compta_ecritures_date ON public.compta_ecritures USING btree (date_ecriture);
CREATE INDEX idx_compta_ecritures_exercice ON public.compta_ecritures USING btree (exercice_annee);
CREATE INDEX idx_compta_ecritures_journal ON public.compta_ecritures USING btree (journal_code);
CREATE INDEX idx_compta_ecritures_source ON public.compta_ecritures USING btree (source_type, source_id);
CREATE INDEX idx_compta_lignes_compte ON public.compta_lignes USING btree (compte_code);
CREATE INDEX idx_compta_lignes_ecriture ON public.compta_lignes USING btree (ecriture_id);
CREATE UNIQUE INDEX depots_un_seul_principal ON public.depots USING btree (est_principal) WHERE est_principal;
CREATE INDEX devis_client_id_idx ON public.devis USING btree (client_id);
CREATE INDEX devis_projet_id_idx ON public.devis USING btree (projet_id);
CREATE INDEX idx_devis_is_current ON public.devis USING btree (is_current);
CREATE INDEX idx_devis_racine ON public.devis USING btree (racine_id);
CREATE INDEX devis_lignes_composant_id_idx ON public.devis_lignes USING btree (composant_id);
CREATE INDEX devis_lignes_devis_id_idx ON public.devis_lignes USING btree (devis_id);
CREATE INDEX factures_client_id_idx ON public.factures USING btree (client_id);
CREATE INDEX factures_devis_id_idx ON public.factures USING btree (devis_id);
CREATE INDEX fiche_execution_lignes_fiche_id_idx ON public.fiche_execution_lignes USING btree (fiche_id);
CREATE INDEX fiches_execution_devis_id_idx ON public.fiches_execution USING btree (devis_id);
CREATE INDEX fournisseurs_nom_idx ON public.fournisseurs USING btree (nom);
CREATE INDEX mouvements_stock_composant_id_idx ON public.mouvements_stock USING btree (composant_id);
CREATE INDEX mouvements_stock_created_at_idx ON public.mouvements_stock USING btree (created_at);
CREATE INDEX idx_paiements_facture ON public.paiements USING btree (facture_id);
CREATE UNIQUE INDEX pva_un_defaut_par_user ON public.point_vente_affectations USING btree (user_id) WHERE par_defaut;
CREATE INDEX projets_client_id_idx ON public.projets USING btree (client_id);
CREATE INDEX projets_etape_idx ON public.projets USING btree (etape);
CREATE INDEX prospects_nom_idx ON public.prospects USING btree (nom);
CREATE INDEX idx_realisations_ordre ON public.realisations USING btree (ordre);
CREATE INDEX idx_stocks_depot_composant ON public.stocks_depot USING btree (composant_id);
CREATE INDEX idx_transferts_lignes_transfert ON public.transferts_stock_lignes USING btree (transfert_id);
CREATE INDEX idx_ventes_comptoir_date ON public.ventes_comptoir USING btree (date_vente);
CREATE INDEX idx_ventes_comptoir_lignes_vente ON public.ventes_comptoir_lignes USING btree (vente_id);

-- ---------------------------------------------------------------------------
-- 3. Fonctions
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.bump_fiche_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  update fiches_execution set updated_at = now() where id = coalesce(new.fiche_id, old.fiche_id);
  return coalesce(new, old);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.devis_set_racine_id()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF NEW.racine_id IS NULL THEN
    NEW.racine_id := NEW.id;
  END IF;
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  insert into public.profiles (id, nom_complet)
  values (new.id, coalesce(new.raw_user_meta_data->>'nom_complet', new.email));
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.portail_lookup(p_code text, p_telephone text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_client clients%ROWTYPE;
  v_result jsonb;
  v_digits text := regexp_replace(coalesce(p_telephone,''), '\D', '', 'g');
  v_actif boolean;
BEGIN
  SELECT portail_actif INTO v_actif FROM parametres LIMIT 1;
  IF NOT coalesce(v_actif,false) THEN
    RETURN jsonb_build_object('found', false, 'disabled', true);
  END IF;

  SELECT * INTO v_client
  FROM clients
  WHERE upper(trim(code)) = upper(trim(coalesce(p_code,'')))
    AND regexp_replace(coalesce(telephone,''), '\D', '', 'g') <> ''
    AND right(regexp_replace(coalesce(telephone,''), '\D', '', 'g'), 8) = right(v_digits, 8)
  LIMIT 1;

  IF v_client.id IS NULL THEN
    RETURN jsonb_build_object('found', false);
  END IF;

  SELECT jsonb_build_object(
    'found', true,
    'client', jsonb_build_object(
      'code', v_client.code, 'nom', v_client.nom, 'prenoms', v_client.prenoms,
      'civilite', v_client.civilite, 'entreprise', v_client.entreprise,
      'commune', v_client.commune
    ),
    'projets', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
        'code', pr.code, 'libelle', pr.libelle, 'etape', pr.etape,
        'date_debut', pr.date_debut, 'date_fin', pr.date_fin, 'commune', pr.commune
      ) ORDER BY pr.created_at DESC)
      FROM projets pr WHERE pr.client_id = v_client.id
    ), '[]'::jsonb),
    'devis', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
        'code', d.code, 'libelle', d.libelle, 'statut', d.statut,
        'total', d.total, 'date_creation', d.date_creation
      ) ORDER BY d.created_at DESC)
      FROM devis d WHERE d.client_id = v_client.id
    ), '[]'::jsonb),
    'factures', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
        'code', f.code, 'statut', f.statut, 'total', f.total,
        'date_facture', f.date_facture, 'type_facture', f.type_facture
      ) ORDER BY f.created_at DESC)
      FROM factures f WHERE f.client_id = v_client.id
    ), '[]'::jsonb)
  ) INTO v_result;

  RETURN v_result;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.set_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  new.updated_at = now();
  return new;
end;
$function$
;

create or replace function public.ventes_comptoir_set_code() returns trigger
language plpgsql set search_path = public as $$
declare n int; an text := to_char(coalesce(new.date_vente, current_date), 'YYYY');
begin
  if new.code is null then
    perform pg_advisory_xact_lock(hashtext('ventes_comptoir_code_' || an));
    select coalesce(max(nullif(split_part(code, '-', 3), '')::int), 0) + 1 into n
      from ventes_comptoir where code like 'VC-' || an || '-%';
    new.code := 'VC-' || an || '-' || lpad(n::text, 5, '0');
  end if;
  return new;
end $$;

create or replace function public.vente_comptoir_valider(p_vente jsonb, p_lignes jsonb)
returns ventes_comptoir
language plpgsql set search_path = public as $$
declare v ventes_comptoir; l jsonb; i int := 0; v_depot uuid;
begin
  if jsonb_array_length(coalesce(p_lignes, '[]'::jsonb)) = 0 then
    raise exception 'Le panier est vide';
  end if;
  v_depot := coalesce(nullif(p_vente->>'depot_id','')::uuid,
                      (select depot_id from points_vente where id = nullif(p_vente->>'point_vente_id','')::uuid),
                      (select id from depots where est_principal limit 1));
  insert into ventes_comptoir (date_vente, client_id, client_nom, client_telephone, sous_total, remise, total, cout_total,
      mode_paiement, montant_recu, monnaie_rendue, reference_paiement, caisse_id, vendeur, created_by, point_vente_id, depot_id)
    values (coalesce((p_vente->>'date_vente')::date, current_date), nullif(p_vente->>'client_id','')::uuid,
      p_vente->>'client_nom', p_vente->>'client_telephone',
      coalesce((p_vente->>'sous_total')::numeric,0), coalesce((p_vente->>'remise')::numeric,0),
      coalesce((p_vente->>'total')::numeric,0), coalesce((p_vente->>'cout_total')::numeric,0),
      coalesce(p_vente->>'mode_paiement','espece'), (p_vente->>'montant_recu')::numeric, (p_vente->>'monnaie_rendue')::numeric,
      p_vente->>'reference_paiement', nullif(p_vente->>'caisse_id','')::uuid, p_vente->>'vendeur', auth.uid(),
      nullif(p_vente->>'point_vente_id','')::uuid, v_depot)
    returning * into v;
  for l in select * from jsonb_array_elements(p_lignes) loop
    insert into ventes_comptoir_lignes (vente_id, composant_id, designation, unite, quantite, prix_unitaire, prix_achat, remise_pct, total, ordre)
      values (v.id, nullif(l->>'composant_id','')::uuid, l->>'designation', l->>'unite', (l->>'quantite')::numeric,
        coalesce((l->>'prix_unitaire')::numeric,0), coalesce((l->>'prix_achat')::numeric,0),
        coalesce((l->>'remise_pct')::numeric,0), coalesce((l->>'total')::numeric,0), i);
    if nullif(l->>'composant_id','') is not null then
      perform stock_mouvement((l->>'composant_id')::uuid, 'sortie', (l->>'quantite')::numeric, 'Vente au comptoir', v.code, null, v_depot, null);
    end if;
    i := i + 1;
  end loop;
  return v;
end $$;

create or replace function public.vente_comptoir_annuler(p_vente_id uuid, p_motif text, p_par text)
returns ventes_comptoir
language plpgsql set search_path = public as $$
declare v ventes_comptoir; l ventes_comptoir_lignes;
begin
  select * into v from ventes_comptoir where id = p_vente_id for update;
  if v.id is null then raise exception 'Vente introuvable'; end if;
  if v.statut = 'annulee' then raise exception 'Vente déjà annulée'; end if;
  for l in select * from ventes_comptoir_lignes where vente_id = p_vente_id loop
    if l.composant_id is not null then
      perform stock_mouvement(l.composant_id, 'ajustement', l.quantite, 'Annulation vente au comptoir', v.code, null, v.depot_id, null);
    end if;
  end loop;
  update ventes_comptoir set statut = 'annulee', motif_annulation = p_motif, annulee_le = now(), annulee_par = p_par
    where id = p_vente_id returning * into v;
  return v;
end $$;

create or replace function public.transferts_stock_set_code() returns trigger
language plpgsql set search_path = public as $$
declare n int; an text := to_char(now(), 'YYYY');
begin
  if new.code is null then
    perform pg_advisory_xact_lock(hashtext('transferts_stock_code_' || an));
    select coalesce(max(nullif(split_part(code, '-', 3), '')::int), 0) + 1 into n
      from transferts_stock where code like 'TR-' || an || '-%';
    new.code := 'TR-' || an || '-' || lpad(n::text, 5, '0');
  end if;
  return new;
end $$;

create or replace function public.stock_mouvement(p_composant_id uuid, p_type text, p_quantite numeric,
  p_motif text default null, p_reference text default null, p_prix_unitaire numeric default null,
  p_depot_id uuid default null, p_transfert_id uuid default null)
returns composants
language plpgsql set search_path = public as $$
declare
  v_comp composants%rowtype;
  v_depot uuid;
  v_qte_depot numeric;
  v_delta numeric;
  v_new_cmup numeric;
begin
  if p_type not in ('entree','sortie','ajustement','inventaire','transfert') then
    raise exception 'Type de mouvement invalide: %', p_type;
  end if;
  v_depot := coalesce(p_depot_id, (select id from depots where est_principal limit 1));
  if v_depot is null then raise exception 'Aucun dépôt principal défini'; end if;

  select * into v_comp from composants where id = p_composant_id for update;
  if v_comp.id is null then raise exception 'Composant introuvable'; end if;

  insert into stocks_depot(depot_id, composant_id, quantite) values (v_depot, p_composant_id, 0)
    on conflict (depot_id, composant_id) do nothing;
  select quantite into v_qte_depot from stocks_depot where depot_id = v_depot and composant_id = p_composant_id for update;

  v_new_cmup := coalesce(v_comp.cmup, 0);
  if p_type = 'entree' then
    if p_quantite <= 0 then raise exception 'Quantité entrée doit être positive'; end if;
    v_delta := p_quantite;
    if p_prix_unitaire is not null and (v_comp.stock_actuel + p_quantite) > 0 then
      v_new_cmup := ((v_comp.stock_actuel * coalesce(v_comp.cmup,0)) + (p_quantite * p_prix_unitaire))
                    / (v_comp.stock_actuel + p_quantite);
    else
      v_new_cmup := coalesce(v_comp.cmup, p_prix_unitaire, 0);
    end if;
  elsif p_type = 'sortie' then
    if p_quantite <= 0 then raise exception 'Quantité sortie doit être positive'; end if;
    v_delta := -p_quantite;
  elsif p_type in ('ajustement','transfert') then
    v_delta := p_quantite;
  elsif p_type = 'inventaire' then
    v_delta := p_quantite - v_qte_depot;
  end if;

  update stocks_depot set quantite = quantite + v_delta where depot_id = v_depot and composant_id = p_composant_id;
  update composants set stock_actuel = stock_actuel + v_delta, cmup = v_new_cmup where id = p_composant_id
    returning * into v_comp;

  insert into mouvements_stock (composant_id, type, quantite, prix_unitaire, stock_apres, cmup_apres, motif, reference,
                                created_by, depot_id, transfert_id, stock_depot_apres)
    values (p_composant_id, p_type, v_delta, p_prix_unitaire, v_comp.stock_actuel, v_new_cmup, p_motif, p_reference,
            auth.uid(), v_depot, p_transfert_id, v_qte_depot + v_delta);
  return v_comp;
end $$;

create or replace function public.transfert_expedier(p_transfert_id uuid, p_par text)
returns transferts_stock
language plpgsql set search_path = public as $$
declare t transferts_stock; l record; v_dispo numeric; n int := 0;
begin
  select * into t from transferts_stock where id = p_transfert_id for update;
  if t.id is null then raise exception 'Transfert introuvable'; end if;
  if t.statut <> 'brouillon' then raise exception 'Seul un transfert en brouillon peut être expédié'; end if;
  for l in select tl.*, c.nom, c.cmup as c_cmup from transferts_stock_lignes tl join composants c on c.id = tl.composant_id
           where tl.transfert_id = t.id order by tl.ordre loop
    select coalesce(quantite,0) into v_dispo from stocks_depot where depot_id = t.depot_source_id and composant_id = l.composant_id;
    if coalesce(v_dispo,0) < l.quantite_envoyee then
      raise exception 'Stock insuffisant au dépôt source pour « % » : disponible %, demandé %', l.nom, coalesce(v_dispo,0), l.quantite_envoyee;
    end if;
    perform stock_mouvement(l.composant_id, 'transfert', -l.quantite_envoyee, 'Transfert expédié', t.code, null, t.depot_source_id, t.id);
    update transferts_stock_lignes set cmup = l.c_cmup where id = l.id;
    n := n + 1;
  end loop;
  if n = 0 then raise exception 'Le transfert ne contient aucune ligne'; end if;
  update transferts_stock set statut = 'en_transit', date_expedition = now(), expedie_par = p_par
    where id = t.id returning * into t;
  return t;
end $$;

create or replace function public.transfert_receptionner(p_transfert_id uuid, p_lignes jsonb, p_notes text, p_par text)
returns transferts_stock
language plpgsql set search_path = public as $$
declare t transferts_stock; l transferts_stock_lignes; v_recu numeric;
begin
  select * into t from transferts_stock where id = p_transfert_id for update;
  if t.id is null then raise exception 'Transfert introuvable'; end if;
  if t.statut <> 'en_transit' then raise exception 'Seul un transfert en transit peut être réceptionné'; end if;
  for l in select * from transferts_stock_lignes where transfert_id = t.id order by ordre loop
    select (e->>'quantite_recue')::numeric into v_recu from jsonb_array_elements(coalesce(p_lignes,'[]'::jsonb)) e
      where e->>'id' = l.id::text limit 1;
    v_recu := coalesce(v_recu, l.quantite_envoyee);
    if v_recu < 0 then raise exception 'Quantité reçue négative'; end if;
    if v_recu > 0 then
      perform stock_mouvement(l.composant_id, 'transfert', v_recu,
        case when v_recu < l.quantite_envoyee then 'Transfert reçu (écart ' || (l.quantite_envoyee - v_recu) || ')' else 'Transfert reçu' end,
        t.code, null, t.depot_destination_id, t.id);
    end if;
    update transferts_stock_lignes set quantite_recue = v_recu where id = l.id;
  end loop;
  update transferts_stock set statut = 'recu', date_reception = now(), recu_par = p_par, notes_reception = p_notes
    where id = t.id returning * into t;
  return t;
end $$;

create or replace function public.transfert_annuler(p_transfert_id uuid, p_par text)
returns transferts_stock
language plpgsql set search_path = public as $$
declare t transferts_stock; l transferts_stock_lignes;
begin
  select * into t from transferts_stock where id = p_transfert_id for update;
  if t.id is null then raise exception 'Transfert introuvable'; end if;
  if t.statut not in ('brouillon','en_transit') then raise exception 'Ce transfert ne peut plus être annulé'; end if;
  if t.statut = 'en_transit' then
    for l in select * from transferts_stock_lignes where transfert_id = t.id loop
      perform stock_mouvement(l.composant_id, 'transfert', l.quantite_envoyee, 'Transfert annulé — retour', t.code, null, t.depot_source_id, t.id);
    end loop;
  end if;
  update transferts_stock set statut = 'annule', annule_par = p_par where id = t.id returning * into t;
  return t;
end $$;

create or replace function public.mon_role_code() returns text
language plpgsql stable security definer set search_path = public as $$
declare r text;
begin
  -- Module Utilisateurs & Rôles (sql/utilisateurs_roles.sql) prioritaire s'il est installé
  if to_regclass('public.roles') is not null then
    begin
      execute 'select r.code from profiles p join roles r on r.id = p.role_id where p.id = auth.uid()' into r;
    exception when undefined_column then r := null;
    end;
  end if;
  if r is null then select role into r from profiles where id = auth.uid(); end if;
  return r;
end $$;

create or replace function public.est_gestionnaire_caisse() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(public.mon_role_code() in ('admin','manager'), false);
$$;

create or replace function public.profiles_proteger_role() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    -- Le tout premier compte devient administrateur (« Première connexion ») ; les suivants sont
    -- créés « utilisateur » (sauf création par un administrateur), un administrateur leur attribue ensuite un rôle.
    if not exists (select 1 from profiles where role = 'admin') then new.role := 'admin';
    elsif coalesce(public.mon_role_code(),'') <> 'admin' then new.role := 'utilisateur';
    end if;
  elsif new.role is distinct from old.role and auth.uid() is not null
        and coalesce(public.mon_role_code(),'') <> 'admin' then
    raise exception 'Seul un administrateur peut modifier un rôle';
  elsif new.role is distinct from old.role and old.role = 'admin' and new.role <> 'admin'
        and (select count(*) from profiles where role = 'admin') <= 1 then
    raise exception 'Impossible de retirer le dernier administrateur';
  end if;
  return new;
end $$;

create or replace function public.peut_utiliser_caisse(p_caisse_id uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select public.est_gestionnaire_caisse()
      or not exists (select 1 from caisse_affectations where caisse_id = p_caisse_id)
      or exists (select 1 from caisse_affectations where caisse_id = p_caisse_id and user_id = auth.uid());
$$;

create or replace function public.peut_utiliser_point_vente(p_pdv_id uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select public.est_gestionnaire_caisse()
      or not exists (select 1 from point_vente_affectations where point_vente_id = p_pdv_id)
      or exists (select 1 from point_vente_affectations where point_vente_id = p_pdv_id and user_id = auth.uid());
$$;

create or replace function public.definir_pin_caisse(p_user_id uuid, p_pin text) returns void
language plpgsql security definer set search_path = public, extensions as $$
begin
  if not public.est_gestionnaire_caisse() then raise exception 'Réservé aux gestionnaires (admin, manager)'; end if;
  if p_pin !~ '^[0-9]{4}$' then raise exception 'Le code PIN doit comporter exactement 4 chiffres'; end if;
  insert into caisse_pins(user_id, pin_hash, echecs, bloque_jusqu, defini_par, updated_at)
    values (p_user_id, crypt(p_pin, gen_salt('bf')), 0, null, auth.uid(), now())
    on conflict (user_id) do update set pin_hash = excluded.pin_hash, echecs = 0, bloque_jusqu = null,
      defini_par = excluded.defini_par, updated_at = now();
end $$;

create or replace function public.supprimer_pin_caisse(p_user_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.est_gestionnaire_caisse() then raise exception 'Réservé aux gestionnaires (admin, manager)'; end if;
  delete from caisse_pins where user_id = p_user_id;
end $$;

create or replace function public.verifier_pin_caisse(p_pin text) returns boolean
language plpgsql security definer set search_path = public, extensions as $$
declare p caisse_pins;
begin
  select * into p from caisse_pins where user_id = auth.uid() for update;
  if p.user_id is null then return true; end if;                       -- pas de PIN configuré : pas de blocage
  if p.bloque_jusqu is not null and p.bloque_jusqu > now() then
    raise exception 'Code PIN bloqué après trop d''essais — réessayez après %', to_char(p.bloque_jusqu at time zone 'Africa/Abidjan','HH24:MI');
  end if;
  if coalesce(p_pin,'') <> '' and crypt(p_pin, p.pin_hash) = p.pin_hash then
    update caisse_pins set echecs = 0, bloque_jusqu = null where user_id = auth.uid();
    return true;
  end if;
  update caisse_pins set echecs = echecs + 1,
    bloque_jusqu = case when echecs + 1 >= 5 then now() + interval '10 minutes' else null end
    where user_id = auth.uid();
  return false;
end $$;

create or replace function public.modifier_mon_pin_caisse(p_ancien text, p_nouveau text) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
begin
  if p_nouveau !~ '^[0-9]{4}$' then return jsonb_build_object('ok',false,'message','Le code PIN doit comporter exactement 4 chiffres'); end if;
  if not exists (select 1 from caisse_pins where user_id = auth.uid()) then
    return jsonb_build_object('ok',false,'message','Aucun code PIN ne vous est attribué — demandez-le à un gestionnaire');
  end if;
  if not public.verifier_pin_caisse(p_ancien) then return jsonb_build_object('ok',false,'message','Ancien code PIN incorrect'); end if;
  update caisse_pins set pin_hash = crypt(p_nouveau, gen_salt('bf')), updated_at = now() where user_id = auth.uid();
  return jsonb_build_object('ok',true);
end $$;

create or replace function public.etat_pins_caisse()
returns table(user_id uuid, a_un_pin boolean, bloque_jusqu timestamptz, echecs int, updated_at timestamptz)
language sql stable security definer set search_path = public as $$
  select p.id, cp.user_id is not null, cp.bloque_jusqu, coalesce(cp.echecs,0), cp.updated_at
  from profiles p left join caisse_pins cp on cp.user_id = p.id
  where public.est_gestionnaire_caisse() or p.id = auth.uid();
$$;

create or replace function public.caisse_ouvrir_session(p_caisse_id uuid, p_fond numeric, p_pin text)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare s caisse_sessions; v_nom text; v_restants int;
begin
  if auth.uid() is null then raise exception 'Non authentifié'; end if;
  if not public.peut_utiliser_caisse(p_caisse_id) then raise exception 'Vous n''êtes pas affecté(e) à cette caisse'; end if;
  if not public.verifier_pin_caisse(p_pin) then
    select greatest(0, 5 - echecs) into v_restants from caisse_pins where user_id = auth.uid();
    return jsonb_build_object('ok',false,'message',
      case when v_restants = 0 then 'Code PIN incorrect — bloqué pendant 10 minutes'
           else 'Code PIN incorrect (' || v_restants || ' essai(s) restant(s))' end);
  end if;
  perform 1 from caisses where id = p_caisse_id for update;
  if exists (select 1 from caisse_sessions where caisse_id = p_caisse_id and statut = 'ouverte') then
    return jsonb_build_object('ok',false,'message','Une séance est déjà ouverte pour cette caisse');
  end if;
  select coalesce(nom_complet, id::text) into v_nom from profiles where id = auth.uid();
  insert into caisse_sessions(caisse_id, date_session, fond_ouverture, statut, ouverte_par, ouverte_par_id)
    values (p_caisse_id, (now() at time zone 'Africa/Abidjan')::date, coalesce(p_fond,0), 'ouverte',
            coalesce((select email from auth.users where id = auth.uid()), v_nom), auth.uid())
    returning * into s;
  return jsonb_build_object('ok',true,'session',to_jsonb(s));
end $$;

create or replace function public.vente_comptoir_controle_affectation() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then return new; end if;
  if new.point_vente_id is not null and not public.peut_utiliser_point_vente(new.point_vente_id) then
    raise exception 'Vous n''êtes pas affecté(e) à ce point de vente';
  end if;
  if new.caisse_id is not null and not public.peut_utiliser_caisse(new.caisse_id) then
    raise exception 'Vous n''êtes pas affecté(e) à cette caisse';
  end if;
  return new;
end $$;

-- ---------------------------------------------------------------------------
-- 4. Déclencheurs
-- ---------------------------------------------------------------------------
CREATE TRIGGER trg_devis_set_racine_id BEFORE INSERT ON public.devis FOR EACH ROW EXECUTE FUNCTION devis_set_racine_id();
CREATE TRIGGER fiche_lignes_bump_updated_at AFTER UPDATE ON public.fiche_execution_lignes FOR EACH ROW EXECUTE FUNCTION bump_fiche_updated_at();
CREATE TRIGGER fiches_execution_set_updated_at BEFORE UPDATE ON public.fiches_execution FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER parametres_set_updated_at BEFORE UPDATE ON public.parametres FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_profiles_proteger_role BEFORE INSERT OR UPDATE OF role ON public.profiles FOR EACH ROW EXECUTE FUNCTION profiles_proteger_role();
CREATE TRIGGER trg_transferts_stock_code BEFORE INSERT ON public.transferts_stock FOR EACH ROW EXECUTE FUNCTION transferts_stock_set_code();
CREATE TRIGGER trg_vente_comptoir_affectation BEFORE INSERT ON public.ventes_comptoir FOR EACH ROW EXECUTE FUNCTION vente_comptoir_controle_affectation();
CREATE TRIGGER trg_ventes_comptoir_code BEFORE INSERT ON public.ventes_comptoir FOR EACH ROW EXECUTE FUNCTION ventes_comptoir_set_code();
-- Création automatique du profil à l'inscription (le premier compte devient administrateur)
drop trigger if exists on_auth_user_created on auth.users;
CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ---------------------------------------------------------------------------
-- 5. Sécurité : RLS et politiques d'accès
-- ---------------------------------------------------------------------------
alter table public.caisse_affectations enable row level security;
alter table public.caisse_mouvements enable row level security;
alter table public.caisse_mouvements_audit enable row level security;
alter table public.caisse_pins enable row level security;
alter table public.caisse_regles_ventilation enable row level security;
alter table public.caisse_sessions enable row level security;
alter table public.caisses enable row level security;
alter table public.client_categories enable row level security;
alter table public.clients enable row level security;
alter table public.composants enable row level security;
alter table public.compta_comptes enable row level security;
alter table public.compta_ecritures enable row level security;
alter table public.compta_exercices enable row level security;
alter table public.compta_journaux enable row level security;
alter table public.compta_lignes enable row level security;
alter table public.depots enable row level security;
alter table public.devis enable row level security;
alter table public.devis_categories enable row level security;
alter table public.devis_lignes enable row level security;
alter table public.factures enable row level security;
alter table public.fiche_execution_lignes enable row level security;
alter table public.fiches_execution enable row level security;
alter table public.fournisseurs enable row level security;
alter table public.mouvements_stock enable row level security;
alter table public.paiements enable row level security;
alter table public.parametres enable row level security;
alter table public.point_vente_affectations enable row level security;
alter table public.points_vente enable row level security;
alter table public.produits enable row level security;
alter table public.profiles enable row level security;
alter table public.projets enable row level security;
alter table public.prospects enable row level security;
alter table public.realisations enable row level security;
alter table public.stocks_depot enable row level security;
alter table public.transferts_stock enable row level security;
alter table public.transferts_stock_lignes enable row level security;
alter table public.ventes_comptoir enable row level security;
alter table public.ventes_comptoir_lignes enable row level security;
-- caisse_pins : RLS sans aucune politique (codes PIN accessibles uniquement via les fonctions)

create policy affect_caisse_gestion on public.caisse_affectations as permissive for all to public using (est_gestionnaire_caisse()) with check (est_gestionnaire_caisse());
create policy affect_caisse_lecture on public.caisse_affectations as permissive for select to public using ((auth.role() = 'authenticated'::text));
create policy authenticated_all_caisse_mouvements on public.caisse_mouvements as permissive for all to public using ((auth.role() = 'authenticated'::text)) with check ((auth.role() = 'authenticated'::text));
create policy mouvements_saisie_affectes on public.caisse_mouvements as restrictive for insert to public with check ((peut_utiliser_caisse(caisse_id) OR ((transfert_id IS NOT NULL) AND (type = 'entree'::text))));
create policy audit_caisse_insert on public.caisse_mouvements_audit as permissive for insert to authenticated with check (true);
create policy audit_caisse_select on public.caisse_mouvements_audit as permissive for select to authenticated using (true);
create policy authenticated_all_caisse_regles_ventilation on public.caisse_regles_ventilation as permissive for all to public using ((auth.role() = 'authenticated'::text)) with check ((auth.role() = 'authenticated'::text));
create policy authenticated_all_caisse_sessions on public.caisse_sessions as permissive for all to public using ((auth.role() = 'authenticated'::text)) with check ((auth.role() = 'authenticated'::text));
create policy sessions_modif_affectes on public.caisse_sessions as restrictive for update to public using (peut_utiliser_caisse(caisse_id)) with check (peut_utiliser_caisse(caisse_id));
create policy sessions_ouverture_via_rpc on public.caisse_sessions as restrictive for insert to public with check (est_gestionnaire_caisse());
create policy authenticated_all_caisses on public.caisses as permissive for all to public using ((auth.role() = 'authenticated'::text)) with check ((auth.role() = 'authenticated'::text));
create policy authenticated_full_access on public.client_categories as permissive for all to public using ((auth.role() = 'authenticated'::text)) with check ((auth.role() = 'authenticated'::text));
create policy authenticated_full_access on public.clients as permissive for all to public using ((auth.role() = 'authenticated'::text)) with check ((auth.role() = 'authenticated'::text));
create policy authenticated_full_access on public.composants as permissive for all to public using ((auth.role() = 'authenticated'::text)) with check ((auth.role() = 'authenticated'::text));
create policy authenticated_all_compta_comptes on public.compta_comptes as permissive for all to public using ((auth.role() = 'authenticated'::text)) with check ((auth.role() = 'authenticated'::text));
create policy authenticated_all_compta_ecritures on public.compta_ecritures as permissive for all to public using ((auth.role() = 'authenticated'::text)) with check ((auth.role() = 'authenticated'::text));
create policy authenticated_all_compta_exercices on public.compta_exercices as permissive for all to public using ((auth.role() = 'authenticated'::text)) with check ((auth.role() = 'authenticated'::text));
create policy authenticated_all_compta_journaux on public.compta_journaux as permissive for all to public using ((auth.role() = 'authenticated'::text)) with check ((auth.role() = 'authenticated'::text));
create policy authenticated_all_compta_lignes on public.compta_lignes as permissive for all to public using ((auth.role() = 'authenticated'::text)) with check ((auth.role() = 'authenticated'::text));
create policy authenticated_all_depots on public.depots as permissive for all to public using ((auth.role() = 'authenticated'::text)) with check ((auth.role() = 'authenticated'::text));
create policy authenticated_full_access on public.devis as permissive for all to public using ((auth.role() = 'authenticated'::text)) with check ((auth.role() = 'authenticated'::text));
create policy authenticated_full_access on public.devis_categories as permissive for all to public using ((auth.role() = 'authenticated'::text)) with check ((auth.role() = 'authenticated'::text));
create policy authenticated_full_access on public.devis_lignes as permissive for all to public using ((auth.role() = 'authenticated'::text)) with check ((auth.role() = 'authenticated'::text));
create policy authenticated_full_access on public.factures as permissive for all to public using ((auth.role() = 'authenticated'::text)) with check ((auth.role() = 'authenticated'::text));
create policy authenticated_full_access on public.fiche_execution_lignes as permissive for all to public using ((auth.role() = 'authenticated'::text)) with check ((auth.role() = 'authenticated'::text));
create policy authenticated_full_access on public.fiches_execution as permissive for all to public using ((auth.role() = 'authenticated'::text)) with check ((auth.role() = 'authenticated'::text));
create policy authenticated_full_access on public.fournisseurs as permissive for all to public using ((auth.role() = 'authenticated'::text)) with check ((auth.role() = 'authenticated'::text));
create policy authenticated_full_access on public.mouvements_stock as permissive for all to public using ((auth.role() = 'authenticated'::text)) with check ((auth.role() = 'authenticated'::text));
create policy authenticated_all_paiements on public.paiements as permissive for all to public using ((auth.role() = 'authenticated'::text)) with check ((auth.role() = 'authenticated'::text));
create policy authenticated_full_access on public.parametres as permissive for all to public using ((auth.role() = 'authenticated'::text)) with check ((auth.role() = 'authenticated'::text));
create policy affect_pdv_gestion on public.point_vente_affectations as permissive for all to public using (est_gestionnaire_caisse()) with check (est_gestionnaire_caisse());
create policy affect_pdv_lecture on public.point_vente_affectations as permissive for select to public using ((auth.role() = 'authenticated'::text));
create policy authenticated_all_points_vente on public.points_vente as permissive for all to public using ((auth.role() = 'authenticated'::text)) with check ((auth.role() = 'authenticated'::text));
create policy authenticated_full_access on public.produits as permissive for all to public using ((auth.role() = 'authenticated'::text)) with check ((auth.role() = 'authenticated'::text));
create policy profiles_authenticated_select on public.profiles as permissive for select to public using ((auth.role() = 'authenticated'::text));
create policy profiles_self_insert on public.profiles as permissive for insert to public with check ((auth.uid() = id));
create policy profiles_self_select on public.profiles as permissive for select to public using ((auth.uid() = id));
create policy profiles_self_update on public.profiles as permissive for update to public using ((auth.uid() = id));
create policy authenticated_full_access on public.projets as permissive for all to public using ((auth.role() = 'authenticated'::text)) with check ((auth.role() = 'authenticated'::text));
create policy authenticated_full_access on public.prospects as permissive for all to public using ((auth.role() = 'authenticated'::text)) with check ((auth.role() = 'authenticated'::text));
create policy authenticated_full_access on public.realisations as permissive for all to public using ((auth.role() = 'authenticated'::text)) with check ((auth.role() = 'authenticated'::text));
create policy authenticated_all_stocks_depot on public.stocks_depot as permissive for all to public using ((auth.role() = 'authenticated'::text)) with check ((auth.role() = 'authenticated'::text));
create policy authenticated_all_transferts_stock on public.transferts_stock as permissive for all to public using ((auth.role() = 'authenticated'::text)) with check ((auth.role() = 'authenticated'::text));
create policy authenticated_all_transferts_stock_lignes on public.transferts_stock_lignes as permissive for all to public using ((auth.role() = 'authenticated'::text)) with check ((auth.role() = 'authenticated'::text));
create policy authenticated_all_ventes_comptoir on public.ventes_comptoir as permissive for all to public using ((auth.role() = 'authenticated'::text)) with check ((auth.role() = 'authenticated'::text));
create policy authenticated_all_ventes_comptoir_lignes on public.ventes_comptoir_lignes as permissive for all to public using ((auth.role() = 'authenticated'::text)) with check ((auth.role() = 'authenticated'::text));

-- Fonctions sensibles : réservées aux utilisateurs connectés ; portail client : accessible au public (anon)
revoke execute on function public.definir_pin_caisse(uuid,text), public.supprimer_pin_caisse(uuid),
  public.verifier_pin_caisse(text), public.modifier_mon_pin_caisse(text,text), public.etat_pins_caisse(),
  public.caisse_ouvrir_session(uuid,numeric,text), public.portail_lookup(text,text) from public;
revoke execute on function public.definir_pin_caisse(uuid,text), public.supprimer_pin_caisse(uuid),
  public.verifier_pin_caisse(text), public.modifier_mon_pin_caisse(text,text), public.etat_pins_caisse(),
  public.caisse_ouvrir_session(uuid,numeric,text) from anon;
grant execute on function public.definir_pin_caisse(uuid,text), public.supprimer_pin_caisse(uuid),
  public.verifier_pin_caisse(text), public.modifier_mon_pin_caisse(text,text), public.etat_pins_caisse(),
  public.caisse_ouvrir_session(uuid,numeric,text) to authenticated;
grant execute on function public.portail_lookup(text,text) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 6. Données de départ (référentiels génériques — aucune donnée d'entreprise)
-- ---------------------------------------------------------------------------
insert into public.compta_journaux (code, libelle) values
  ('AC', 'Journal des Achats'),
  ('AN', 'Journal des À-Nouveaux'),
  ('BQ', 'Journal de Banque'),
  ('CA', 'Journal de Caisse'),
  ('CLO', 'Journal de Clôture'),
  ('MM', 'Journal Mobile Money'),
  ('OD', 'Journal des Opérations Diverses'),
  ('VE', 'Journal des Ventes')
on conflict (code) do nothing;

-- Plan comptable SYSCOHADA de base (adaptable dans Comptabilité → Plan comptable)
insert into public.compta_comptes (code, libelle, classe, nature) values
  ('101000', 'Capital social', 1, 'passif'),
  ('106000', 'Réserves', 1, 'passif'),
  ('110000', 'Report à nouveau créditeur', 1, 'passif'),
  ('120000', 'Résultat net de l''exercice (bénéfice)', 1, 'passif'),
  ('129000', 'Résultat net de l''exercice (perte)', 1, 'passif'),
  ('162000', 'Emprunts auprès des établissements de crédit', 1, 'passif'),
  ('168000', 'Autres emprunts et dettes assimilées', 1, 'passif'),
  ('213000', 'Logiciels et sites internet', 2, 'actif'),
  ('222000', 'Terrains', 2, 'actif'),
  ('231000', 'Bâtiments industriels et administratifs', 2, 'actif'),
  ('241000', 'Matériel et outillage industriel (atelier)', 2, 'actif'),
  ('244000', 'Matériel et mobilier de bureau', 2, 'actif'),
  ('245000', 'Matériel de transport', 2, 'actif'),
  ('281300', 'Amortissements des logiciels', 2, 'actif'),
  ('283100', 'Amortissements des bâtiments', 2, 'actif'),
  ('284100', 'Amortissements du matériel et outillage industriel', 2, 'actif'),
  ('284500', 'Amortissements du matériel de transport', 2, 'actif'),
  ('321000', 'Matières premières — Profilés aluminium', 3, 'actif'),
  ('322000', 'Matières premières — Vitrage', 3, 'actif'),
  ('323000', 'Fournitures liées — Quincaillerie & accessoires', 3, 'actif'),
  ('331000', 'Autres approvisionnements — Consommables', 3, 'actif'),
  ('401000', 'Fournisseurs', 4, 'passif'),
  ('408000', 'Fournisseurs — Factures non parvenues', 4, 'passif'),
  ('409000', 'Fournisseurs débiteurs — Avances et acomptes versés', 4, 'actif'),
  ('411000', 'Clients', 4, 'actif'),
  ('416000', 'Clients douteux ou litigieux', 4, 'actif'),
  ('418000', 'Clients — Factures à établir', 4, 'actif'),
  ('419000', 'Clients créditeurs — Avances et acomptes reçus', 4, 'passif'),
  ('421000', 'Personnel — Rémunérations dues', 4, 'passif'),
  ('422000', 'Personnel — Avances et acomptes', 4, 'actif'),
  ('431000', 'Sécurité sociale (CNPS)', 4, 'passif'),
  ('441000', 'État — Impôt sur les bénéfices', 4, 'passif'),
  ('443000', 'État — TVA facturée (collectée)', 4, 'passif'),
  ('444100', 'État — TVA à décaisser', 4, 'passif'),
  ('444900', 'État — Crédit de TVA à reporter', 4, 'actif'),
  ('445000', 'État — TVA récupérable', 4, 'actif'),
  ('447000', 'État — Autres impôts et taxes', 4, 'passif'),
  ('512000', 'Banques', 5, 'actif'),
  ('571000', 'Caisse principale', 5, 'actif'),
  ('572000', 'Caisses secondaires (chantiers)', 5, 'actif'),
  ('585000', 'Virements internes (entre caisses / banque)', 5, 'autre'),
  ('601000', 'Achats de matières premières — Aluminium', 6, 'charge'),
  ('602000', 'Achats de fournitures liées — Vitrage, quincaillerie', 6, 'charge'),
  ('605000', 'Autres achats (emballages, divers)', 6, 'charge'),
  ('614000', 'Transports sur achats et livraisons', 6, 'charge'),
  ('621000', 'Sous-traitance générale', 6, 'charge'),
  ('622000', 'Locations', 6, 'charge'),
  ('624000', 'Entretien, réparations et maintenance', 6, 'charge'),
  ('625000', 'Primes d''assurance', 6, 'charge'),
  ('627000', 'Publicité, publications, relations publiques', 6, 'charge'),
  ('628000', 'Autres charges externes', 6, 'charge'),
  ('631000', 'Frais bancaires', 6, 'charge'),
  ('633000', 'Frais de formation du personnel', 6, 'charge'),
  ('638000', 'Autres charges externes diverses', 6, 'charge'),
  ('641000', 'Impôts et taxes directs', 6, 'charge'),
  ('658000', 'Charges diverses', 6, 'charge'),
  ('661000', 'Rémunérations directes du personnel', 6, 'charge'),
  ('664000', 'Charges sociales (CNPS)', 6, 'charge'),
  ('668000', 'Autres charges de personnel', 6, 'charge'),
  ('671000', 'Intérêts des emprunts', 6, 'charge'),
  ('678000', 'Autres charges financières', 6, 'charge'),
  ('681000', 'Dotations aux amortissements des immobilisations', 6, 'charge'),
  ('701000', 'Ventes d''ouvrages menuiserie aluminium', 7, 'produit'),
  ('706000', 'Prestations de services (pose, installation)', 7, 'produit'),
  ('758000', 'Produits divers', 7, 'produit'),
  ('771000', 'Intérêts et produits financiers', 7, 'produit'),
  ('891000', 'Impôts sur le résultat', 8, 'charge')
on conflict (code) do nothing;

-- Exercice comptable de l'année en cours
insert into public.compta_exercices (annee, date_debut, date_fin, statut)
  select y, make_date(y,1,1), make_date(y,12,31), 'ouvert'
  from (select extract(year from now())::int as y) a
on conflict (annee) do nothing;

-- Structure minimale : dépôt principal, caisse principale, point de vente (renommables dans l'application)
insert into public.depots (code, nom, type, est_principal)
  select 'DEP-01', 'Dépôt principal', 'depot', true where not exists (select 1 from public.depots);
insert into public.caisses (nom, compte_code)
  select 'Caisse principale', '571000' where not exists (select 1 from public.caisses);
insert into public.points_vente (code, nom, depot_id, caisse_id)
  select 'PDV-01', 'Comptoir principal', (select id from public.depots where est_principal),
         (select id from public.caisses order by created_at limit 1)
  where not exists (select 1 from public.points_vente);

-- Paramètres vierges : raison sociale, logo, TVA, FNE, conditions… à renseigner dans Paramètres → Entreprise
insert into public.parametres (raison_sociale) select '' where not exists (select 1 from public.parametres);

-- Catalogue technique du Configurateur d'ouvrage (codes utilisés pour le calcul des débits / BOM).
-- PRIX INDICATIFS en FCFA : à ajuster par la structure (Composants → Catalogue).
insert into public.composants (code, standing, nom, type, famille, unite, prix_unitaire) values
  ('BAR-GI-001', 'standard', 'Barreau vertical inox Ø12mm', 'Composant', 'Profilé aluminium', 'ml', 8200),
  ('BRO-001', 'standard', 'Joint brosse étanchéité', 'Consommable', 'Joint & étanchéité', 'ml', 1100),
  ('CAB-GI-001', 'standard', 'Câble inox Ø6mm tendu', 'Composant', 'Quincaillerie', 'ml', 4.5),
  ('CAD-FJ-001', 'standard', 'Cadre dormant jalousie', 'Composant', 'Profilé aluminium', 'ml', 8500),
  ('CAD-FJ-002', 'standard', 'Montant dormant jalousie', 'Composant', 'Profilé aluminium', 'ml', 8500),
  ('CAD-MO-001', 'standard', 'Cadre aluminium moustiquaire', 'Composant', 'Profilé aluminium', 'ml', 3800),
  ('CAD-MO-002', 'standard', 'Traverse aluminium moustiquaire', 'Composant', 'Profilé aluminium', 'ml', 3800),
  ('CAI-001', 'standard', 'Caisson de galandage', 'Composant', 'Profilé aluminium', 'ml', 14500),
  ('CLI-FJ-001', 'standard', 'Clip de fixation lame', 'Composant', 'Quincaillerie', 'unite', 350),
  ('CON-001', 'standard', 'Silicone', 'Consommable', 'Consommable atelier', 'cartouche', 2800),
  ('JNT-001', 'standard', 'Joint vitrage', 'Consommable', 'Joint & étanchéité', 'ml', 900),
  ('JNT-ABT-001', 'standard', 'Aboutage 90° + vis', 'Composant', 'Visserie & fixations', 'unite', 900),
  ('JNT-EQ-001', 'standard', 'Équerre d''angle mécanique', 'Composant', 'Visserie & fixations', 'unite', 1200),
  ('JNT-ONG-001', 'standard', 'Jonction onglet 45° (colle+sertissage)', 'Composant', 'Visserie & fixations', 'unite', 1500),
  ('LAM-FJ-001', 'standard', 'Lame de verre jalousie 5mm', 'Composant', 'Vitrage', 'm2', 4800),
  ('LOQ-MO-001', 'standard', 'Loquet de fermeture', 'Composant', 'Quincaillerie', 'unite', 1200),
  ('MC-GI-001', 'standard', 'Main courante inox', 'Composant', 'Profilé aluminium', 'ml', 16800),
  ('MEC-FJ-001', 'standard', 'Mécanisme à manivelle', 'Composant', 'Quincaillerie', 'unite', 6500),
  ('P-PAR-001', 'standard', 'Parclose', 'Composant', 'Profilé aluminium', 'ml', 3200),
  ('P-SEU-001', 'standard', 'Seuil bas renforcé', 'Composant', 'Profilé aluminium', 'ml', 11500),
  ('P-STD-001', 'standard', 'Dormant horizontal', 'Composant', 'Profilé aluminium', 'ml', 8500),
  ('P-STD-002', 'standard', 'Dormant vertical', 'Composant', 'Profilé aluminium', 'ml', 8500),
  ('P-STD-003', 'standard', 'Ouvrant horizontal', 'Composant', 'Profilé aluminium', 'ml', 9200),
  ('P-STD-004', 'standard', 'Ouvrant vertical', 'Composant', 'Profilé aluminium', 'ml', 9200),
  ('PIN-GI-001', 'standard', 'Pince de fixation verre inox', 'Composant', 'Quincaillerie', 'unite', 2400),
  ('PLA-GI-001', 'standard', 'Platine fixation inox', 'Composant', 'Quincaillerie', 'unite', 3800),
  ('POT-GI-001', 'standard', 'Poteau inox tube 42.4mm', 'Composant', 'Profilé aluminium', 'ml', 22500),
  ('QUI-001', 'standard', 'Poignée', 'Composant', 'Quincaillerie', 'unite', 4500),
  ('QUI-001-PORTE', 'standard', 'Ensemble serrure + poignée', 'Composant', 'Quincaillerie', 'unite', 12500),
  ('QUI-002', 'standard', 'Paumelle', 'Composant', 'Quincaillerie', 'unite', 850),
  ('QUI-002-GALANDAGE', 'standard', 'Roulette renforcée galandage', 'Composant', 'Quincaillerie', 'unite', 2100),
  ('QUI-002-PORTE', 'standard', 'Paumelle renforcée', 'Composant', 'Quincaillerie', 'unite', 1600),
  ('QUI-003', 'standard', 'Gâche + ferme-porte', 'Composant', 'Quincaillerie', 'unite', 7800),
  ('RAI-MO-001', 'standard', 'Rail coulissant moustiquaire', 'Composant', 'Profilé aluminium', 'ml', 4200),
  ('RAIL-001', 'standard', 'Rail double renforcé galandage', 'Composant', 'Profilé aluminium', 'ml', 12800),
  ('ROU-MO-001', 'standard', 'Roulette coulissante', 'Composant', 'Quincaillerie', 'unite', 950),
  ('SAN-001', 'standard', 'Sangle de finition caisson', 'Composant', 'Visserie & fixations', 'ml', 3500),
  ('TEN-GI-001', 'standard', 'Tendeur + terminaison sertie', 'Composant', 'Quincaillerie', 'unite', 1800),
  ('TUL-MO-001', 'standard', 'Toile moustiquaire (fibre de verre)', 'Consommable', 'Vitrage', 'm2', 3200),
  ('VIT-001', 'standard', 'Double vitrage 6/12/6', 'Composant', 'Vitrage', 'm2', 6500),
  ('VIT-GI-001', 'standard', 'Verre feuilleté sécurit', 'Composant', 'Vitrage', 'm2', 9500)
on conflict (code, standing) do nothing;

reset check_function_bodies;

-- ===========================================================================
-- 7. Utilisateurs, rôles et droits par module (copie de sql/utilisateurs_roles.sql)
-- ===========================================================================
-- ============================================================================
-- Sanix AluExpert ERP — Module Utilisateurs, Rôles & Accès (à l'image de ImmoSuite)
-- ============================================================================
-- À exécuter dans l'éditeur SQL Supabase, APRÈS sql/comptabilite_syscohada.sql
-- et sql/parametres_comptes_defaut.sql. Additif : crée 3 nouvelles tables
-- (roles, role_permissions, invitations) et ajoute 2 colonnes à `profiles`
-- (déjà existante). Aucune table existante n'est modifiée en profondeur.
--
-- Modèle : chaque rôle porte, pour chaque module de l'application, 5 droits
-- indépendants (voir/créer/modifier/supprimer/valider). Contrairement à
-- ImmoSuite (où l'absence de restriction sur un module = tout autorisé),
-- ici chaque couple (rôle, module) a une ligne explicite dans
-- role_permissions — pas de valeur implicite, pour éviter les angles morts
-- de sécurité. Règle absolue conservée d'ImmoSuite : seuls les rôles
-- « admin » et « manager » peuvent supprimer, même si un rôle personnalisé
-- coche « supprimer » sur un module (contrôlée côté application).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Rôles
-- ----------------------------------------------------------------------------
create table if not exists roles (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  label text not null,
  icon text not null default '👤',
  niveau int not null default 1,
  est_systeme boolean not null default false,
  peut_supprimer boolean not null default true,
  plafond_validation numeric(14,2),
  description text,
  created_at timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- 2. Permissions par rôle et par module
-- ----------------------------------------------------------------------------
create table if not exists role_permissions (
  role_id uuid not null references roles(id) on delete cascade,
  module_code text not null,
  peut_voir boolean not null default false,
  peut_creer boolean not null default false,
  peut_modifier boolean not null default false,
  peut_supprimer boolean not null default false,
  peut_valider boolean not null default false,
  primary key (role_id, module_code)
);

-- ----------------------------------------------------------------------------
-- 3. Invitations (l'application n'a pas d'API admin Supabase côté client : on ne
--    peut pas créer un compte auth pour quelqu'un d'autre. Une invitation
--    pré-attribue un rôle à un email ; quand cette personne s'inscrit via
--    l'écran de connexion existant, le rôle lui est attribué automatiquement)
-- ----------------------------------------------------------------------------
create table if not exists invitations (
  id uuid primary key default gen_random_uuid(),
  email text unique not null,
  role_id uuid not null references roles(id),
  statut text not null default 'en_attente' check (statut in ('en_attente','acceptee')),
  invited_by uuid,
  created_at timestamptz not null default now(),
  accepted_at timestamptz
);

-- ----------------------------------------------------------------------------
-- 4. Rattachement d'un rôle et d'un statut actif/inactif à chaque profil
-- ----------------------------------------------------------------------------
alter table profiles add column if not exists role_id uuid references roles(id);
alter table profiles add column if not exists actif boolean not null default true;
-- `profiles` n'avait pas de colonne email (l'email vit dans auth.users, non
-- lisible par le client). On la duplique ici pour l'affichage dans l'écran
-- Utilisateurs et le rapprochement des invitations ; elle se renseigne toute
-- seule à la prochaine connexion de chaque utilisateur (voir index.html).
alter table profiles add column if not exists email text;

-- ----------------------------------------------------------------------------
-- 5. Sécurité — RLS + garde-fou anti élévation de privilège
-- ----------------------------------------------------------------------------
alter table roles enable row level security;
alter table role_permissions enable row level security;
alter table invitations enable row level security;

create or replace function public.is_admin() returns boolean
language sql stable as $$
  select exists(
    select 1 from profiles p join roles r on r.id = p.role_id
    where p.id = auth.uid() and r.code = 'admin'
  );
$$;

drop policy if exists "roles_select" on roles;
create policy "roles_select" on roles for select using (auth.role() = 'authenticated');
drop policy if exists "roles_insert_admin" on roles;
create policy "roles_insert_admin" on roles for insert with check (public.is_admin());
drop policy if exists "roles_update_admin" on roles;
create policy "roles_update_admin" on roles for update using (public.is_admin()) with check (public.is_admin());
drop policy if exists "roles_delete_admin" on roles;
create policy "roles_delete_admin" on roles for delete using (public.is_admin());

drop policy if exists "role_permissions_select" on role_permissions;
create policy "role_permissions_select" on role_permissions for select using (auth.role() = 'authenticated');
drop policy if exists "role_permissions_insert_admin" on role_permissions;
create policy "role_permissions_insert_admin" on role_permissions for insert with check (public.is_admin());
drop policy if exists "role_permissions_update_admin" on role_permissions;
create policy "role_permissions_update_admin" on role_permissions for update using (public.is_admin()) with check (public.is_admin());
drop policy if exists "role_permissions_delete_admin" on role_permissions;
create policy "role_permissions_delete_admin" on role_permissions for delete using (public.is_admin());

drop policy if exists "invitations_select" on invitations;
create policy "invitations_select" on invitations for select using (public.is_admin() or email = (auth.jwt()->>'email'));
drop policy if exists "invitations_insert_admin" on invitations;
create policy "invitations_insert_admin" on invitations for insert with check (public.is_admin());
drop policy if exists "invitations_update" on invitations;
create policy "invitations_update" on invitations for update
  using (public.is_admin() or email = (auth.jwt()->>'email'))
  with check (public.is_admin() or email = (auth.jwt()->>'email'));
drop policy if exists "invitations_delete_admin" on invitations;
create policy "invitations_delete_admin" on invitations for delete using (public.is_admin());

-- Garde-fou indépendant de la policy RLS existante sur `profiles` (que cette
-- migration ne connaît pas et ne modifie pas) : quel que soit ce que cette
-- policy autorise déjà, ce trigger empêche un utilisateur non-admin de
-- modifier son propre rôle ou son statut actif une fois qu'un rôle lui a
-- déjà été attribué. Exception nécessaire : un profil qui n'a PAS encore de
-- rôle (role_id IS NULL, cas d'une inscription qui vient d'avoir lieu) peut
-- recevoir son rôle initial — c'est ce qui permet à l'inscription et au
-- mécanisme d'invitation de fonctionner sans intervention manuelle.
create or replace function public.proteger_role_profil() returns trigger
language plpgsql as $$
declare
  appelant_admin boolean;
begin
  if new.role_id is distinct from old.role_id or new.actif is distinct from old.actif then
    select public.is_admin() into appelant_admin;
    if not appelant_admin and old.role_id is not null then
      new.role_id := old.role_id;
      new.actif := old.actif;
    end if;
  end if;
  return new;
end;
$$;
drop trigger if exists trg_proteger_role_profil on profiles;
create trigger trg_proteger_role_profil before update on profiles
for each row execute function public.proteger_role_profil();

-- ----------------------------------------------------------------------------
-- 6. Rôles système + matrice de permissions par défaut
-- ----------------------------------------------------------------------------
do $$
declare
  rid uuid;
  m text;
  tous_modules text[] := array['Clients','Prospects','Fournisseurs','Projets','Devis','Factures',
                                'FichesExecution','Produits','Composants','Stock','Comptabilite',
                                'Caisse','Comptoir','Realisations','Utilisateurs','Parametres'];
begin
  -- ADMINISTRATEUR : accès total, y compris Utilisateurs et Paramètres
  insert into roles(code,label,icon,niveau,est_systeme,peut_supprimer,plafond_validation,description)
    values ('admin','Administrateur','👑',4,true,true,null,'Accès complet à tous les modules, y compris Utilisateurs et Paramètres.')
    on conflict (code) do nothing;
  select id into rid from roles where code='admin';
  foreach m in array tous_modules loop
    insert into role_permissions(role_id,module_code,peut_voir,peut_creer,peut_modifier,peut_supprimer,peut_valider)
      values (rid,m,true,true,true,true,true) on conflict (role_id,module_code) do nothing;
  end loop;

  -- MANAGER : tout sauf Comptabilité, Utilisateurs, Paramètres
  insert into roles(code,label,icon,niveau,est_systeme,peut_supprimer,plafond_validation,description)
    values ('manager','Manager','🧭',3,true,true,null,'Gestion opérationnelle complète (commercial, chantiers, stock) — sans accès à la Comptabilité ni aux Paramètres.')
    on conflict (code) do nothing;
  select id into rid from roles where code='manager';
  foreach m in array tous_modules loop
    if m in ('Comptabilite','Utilisateurs','Parametres') then
      insert into role_permissions(role_id,module_code,peut_voir,peut_creer,peut_modifier,peut_supprimer,peut_valider)
        values (rid,m,false,false,false,false,false) on conflict (role_id,module_code) do nothing;
    else
      insert into role_permissions(role_id,module_code,peut_voir,peut_creer,peut_modifier,peut_supprimer,peut_valider)
        values (rid,m,true,true,true,true,true) on conflict (role_id,module_code) do nothing;
    end if;
  end loop;

  -- COMPTABLE : Comptabilité/Caisse/Factures/Fournisseurs en création-modif (pas suppression),
  -- consultation sur le reste, aucun accès à Utilisateurs/Paramètres/Prospects
  insert into roles(code,label,icon,niveau,est_systeme,peut_supprimer,plafond_validation,description)
    values ('comptable','Comptable','📗',2,true,false,1000000,'Comptabilité SYSCOHADA, Caisse, Factures et Fournisseurs — sans droit de suppression.')
    on conflict (code) do nothing;
  select id into rid from roles where code='comptable';
  foreach m in array tous_modules loop
    if m in ('Comptabilite','Caisse','Factures','Fournisseurs') then
      insert into role_permissions(role_id,module_code,peut_voir,peut_creer,peut_modifier,peut_supprimer,peut_valider)
        values (rid,m,true,true,true,false,true) on conflict (role_id,module_code) do nothing;
    elsif m in ('Clients','Devis','Projets','Stock','Produits','Composants','Realisations','FichesExecution','Comptoir') then
      insert into role_permissions(role_id,module_code,peut_voir,peut_creer,peut_modifier,peut_supprimer,peut_valider)
        values (rid,m,true,false,false,false,false) on conflict (role_id,module_code) do nothing;
    else
      insert into role_permissions(role_id,module_code,peut_voir,peut_creer,peut_modifier,peut_supprimer,peut_valider)
        values (rid,m,false,false,false,false,false) on conflict (role_id,module_code) do nothing;
    end if;
  end loop;

  -- COMMERCIAL : Clients/Prospects/Devis en création-modif, consultation sur le reste du cycle de vente
  insert into roles(code,label,icon,niveau,est_systeme,peut_supprimer,plafond_validation,description)
    values ('commercial','Commercial','🤝',1,true,false,null,'Clients, prospects et devis — sans droit de suppression, sans accès à la Comptabilité ni à la Caisse.')
    on conflict (code) do nothing;
  select id into rid from roles where code='commercial';
  foreach m in array tous_modules loop
    if m in ('Clients','Prospects','Devis','Realisations','Comptoir') then
      insert into role_permissions(role_id,module_code,peut_voir,peut_creer,peut_modifier,peut_supprimer,peut_valider)
        values (rid,m,true,true,true,false,true) on conflict (role_id,module_code) do nothing;
    elsif m in ('Projets','FichesExecution','Produits','Composants','Stock','Factures') then
      insert into role_permissions(role_id,module_code,peut_voir,peut_creer,peut_modifier,peut_supprimer,peut_valider)
        values (rid,m,true,false,false,false,false) on conflict (role_id,module_code) do nothing;
    else
      insert into role_permissions(role_id,module_code,peut_voir,peut_creer,peut_modifier,peut_supprimer,peut_valider)
        values (rid,m,false,false,false,false,false) on conflict (role_id,module_code) do nothing;
    end if;
  end loop;

  -- CAISSIÈRE : Caisse en création-modif uniquement (ni suppression, ni validation —
  -- ségrégation des tâches), simple consultation de la Comptabilité
  insert into roles(code,label,icon,niveau,est_systeme,peut_supprimer,plafond_validation,description)
    values ('caissiere','Caissier(ère)','💰',1,true,false,100000,'Bons d''entrée/sortie de caisse — sans suppression ni validation, pour la ségrégation des tâches.')
    on conflict (code) do nothing;
  select id into rid from roles where code='caissiere';
  foreach m in array tous_modules loop
    if m in ('Caisse','Comptoir') then
      insert into role_permissions(role_id,module_code,peut_voir,peut_creer,peut_modifier,peut_supprimer,peut_valider)
        values (rid,m,true,true,true,false,false) on conflict (role_id,module_code) do nothing;
    elsif m='Comptabilite' then
      insert into role_permissions(role_id,module_code,peut_voir,peut_creer,peut_modifier,peut_supprimer,peut_valider)
        values (rid,m,true,false,false,false,false) on conflict (role_id,module_code) do nothing;
    else
      insert into role_permissions(role_id,module_code,peut_voir,peut_creer,peut_modifier,peut_supprimer,peut_valider)
        values (rid,m,false,false,false,false,false) on conflict (role_id,module_code) do nothing;
    end if;
  end loop;

  -- COMMISSAIRE (auditeur externe) : consultation seule sur tous les modules financiers/métier
  insert into roles(code,label,icon,niveau,est_systeme,peut_supprimer,plafond_validation,description)
    values ('commissaire','Commissaire aux comptes','🔍',1,true,false,0,'Consultation uniquement — aucune création, modification, suppression ou validation.')
    on conflict (code) do nothing;
  select id into rid from roles where code='commissaire';
  foreach m in array tous_modules loop
    if m in ('Utilisateurs','Parametres') then
      insert into role_permissions(role_id,module_code,peut_voir,peut_creer,peut_modifier,peut_supprimer,peut_valider)
        values (rid,m,false,false,false,false,false) on conflict (role_id,module_code) do nothing;
    else
      insert into role_permissions(role_id,module_code,peut_voir,peut_creer,peut_modifier,peut_supprimer,peut_valider)
        values (rid,m,true,false,false,false,false) on conflict (role_id,module_code) do nothing;
    end if;
  end loop;

  -- SANS RÔLE : aucun accès — attribué par défaut à toute inscription sans invitation
  -- lorsqu'un compte administrateur existe déjà (empêche un inconnu de s'auto-attribuer
  -- un accès en s'inscrivant sur l'écran de connexion public)
  insert into roles(code,label,icon,niveau,est_systeme,peut_supprimer,plafond_validation,description)
    values ('sans_role','Sans rôle (en attente)','🚫',0,true,false,0,'Compte créé sans invitation : aucun accès tant qu''un administrateur n''attribue un rôle.')
    on conflict (code) do nothing;
  select id into rid from roles where code='sans_role';
  foreach m in array tous_modules loop
    insert into role_permissions(role_id,module_code,peut_voir,peut_creer,peut_modifier,peut_supprimer,peut_valider)
      values (rid,m,false,false,false,false,false) on conflict (role_id,module_code) do nothing;
  end loop;
end $$;

-- ----------------------------------------------------------------------------
-- 7. Migration des comptes déjà existants : conserve leur accès complet actuel
--    (aujourd'hui, sans notion de rôle, TOUT utilisateur connecté a un accès
--    complet — on ne restreint donc personne rétroactivement, seuls les
--    NOUVEAUX comptes créés après cette migration seront concernés par le
--    rôle « Sans rôle » par défaut).
-- ----------------------------------------------------------------------------
-- Si un rôle texte existe déjà (profiles.role, cf. sql/affectations_caisse_pdv.sql), on le reprend ;
-- « utilisateur » / « technicien » (sans équivalent) → « sans rôle » ; profil sans rôle du tout → administrateur
-- (comportement historique : avant ce module, tout compte connecté avait un accès complet).
do $$
begin
  if exists (select 1 from information_schema.columns where table_schema='public' and table_name='profiles' and column_name='role') then
    execute $q$
      update profiles p set role_id = r.id from roles r
      where p.role_id is null and p.role is not null
        and r.code = case p.role when 'caissier' then 'caissiere' when 'utilisateur' then 'sans_role'
                                 when 'technicien' then 'sans_role' else p.role end $q$;
  end if;
end $$;
update profiles set role_id = (select id from roles where code = 'admin') where role_id is null;

-- ===========================================================================
-- 8. Comptes, connexion et sécurité à la manière de Menko Immo
--    (copie de sql/utilisateurs_auth_menko.sql)
-- ===========================================================================
-- ============================================================================
-- Sanix AluExpert ERP — Comptes utilisateurs à la manière de Menko Immo
-- ============================================================================
-- À exécuter APRÈS sql/utilisateurs_roles.sql (rôles & droits par module) et
-- sql/affectations_caisse_pdv.sql. Reprend le fonctionnement de Menko Immo :
--   • comptes créés par un administrateur (identifiant + mot de passe provisoire),
--     plus d'inscription libre (sauf le tout premier compte, qui devient administrateur) ;
--   • connexion par identifiant OU e-mail (Edge Function « connexion ») avec blocage
--     après 5 échecs sur 24 h et journal des connexions (IP, navigateur) ;
--   • changement de mot de passe obligatoire à la première connexion / après réinitialisation ;
--   • activation / désactivation des comptes, déconnexion forcée de tous les postes,
--     déconnexion après inactivité (paramétrable).
-- En plus de Menko, appliqué DANS LA BASE : un compte désactivé, « sans rôle » ou devant
-- changer son mot de passe n'a accès à AUCUNE donnée (politiques RLS restrictives).
-- L'authentification reste celle de Supabase (sessions signées, RLS) : pas de table de
-- mots de passe maison.
-- ============================================================================

-- ---------- Profils : colonnes Menko ----------
alter table profiles add column if not exists login text;
alter table profiles add column if not exists telephone text;
alter table profiles add column if not exists must_change boolean not null default false;
alter table profiles add column if not exists derniere_connexion timestamptz;
alter table profiles add column if not exists cree_par uuid;
create unique index if not exists profiles_login_unique on profiles (lower(login)) where login is not null;

-- Identifiant proposé à partir d'un e-mail (début de l'adresse, rendu unique)
create or replace function public.login_depuis_email(p_email text) returns text
language plpgsql stable security definer set search_path = public as $$
declare base text; cand text; n int := 1;
begin
  base := lower(regexp_replace(split_part(coalesce(p_email,''),'@',1), '[^a-zA-Z0-9._-]', '', 'g'));
  base := left(regexp_replace(base, '^[^a-z0-9]+', ''), 26);
  if length(base) < 3 then base := base || 'utilisateur'; end if;
  cand := base;
  while exists (select 1 from profiles where lower(login) = cand) loop n := n + 1; cand := base || n; end loop;
  return cand;
end $$;

-- E-mail et identifiant des comptes existants
update profiles p set email = u.email from auth.users u where u.id = p.id and p.email is null;
do $$
declare r record;
begin
  for r in select id, email from profiles where login is null and email is not null order by created_at loop
    update profiles set login = public.login_depuis_email(r.email) where id = r.id;
  end loop;
end $$;

-- Nouveaux comptes : le profil reçoit aussi l'e-mail et un identifiant (modifiable ensuite)
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, nom_complet, email, login)
  values (new.id, coalesce(new.raw_user_meta_data->>'nom_complet', new.email),
          case when new.email like '%@comptes.aluexpert.local' then null else new.email end,
          public.login_depuis_email(new.email));
  return new;
end $$;

-- ---------- Rôle texte = reflet du rôle attribué (roles.code) ----------
-- Les rôles sont désormais dynamiques (rôles personnalisés possibles) : plus de liste figée.
alter table profiles drop constraint if exists profiles_role_check;
alter table profiles alter column role drop default;
alter table profiles alter column role drop not null;

create or replace function public.profiles_garde_et_role() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_admin uuid; v_sans uuid; v_nb_admins int; appelant_admin boolean;
begin
  select id into v_admin from roles where code = 'admin';
  select id into v_sans from roles where code = 'sans_role';
  appelant_admin := public.is_admin();

  if tg_op = 'INSERT' then
    -- Rôle initial : le tout premier compte devient administrateur ; ensuite « sans rôle »,
    -- sauf création par un administrateur ou par le serveur (Edge Function, service role).
    if auth.uid() is not null and not appelant_admin then new.role_id := null; end if;
    if new.role_id is null then
      new.role_id := case when exists (select 1 from profiles where role_id = v_admin) then v_sans else v_admin end;
    end if;
  else
    -- Champs réservés à un administrateur (ou au serveur / aux fonctions autorisées)
    if auth.uid() is not null and not appelant_admin
       and coalesce(current_setting('app.maj_compte_autorisee', true), '') <> '1' then
      new.role_id := old.role_id; new.actif := old.actif; new.login := old.login;
      new.must_change := old.must_change; new.cree_par := old.cree_par;
    end if;
    -- Jamais moins d'un administrateur actif
    if old.role_id = v_admin and old.actif and (new.role_id is distinct from v_admin or not new.actif) then
      select count(*) into v_nb_admins from profiles where role_id = v_admin and actif and id <> old.id;
      if v_nb_admins = 0 then raise exception 'Impossible : ce compte est le dernier administrateur actif'; end if;
    end if;
  end if;
  new.role := (select code from roles where id = new.role_id);
  return new;
end $$;
drop trigger if exists trg_proteger_role_profil on profiles;         -- remplacé par la garde ci-dessous
drop trigger if exists trg_profiles_proteger_role on profiles;       -- idem (ancienne garde sur le rôle texte)
drop trigger if exists trg_zz_profiles_garde_et_role on profiles;
create trigger trg_zz_profiles_garde_et_role before insert or update on profiles
  for each row execute function public.profiles_garde_et_role();
-- Un administrateur peut modifier les profils des autres (rôle, statut…) ; chacun garde la main sur le sien
drop policy if exists "profiles_admin_update" on profiles;
create policy "profiles_admin_update" on profiles for update to authenticated using (public.is_admin()) with check (public.is_admin());
-- Réaligne le rôle texte des comptes existants
update profiles p set role = r.code from roles r where r.id = p.role_id and p.role is distinct from r.code;

-- ---------- Accès aux données : comptes actifs, avec rôle, mot de passe à jour ----------
create or replace function public.est_utilisateur_autorise() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from profiles p join roles r on r.id = p.role_id
    where p.id = auth.uid() and p.actif and not p.must_change and r.code <> 'sans_role'
  );
$$;
do $$
declare t text;
begin
  for t in select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
           where n.nspname = 'public' and c.relkind = 'r' and c.relrowsecurity
             and c.relname not in ('profiles','roles','role_permissions','invitations','logs_connexion','caisse_pins')
  loop
    execute format('drop policy if exists "acces_comptes_autorises" on public.%I', t);
    execute format('create policy "acces_comptes_autorises" on public.%I as restrictive for all to authenticated using (public.est_utilisateur_autorise()) with check (public.est_utilisateur_autorise())', t);
  end loop;
end $$;

-- ---------- Journal des connexions (écrit par l'Edge Function « connexion ») ----------
create table if not exists logs_connexion (
  id uuid primary key default gen_random_uuid(),
  login_saisi text not null,
  user_id uuid references profiles(id) on delete set null,
  succes boolean not null,
  detail text,
  ip text,
  user_agent text,
  created_at timestamptz not null default now()
);
create index if not exists idx_logs_connexion_login on logs_connexion (login_saisi, created_at desc);
create index if not exists idx_logs_connexion_date on logs_connexion (created_at desc);
alter table logs_connexion enable row level security;
drop policy if exists "logs_connexion_admin" on logs_connexion;
create policy "logs_connexion_admin" on logs_connexion for select to authenticated using (public.is_admin());

-- ---------- Paramètres de session ----------
alter table parametres add column if not exists session_inactivite_min int not null default 30;   -- 0 = désactivé
alter table parametres add column if not exists deconnexion_forcee_le timestamptz;

-- ---------- Fonctions appelées par l'application ----------
-- Installation vierge ? (affiche « Créer le compte administrateur » sur l'écran de connexion)
create or replace function public.installation_vierge() returns boolean
language sql stable security definer set search_path = public as $$
  select not exists (select 1 from profiles p join roles r on r.id = p.role_id where r.code = 'admin');
$$;
-- Après un changement de mot de passe obligatoire (le mot de passe est changé via Supabase Auth)
create or replace function public.mot_de_passe_change() returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Non authentifié'; end if;
  perform set_config('app.maj_compte_autorisee', '1', true);
  update profiles set must_change = false where id = auth.uid();
end $$;
-- Déconnecte tous les postes (chaque application vérifie cette date toutes les minutes)
create or replace function public.forcer_deconnexion_generale() returns timestamptz
language plpgsql security definer set search_path = public as $$
declare v timestamptz := now();
begin
  if not public.is_admin() then raise exception 'Réservé à un administrateur'; end if;
  update parametres set deconnexion_forcee_le = v where true;
  return v;
end $$;
revoke execute on function public.mot_de_passe_change(), public.forcer_deconnexion_generale() from public, anon;
grant execute on function public.mot_de_passe_change(), public.forcer_deconnexion_generale() to authenticated;
grant execute on function public.installation_vierge() to anon, authenticated;
