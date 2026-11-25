-- ============================================================================
-- Sanix AluExpert ERP — Matériel de chantier : fournisseur modifiable (avec historique)
-- ============================================================================
-- Remplace modifier_materiel() pour accepter le fournisseur. À exécuter après chantier_materiel_historique.sql.
-- Idempotent.
-- ============================================================================
drop function if exists public.modifier_materiel(uuid, text, numeric, numeric, text);
create or replace function public.modifier_materiel(p_id uuid, p_designation text, p_quantite numeric, p_prix_unitaire numeric, p_motif text, p_fournisseur text default null)
returns void language plpgsql as $$
begin
  if coalesce(trim(p_motif), '') = '' then raise exception 'Motif de modification obligatoire'; end if;
  perform set_config('app.motif_materiel', p_motif, true);
  update chantier_materiel set designation = p_designation, quantite = p_quantite, prix_unitaire = p_prix_unitaire,
         fournisseur = nullif(trim(coalesce(p_fournisseur, '')), '') where id = p_id;
  if not found then raise exception 'Ligne introuvable ou accès refusé'; end if;
end $$;
grant execute on function public.modifier_materiel(uuid,text,numeric,numeric,text,text) to authenticated;
