/* Sanix AluExpert ERP — configuration de CETTE installation (une par structure cliente).
   Chaque structure a sa propre base Supabase : remplacez l'URL et la clé publique (anon) par celles
   de son projet (Supabase → Project Settings → API). La clé « anon » est publique par conception :
   la sécurité repose sur les règles d'accès (RLS) de la base. Modèle vierge : config.example.js */
window.SB_CFG = {
  SUPABASE_URL: 'https://snphfuygvllbioaoyfkm.supabase.co',
  SUPABASE_ANON_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNucGhmdXlndmxsYmlvYW95ZmttIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODkxODY5NjgsImV4cCI6MjEwNDc2Mjk2OH0.DCX9OO8aTwWLFGEWPDS9jESrnAPKDjhMSq10SEM1FBs'
};
