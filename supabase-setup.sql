-- Cruciverba by Giuggi — tabella delle bozze e spazio per le immagini
-- Da incollare ed eseguire in Supabase > SQL Editor (una volta sola, su un progetto nuovo).
-- Non contiene istruzioni che cancellano dati: se lo esegui due volte, Supabase
-- segnalerà che alcune regole esistono già, ed è normale.

-- 1) Tabella delle bozze (papiri e cruciverba)
create table if not exists public.bozze (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null default auth.uid() references auth.users(id) on delete cascade,
  tipo          text not null check (tipo in ('papiro','cruciverba')),
  nome          text not null default 'Senza titolo',
  dati          jsonb not null default '{}'::jsonb,
  anteprima     text,
  creata_il     timestamptz not null default now(),
  modificata_il timestamptz not null default now()
);

create index if not exists bozze_utente_idx on public.bozze (user_id, tipo, modificata_il desc);

-- 2) Aggiorna da sola la data dell'ultima modifica
create or replace function public.bozze_tocca()
returns trigger language plpgsql as $$
begin
  new.modificata_il = now();
  return new;
end $$;

create or replace trigger bozze_tocca before update on public.bozze
  for each row execute function public.bozze_tocca();

-- 3) Sicurezza: ognuno vede e modifica solo le proprie righe
alter table public.bozze enable row level security;

create policy "bozze: leggi le tue"    on public.bozze for select to authenticated using (auth.uid() = user_id);
create policy "bozze: crea le tue"     on public.bozze for insert to authenticated with check (auth.uid() = user_id);
create policy "bozze: modifica le tue" on public.bozze for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "bozze: elimina le tue"  on public.bozze for delete to authenticated using (auth.uid() = user_id);

-- 4) Spazio privato per le immagini (logo, caricatura, foto): una cartella per utente
insert into storage.buckets (id, name, public)
values ('bozze', 'bozze', false)
on conflict (id) do nothing;

create policy "bozze file: leggi i tuoi" on storage.objects for select to authenticated
  using (bucket_id = 'bozze' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "bozze file: carica i tuoi" on storage.objects for insert to authenticated
  with check (bucket_id = 'bozze' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "bozze file: modifica i tuoi" on storage.objects for update to authenticated
  using (bucket_id = 'bozze' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'bozze' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "bozze file: elimina i tuoi" on storage.objects for delete to authenticated
  using (bucket_id = 'bozze' and (storage.foldername(name))[1] = auth.uid()::text);
