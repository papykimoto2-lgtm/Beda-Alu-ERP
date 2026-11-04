-- =====================================================================
-- Validations en temps réel (Supabase Realtime)
-- Publie les tables du circuit de validation pour que l'application
-- (badge « Validations », notification, pages de validation) se mette à
-- jour sans recharger la page. Les politiques RLS restent appliquées :
-- chaque utilisateur ne reçoit que les lignes qu'il a le droit de lire.
-- Script idempotent.
-- =====================================================================
do $$
declare t text;
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
  foreach t in array array['caisse_demandes','commandes_fournisseur','commandes_internes'] loop
    if to_regclass('public.' || t) is not null
       and not exists (select 1 from pg_publication_tables
                        where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;
