-- Cumartesi öğretmen ders dinleme puanları
-- Supabase SQL Editor'da bir kez çalıştırın.
-- Mevcut etüt kayıtlarına dokunmaz; puanlar ayrı tabloda tutulur.

create table if not exists public.saturday_lesson_ratings (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id) on delete cascade,
  lesson_date date not null,
  subject text not null check (subject in ('Türkçe','Matematik','Fen Bilimleri','İnkılap Tarihi','İngilizce')),
  score integer check (score between 0 and 10),
  teacher_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (student_id, lesson_date, subject)
);

create index if not exists saturday_lesson_ratings_date_idx
  on public.saturday_lesson_ratings(lesson_date);

alter table public.saturday_lesson_ratings enable row level security;

grant select, insert, update, delete
  on table public.saturday_lesson_ratings to authenticated;
revoke all on table public.saturday_lesson_ratings from anon;

drop policy if exists "teacher manages saturday lesson ratings"
  on public.saturday_lesson_ratings;
create policy "teacher manages saturday lesson ratings"
  on public.saturday_lesson_ratings
  for all to authenticated
  using (public.current_user_role() = 'teacher')
  with check (public.current_user_role() = 'teacher');

-- Doğrulama
select column_name, data_type
from information_schema.columns
where table_schema = 'public'
  and table_name = 'saturday_lesson_ratings'
order by ordinal_position;
