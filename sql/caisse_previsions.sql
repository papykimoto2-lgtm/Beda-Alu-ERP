-- ============================================================================
-- Sanix AluExpert ERP — Caisse : PRÉVISIONS DE DÉPENSES validées par la hiérarchie
-- ============================================================================
-- Une prévision est une dépense planifiée (date prévue, montant, motif, bénéficiaire, chantier, caisse).
-- Elle est approuvée / rejetée par la hiérarchie : droit « valider » du module Caisse + plafond du rôle +
-- palier hiérarchique (peut_valider_caisse, voir validations_hierarchie.sql). Une fois validée, elle se
-- décaisse par un bon de sortie de caisse (qui suit le circuit normal) et passe à « réalisée ».
-- Les changements de statut passent UNIQUEMENT par les fonctions ci-dessous (aucune écriture directe).
-- Prérequis : validation_dg.sql et validations_hierarchie.sql. Idempotent.
-- ============================================================================
create sequence if not exists public.caisse_previsions_seq;
create table if not exists public.caisse_previsions (
  id uuid primary key default gen_random_uuid(),
  numero text unique default ('PRV-' || lpad(nextval('public.caisse_previsions_seq')::text, 5, '0')),
  date_prevue date not null,
  montant numeric(14,2) not null check (montant > 0),
  motif text not null,
  beneficiaire text,
  categorie text,
  caisse_id uuid references public.caisses(id) on delete set null,
  projet_id uuid references public.projets(id) on delete set null,
  statut text not null default 'en_attente' check (statut in ('en_attente','validee','rejetee','annulee','realisee')),
  niveau_requis int not null default 0,
  demande_par uuid default auth.uid() references public.profiles(id) on delete set null,
  demande_nom text,
  demande_le timestamptz not null default now(),
  decide_par uuid,
  decide_nom text,
  decide_le timestamptz,
  motif_rejet text,
  realise_le timestamptz,
  bon_numero text,
  created_at timestamptz not null default now()
);
create index if not exists idx_cprev_statut on public.caisse_previsions (statut, date_prevue);
create index if not exists idx_cprev_projet on public.caisse_previsions (projet_id);

-- Nom du demandeur et palier exigé figés à la création
create or replace function public.trg_caisse_previsions_ins() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  new.demande_par := auth.uid();
  select coalesce(nom_complet, login) into new.demande_nom from profiles where id = auth.uid();
  new.niveau_requis := public.validation_niveau_requis(new.montant);
  new.statut := 'en_attente';
  return new;
end $$;
drop trigger if exists trg_caisse_previsions_ins on public.caisse_previsions;
create trigger trg_caisse_previsions_ins before insert on public.caisse_previsions
  for each row execute function public.trg_caisse_previsions_ins();

alter table public.caisse_previsions enable row level security;
drop policy if exists "cprev_select" on public.caisse_previsions;
create policy "cprev_select" on public.caisse_previsions for select to authenticated using (true);
drop policy if exists "cprev_insert" on public.caisse_previsions;
create policy "cprev_insert" on public.caisse_previsions for insert to authenticated with check (demande_par = auth.uid());
drop policy if exists "acces_comptes_autorises" on public.caisse_previsions;
create policy "acces_comptes_autorises" on public.caisse_previsions as restrictive for all to authenticated
  using (public.est_utilisateur_autorise()) with check (public.est_utilisateur_autorise());
revoke all on public.caisse_previsions from anon, authenticated;
grant select, insert on public.caisse_previsions to authenticated;

-- Décision de la hiérarchie
create or replace function public.caisse_prevision_decider(p_id uuid, p_decision text, p_motif text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare d caisse_previsions; v_nom text;
begin
  if auth.uid() is null then raise exception 'Non authentifié'; end if;
  select * into d from caisse_previsions where id = p_id for update;
  if d.id is null then return jsonb_build_object('ok',false,'message','Prévision introuvable'); end if;
  if d.statut <> 'en_attente' then return jsonb_build_object('ok',false,'message','Cette prévision a déjà été traitée ('||d.statut||')'); end if;
  if not public.peut_valider_caisse(d.montant) then
    return jsonb_build_object('ok',false,'message','🔒 Votre plafond ou votre niveau hiérarchique ne couvre pas ce montant : un responsable habilité doit décider.');
  end if;
  if d.demande_par = auth.uid() and not public.is_admin() then
    return jsonb_build_object('ok',false,'message','Séparation des tâches : vous ne pouvez pas valider votre propre prévision.');
  end if;
  select coalesce(nom_complet, login) into v_nom from profiles where id = auth.uid();
  if p_decision = 'rejeter' then
    if coalesce(trim(p_motif),'') = '' then return jsonb_build_object('ok',false,'message','Motif du rejet obligatoire'); end if;
    update caisse_previsions set statut='rejetee', motif_rejet=trim(p_motif), decide_par=auth.uid(), decide_nom=v_nom, decide_le=now() where id = d.id;
    return jsonb_build_object('ok',true,'statut','rejetee');
  elsif p_decision = 'valider' then
    update caisse_previsions set statut='validee', decide_par=auth.uid(), decide_nom=v_nom, decide_le=now() where id = d.id;
    return jsonb_build_object('ok',true,'statut','validee');
  end if;
  raise exception 'Décision inconnue';
end $$;

-- Annulation par l'auteur (tant qu'elle est en attente)
create or replace function public.caisse_prevision_annuler(p_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare d caisse_previsions;
begin
  select * into d from caisse_previsions where id = p_id for update;
  if d.id is null then return jsonb_build_object('ok',false,'message','Prévision introuvable'); end if;
  if d.demande_par is distinct from auth.uid() then return jsonb_build_object('ok',false,'message','Seul l''auteur peut annuler sa prévision'); end if;
  if d.statut <> 'en_attente' then return jsonb_build_object('ok',false,'message','Déjà traitée ('||d.statut||')'); end if;
  update caisse_previsions set statut='annulee' where id = d.id;
  return jsonb_build_object('ok',true);
end $$;

-- Réalisation : appelée quand le bon de sortie issu de la prévision est enregistré
create or replace function public.caisse_prevision_realiser(p_id uuid, p_bon_numero text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare d caisse_previsions;
begin
  if auth.uid() is null or not public.est_utilisateur_autorise() then raise exception 'Accès refusé'; end if;
  select * into d from caisse_previsions where id = p_id for update;
  if d.id is null then return jsonb_build_object('ok',false,'message','Prévision introuvable'); end if;
  if d.statut <> 'validee' then return jsonb_build_object('ok',false,'message','Prévision non validée ('||d.statut||')'); end if;
  update caisse_previsions set statut='realisee', realise_le=now(), bon_numero=p_bon_numero where id = d.id;
  return jsonb_build_object('ok',true);
end $$;
grant execute on function public.caisse_prevision_decider(uuid,text,text), public.caisse_prevision_annuler(uuid), public.caisse_prevision_realiser(uuid,text) to authenticated;
