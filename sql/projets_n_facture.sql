-- ============================================================================
-- Sanix AluExpert ERP — N° de facture rattaché au chantier
-- ============================================================================
-- Le n° de facture (ex. « N°27484 ») identifie le chantier et permet de rattacher ses mouvements de
-- caisse (numéro / motif) et de stock (référence). Saisi à la main ou déduit du libellé du chantier.
-- À exécuter une fois (idempotent).
-- ============================================================================
alter table public.projets add column if not exists n_facture text;
create index if not exists idx_projets_n_facture on public.projets (n_facture);

-- Reprise de l'existant : « Fiche N27484 - 2026-01-28 » ou « CHANTIER M BONY 29223 »
update public.projets set n_facture = 'N°' || (regexp_match(libelle, '^Fiche\s+N(\d\S*)', 'i'))[1]
 where n_facture is null and libelle ~* '^Fiche\s+N\d';
update public.projets set n_facture = 'N°' || (regexp_match(libelle, '\m(\d{4,6})\M'))[1]
 where n_facture is null and libelle !~* '^Fiche\s+N' and libelle ~ '\m\d{4,6}\M';
