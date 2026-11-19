-- ============================================================================
-- Sanix AluExpert ERP — Historique des modifications d'une facture (MODI / MODIF)
-- ============================================================================
-- Du matériel livré sur le chantier d'un client peut être remplacé à sa demande : c'est la MÊME facture,
-- mais on garde la trace de chaque changement (date, matériel remplacé → remplaçant, écart de montant, note).
-- La facture est identifiée par sa clé numérique (ex. « 27484 » pour « N°27484 »), comme dans la page
-- « Factures des chantiers ». Les notes ne sont pas modifiables / supprimables, sauf par un administrateur.
-- À exécuter une fois (idempotent).
-- ============================================================================
create table if not exists public.facture_modifications (
  id uuid primary key default gen_random_uuid(),
  n_facture text not null,                                           -- clé numérique de la facture (27484)
  projet_id uuid references public.projets(id) on delete set null,   -- chantier concerné (facultatif)
  date_modif date not null default current_date,
  type text not null default 'MODIF' check (type in ('MODIF','AJOUT','RETRAIT','AUTRE')),
  ancien_materiel text,                                              -- matériel livré, remplacé
  nouveau_materiel text,                                             -- matériel de remplacement
  ecart_montant numeric,                                             -- + supplément / − avoir (FCFA), facultatif
  note text not null,
  created_by uuid default auth.uid() references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);
create index if not exists idx_facture_modif_facture on public.facture_modifications (n_facture, date_modif desc);
create index if not exists idx_facture_modif_projet on public.facture_modifications (projet_id);

alter table public.facture_modifications enable row level security;
drop policy if exists "facture_modif_select" on public.facture_modifications;
create policy "facture_modif_select" on public.facture_modifications for select to authenticated using (true);
drop policy if exists "facture_modif_insert" on public.facture_modifications;
create policy "facture_modif_insert" on public.facture_modifications for insert to authenticated with check (created_by = auth.uid());
drop policy if exists "facture_modif_admin_maj" on public.facture_modifications;
create policy "facture_modif_admin_maj" on public.facture_modifications for update to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists "facture_modif_admin_suppr" on public.facture_modifications;
create policy "facture_modif_admin_suppr" on public.facture_modifications for delete to authenticated using (public.is_admin());
-- Comptes désactivés / sans rôle / mot de passe à changer : aucun accès (comme les autres tables)
drop policy if exists "acces_comptes_autorises" on public.facture_modifications;
create policy "acces_comptes_autorises" on public.facture_modifications as restrictive for all to authenticated
  using (public.est_utilisateur_autorise()) with check (public.est_utilisateur_autorise());
grant select, insert, update, delete on public.facture_modifications to authenticated;
