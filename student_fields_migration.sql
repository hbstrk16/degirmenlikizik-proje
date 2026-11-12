-- Değirmenlikızık Proje: öğrenci kayıt formu alanları
-- Supabase Dashboard > SQL Editor bölümünde bir kez çalıştırın.
alter table public.students
  add column if not exists email text,
  add column if not exists parent_name text,
  add column if not exists parent_email text,
  add column if not exists target_lgs_score numeric(5,2),
  add column if not exists target_high_school text;

-- Puan hedefi 0-500 aralığında tutulur.
alter table public.students
  drop constraint if exists students_target_lgs_score_range;

alter table public.students
  add constraint students_target_lgs_score_range
  check (target_lgs_score is null or (target_lgs_score >= 0 and target_lgs_score <= 500));
