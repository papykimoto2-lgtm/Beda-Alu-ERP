-- ============================================================================
-- Sanix AluExpert ERP — Modification d'un mouvement de stock avec historique
-- ============================================================================
-- Le journal de stock est un registre : on ne change jamais la quantité d'un mouvement passé (le stock et le CMUP
-- en dépendent). Deux voies :
--  1. Informations du mouvement (date, motif, référence, chantier rattaché) : fonction modifier_mouvement_stock(),
--     motif de modification obligatoire, avant / après conservés dans mouvements_stock_modifs (lecture seule).
--  2. Quantité d'une sortie : l'application passe un mouvement d'AJUSTEMENT compensateur (stock_mouvement) —
--     la trace reste visible dans le journal.
-- À exécuter une fois (idempotent).
-- ============================================================================
create table if not exists public.mouvements_stock_modifs (
  id uuid primary key default gen_random_uuid(),
  mouvement_id uuid not null,
  projet_id uuid,                                   -- chantier après modification (pour l'historique du suivi)
  projet_avant uuid,
  avant jsonb not null,
  apres jsonb not null,
  motif text not null,
  created_by uuid default auth.uid() references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);
create index if not exists idx_msm_projet on public.mouvements_stock_modifs (projet_id, created_at desc);
create index if not exists idx_msm_projet_avant on public.mouvements_stock_modifs (projet_avant);
create index if not exists idx_msm_mvt on public.mouvements_stock_modifs (mouvement_id);

alter table public.mouvements_stock_modifs enable row level security;
drop policy if exists "msm_select" on public.mouvements_stock_modifs;
create policy "msm_select" on public.mouvements_stock_modifs for select to authenticated using (true);
drop policy if exists "acces_comptes_autorises" on public.mouvements_stock_modifs;
create policy "acces_comptes_autorises" on public.mouvements_stock_modifs as restrictive for all to authenticated
  using (public.est_utilisateur_autorise()) with check (public.est_utilisateur_autorise());
revoke all on public.mouvements_stock_modifs from anon, authenticated;
grant select on public.mouvements_stock_modifs to authenticated;

create or replace function public.modifier_mouvement_stock(p_id uuid, p_date date, p_motif text, p_reference text, p_projet_id uuid, p_raison text)
returns void language plpgsql security definer set search_path = public as $$
declare m mouvements_stock; v_avant jsonb; v_apres jsonb;
begin
  if auth.uid() is null or not public.est_utilisateur_autorise() then raise exception 'Accès refusé'; end if;
  if coalesce(trim(p_raison), '') = '' then raise exception 'Motif de modification obligatoire'; end if;
  select * into m from mouvements_stock where id = p_id for update;
  if m.id is null then raise exception 'Mouvement introuvable'; end if;
  if m.transfert_id is not null then raise exception 'Un mouvement de transfert ne se modifie pas ici'; end if;
  v_avant := jsonb_build_object('date_mouvement', m.date_mouvement, 'motif', m.motif, 'reference', m.reference, 'projet_id', m.projet_id);
  v_apres := jsonb_build_object('date_mouvement', coalesce(p_date, m.date_mouvement), 'motif', nullif(trim(coalesce(p_motif,'')), ''),
                                'reference', nullif(trim(coalesce(p_reference,'')), ''), 'projet_id', p_projet_id);
  if v_avant = v_apres then return; end if;
  update mouvements_stock set date_mouvement = coalesce(p_date, date_mouvement), motif = nullif(trim(coalesce(p_motif,'')), ''),
         reference = nullif(trim(coalesce(p_reference,'')), ''), projet_id = p_projet_id where id = m.id;
  insert into mouvements_stock_modifs(mouvement_id, projet_id, projet_avant, avant, apres, motif)
    values (m.id, p_projet_id, m.projet_id, v_avant, v_apres, trim(p_raison));
end $$;
grant execute on function public.modifier_mouvement_stock(uuid, date, text, text, uuid, text) to authenticated;
