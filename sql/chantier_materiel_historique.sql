-- ============================================================================
-- Sanix AluExpert ERP — Historique des modifications du calcul de matériel d'un chantier
-- ============================================================================
-- Chaque ajout / modification / suppression d'une ligne de chantier_materiel est journalisé par un
-- TRIGGER (impossible à contourner côté client) : avant / après (jsonb), auteur, date, motif.
-- Le motif est transmis par les fonctions modifier_materiel() / supprimer_materiel().
-- Le journal est en lecture seule (aucune politique d'écriture : seul le trigger écrit).
-- À exécuter une fois (idempotent).
-- ============================================================================
create table if not exists public.chantier_materiel_historique (
  id uuid primary key default gen_random_uuid(),
  materiel_id uuid not null,                                         -- ligne concernée (pas de FK : la ligne peut être supprimée)
  projet_id uuid references public.projets(id) on delete cascade,
  action text not null check (action in ('AJOUT','MODIFICATION','SUPPRESSION')),
  avant jsonb,
  apres jsonb,
  motif text,
  created_by uuid default auth.uid() references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);
create index if not exists idx_cmh_projet on public.chantier_materiel_historique (projet_id, created_at desc);
create index if not exists idx_cmh_materiel on public.chantier_materiel_historique (materiel_id);

alter table public.chantier_materiel_historique enable row level security;
drop policy if exists "cmh_select" on public.chantier_materiel_historique;
create policy "cmh_select" on public.chantier_materiel_historique for select to authenticated using (true);
drop policy if exists "acces_comptes_autorises" on public.chantier_materiel_historique;
create policy "acces_comptes_autorises" on public.chantier_materiel_historique as restrictive for all to authenticated
  using (public.est_utilisateur_autorise()) with check (public.est_utilisateur_autorise());
revoke all on public.chantier_materiel_historique from anon, authenticated;
grant select on public.chantier_materiel_historique to authenticated;

-- Trigger de journalisation
create or replace function public.trg_chantier_materiel_histo() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_motif text := nullif(current_setting('app.motif_materiel', true), '');
begin
  if tg_op = 'INSERT' then
    insert into chantier_materiel_historique(materiel_id, projet_id, action, apres, motif)
      values (new.id, new.projet_id, 'AJOUT', to_jsonb(new), v_motif);
  elsif tg_op = 'UPDATE' then
    if to_jsonb(new) is distinct from to_jsonb(old) then
      insert into chantier_materiel_historique(materiel_id, projet_id, action, avant, apres, motif)
        values (new.id, new.projet_id, 'MODIFICATION', to_jsonb(old), to_jsonb(new), v_motif);
    end if;
  else
    insert into chantier_materiel_historique(materiel_id, projet_id, action, avant, motif)
      values (old.id, old.projet_id, 'SUPPRESSION', to_jsonb(old), v_motif);
  end if;
  return null;
end $$;
drop trigger if exists trg_chantier_materiel_histo on public.chantier_materiel;
create trigger trg_chantier_materiel_histo after insert or update or delete on public.chantier_materiel
  for each row execute function public.trg_chantier_materiel_histo();

-- Modification / suppression avec motif (SECURITY INVOKER : les droits RLS de l'utilisateur s'appliquent)
create or replace function public.modifier_materiel(p_id uuid, p_designation text, p_quantite numeric, p_prix_unitaire numeric, p_motif text)
returns void language plpgsql as $$
begin
  if coalesce(trim(p_motif), '') = '' then raise exception 'Motif de modification obligatoire'; end if;
  perform set_config('app.motif_materiel', p_motif, true);
  update chantier_materiel set designation = p_designation, quantite = p_quantite, prix_unitaire = p_prix_unitaire where id = p_id;
  if not found then raise exception 'Ligne introuvable ou accès refusé'; end if;
end $$;

create or replace function public.supprimer_materiel(p_id uuid, p_motif text)
returns void language plpgsql as $$
begin
  if coalesce(trim(p_motif), '') = '' then raise exception 'Motif de suppression obligatoire'; end if;
  perform set_config('app.motif_materiel', p_motif, true);
  delete from chantier_materiel where id = p_id;
  if not found then raise exception 'Ligne introuvable ou accès refusé'; end if;
end $$;
grant execute on function public.modifier_materiel(uuid,text,numeric,numeric,text), public.supprimer_materiel(uuid,text) to authenticated;
