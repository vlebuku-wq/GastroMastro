-- ============================================================
-- Bestand & Bestellung – Datenbank für Supabase
-- Einmal komplett im SQL Editor von Supabase ausführen.
--
-- Aufbau:
--   lager       – ein gemeinsamer Bereich (z. B. "WG Stuttgart")
--   mitglieder  – wer zu welchem Lager gehört
--   eintraege   – alle Daten der App (Artikel, Lieferanten, Listen …),
--                 je Eintrag ein JSON-Dokument. So bleibt die App-Logik
--                 unverändert und Sicherungen lassen sich 1:1 einspielen.
--
-- Zugriffsregel: Jeder sieht und ändert nur die Daten der Lager,
-- in denen er Mitglied ist. Beitreten geht nur mit Einladungscode.
-- ============================================================

-- ---------- Tabellen ----------
create table if not exists public.lager (
  id               uuid primary key default gen_random_uuid(),
  name             text not null check (char_length(name) between 1 and 80),
  einladungscode   text not null unique default upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8)),
  erstellt_von     uuid references auth.users on delete set null default auth.uid(),
  erstellt_am      timestamptz not null default now()
);

create table if not exists public.mitglieder (
  lager_id     uuid not null references public.lager on delete cascade,
  user_id      uuid not null references auth.users on delete cascade,
  rolle        text not null default 'mitglied' check (rolle in ('besitzer', 'mitglied')),
  beigetreten  timestamptz not null default now(),
  primary key (lager_id, user_id)
);
create index if not exists mitglieder_user_idx on public.mitglieder (user_id);

create table if not exists public.eintraege (
  lager_id      uuid not null references public.lager on delete cascade,
  sammlung      text not null check (sammlung in ('rubriken', 'lists', 'items', 'suppliers', 'inventory', 'settings')),
  id            text not null check (char_length(id) between 1 and 200),
  daten         jsonb not null default '{}'::jsonb check (jsonb_typeof(daten) = 'object' and pg_column_size(daten) < 262144),
  geaendert_am  timestamptz not null default now(),
  geaendert_von uuid default auth.uid(),
  primary key (lager_id, sammlung, id)
);

-- Änderungszeitpunkt automatisch setzen
create or replace function public.eintraege_stempel()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.geaendert_am := now();
  new.geaendert_von := auth.uid();
  return new;
end $$;
drop trigger if exists eintraege_stempel on public.eintraege;
create trigger eintraege_stempel before insert or update on public.eintraege
  for each row execute function public.eintraege_stempel();

-- ---------- Hilfsfunktion: Ist der angemeldete Nutzer Mitglied? ----------
create or replace function public.ist_mitglied(l uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.mitglieder m where m.lager_id = l and m.user_id = auth.uid());
$$;

-- ---------- Zugriffsregeln (Row Level Security) ----------
alter table public.lager      enable row level security;
alter table public.mitglieder enable row level security;
alter table public.eintraege  enable row level security;

drop policy if exists "lager lesen" on public.lager;
create policy "lager lesen" on public.lager for select to authenticated using (public.ist_mitglied(id));
drop policy if exists "lager umbenennen" on public.lager;
create policy "lager umbenennen" on public.lager for update to authenticated using (public.ist_mitglied(id)) with check (public.ist_mitglied(id));
-- Anlegen und Beitreten nur über die Funktionen unten.

drop policy if exists "mitglieder lesen" on public.mitglieder;
create policy "mitglieder lesen" on public.mitglieder for select to authenticated using (public.ist_mitglied(lager_id));
drop policy if exists "lager verlassen" on public.mitglieder;
create policy "lager verlassen" on public.mitglieder for delete to authenticated using (user_id = auth.uid());

drop policy if exists "eintraege lesen" on public.eintraege;
create policy "eintraege lesen" on public.eintraege for select to authenticated using (public.ist_mitglied(lager_id));
drop policy if exists "eintraege anlegen" on public.eintraege;
create policy "eintraege anlegen" on public.eintraege for insert to authenticated with check (public.ist_mitglied(lager_id));
drop policy if exists "eintraege aendern" on public.eintraege;
create policy "eintraege aendern" on public.eintraege for update to authenticated using (public.ist_mitglied(lager_id)) with check (public.ist_mitglied(lager_id));
drop policy if exists "eintraege loeschen" on public.eintraege;
create policy "eintraege loeschen" on public.eintraege for delete to authenticated using (public.ist_mitglied(lager_id));

-- ---------- Funktionen für die App ----------
-- Neues Lager anlegen; der Ersteller wird Besitzer.
create or replace function public.lager_anlegen(p_name text)
returns public.lager language plpgsql security definer set search_path = '' as $$
declare l public.lager;
begin
  if auth.uid() is null then raise exception 'Nicht angemeldet'; end if;
  if (select count(*) from public.lager where erstellt_von = auth.uid()) >= 10 then
    raise exception 'Höchstens 10 Lager pro Konto';
  end if;
  insert into public.lager (name, erstellt_von) values (trim(p_name), auth.uid()) returning * into l;
  insert into public.mitglieder (lager_id, user_id, rolle) values (l.id, auth.uid(), 'besitzer');
  return l;
end $$;

-- Mit Einladungscode beitreten.
create or replace function public.lager_beitreten(p_code text)
returns public.lager language plpgsql security definer set search_path = '' as $$
declare l public.lager;
begin
  if auth.uid() is null then raise exception 'Nicht angemeldet'; end if;
  select * into l from public.lager where einladungscode = upper(trim(p_code));
  if not found then raise exception 'Einladungscode unbekannt'; end if;
  insert into public.mitglieder (lager_id, user_id) values (l.id, auth.uid()) on conflict do nothing;
  return l;
end $$;

-- Neuen Einladungscode erzeugen (der alte wird ungültig). Nur für Besitzer.
create or replace function public.einladungscode_erneuern(p_lager uuid)
returns text language plpgsql security definer set search_path = '' as $$
declare c text;
begin
  if not exists (select 1 from public.mitglieder where lager_id = p_lager and user_id = auth.uid() and rolle = 'besitzer') then
    raise exception 'Nur der Besitzer kann den Code erneuern';
  end if;
  c := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
  update public.lager set einladungscode = c where id = p_lager;
  return c;
end $$;

revoke all on function public.lager_anlegen(text), public.lager_beitreten(text), public.einladungscode_erneuern(uuid), public.ist_mitglied(uuid) from public, anon;
grant execute on function public.lager_anlegen(text), public.lager_beitreten(text), public.einladungscode_erneuern(uuid), public.ist_mitglied(uuid) to authenticated;

grant select, update on public.lager to authenticated;
grant select, delete on public.mitglieder to authenticated;
grant select, insert, update, delete on public.eintraege to authenticated;
revoke all on public.lager, public.mitglieder, public.eintraege from anon;

-- ---------- Live-Aktualisierung ----------
do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'eintraege') then
    alter publication supabase_realtime add table public.eintraege;
  end if;
end $$;
