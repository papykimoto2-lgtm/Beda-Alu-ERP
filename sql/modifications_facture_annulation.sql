-- ============================================================================
-- Sanix AluExpert ERP — Historique des modifications : annulation d'une modification
-- ============================================================================
-- Annuler une modification NE SUPPRIME RIEN : la commande chantier retrouve son état d'avant et l'annulation
-- devient une nouvelle ligne de l'historique (type ANNULATION, avec motif) qui pointe la modification annulée.
-- Une modification ne peut être annulée qu'une seule fois. Complète modifications_facture(.sql / _montant.sql). Idempotent.
-- ============================================================================
alter table public.facture_modifications add column if not exists annule_id uuid references public.facture_modifications(id) on delete set null;
alter table public.facture_modifications add column if not exists ancienne_designation text;   -- désignation de la ligne avant / après (si elle a changé)
alter table public.facture_modifications add column if not exists nouvelle_designation text;
alter table public.facture_modifications drop constraint if exists facture_modifications_type_check;
alter table public.facture_modifications add constraint facture_modifications_type_check
  check (type in ('MODIF','AJOUT','RETRAIT','AUTRE','ANNULATION'));
create unique index if not exists uq_facture_modif_annule on public.facture_modifications (annule_id) where annule_id is not null;
