-- ============================================================================
-- Sanix AluExpert ERP — Historique des modifications : rattachement à la ligne de commande chantier et montants
-- ============================================================================
-- Complète sql/modifications_facture.sql : une modification peut maintenant changer la ligne de commande chantier
-- (montant, désignation). On garde la ligne concernée, le montant avant et après ; le montant initial reste
-- visible dans l'historique et dans la liste « Commandes chantier ». Idempotent.
-- ============================================================================
alter table public.facture_modifications add column if not exists commande_id uuid references public.commandes_chantier(id) on delete set null;
alter table public.facture_modifications add column if not exists ancien_montant numeric;
alter table public.facture_modifications add column if not exists nouveau_montant numeric;
create index if not exists idx_facture_modif_commande on public.facture_modifications (commande_id);
