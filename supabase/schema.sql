-- Değirmenlikızık Proje: Supabase başlangıç şeması
-- Supabase SQL Editor içinde çalıştırılmalıdır.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  role text not null check (role in ('teacher','student','parent')),
  created_at timestamptz not null default now()
);

create table if not exists public.students (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  grade text not null default '8. sınıf',
  auth_user_id uuid unique references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.parent_student (
  parent_user_id uuid not null references auth.users(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  primary key(parent_user_id, student_id)
);

create table if not exists public.study_records (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id) on delete cascade,
  subject text not null,
  total_questions integer not null default 0 check(total_questions >= 0),
  correct integer not null default 0 check(correct >= 0),
  wrong integer not null default 0 check(wrong >= 0),
  blank integer not null default 0 check(blank >= 0),
  net numeric(7,2) generated always as (correct - wrong::numeric / 3) stored,
  status text not null default 'Tamamlandı',
  recorded_on date not null default current_date,
  created_at timestamptz not null default now(),
  check(correct + wrong + blank <= total_questions)
);

create table if not exists public.exam_results (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id) on delete cascade,
  exam_name text not null,
  total_net numeric(7,2) not null,
  exam_date date not null default current_date,
  created_at timestamptz not null default now()
);

create table if not exists public.attendance (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id) on delete cascade,
  attendance_date date not null default current_date,
  status text not null check(status in ('Geldi','Gelmedi','Geç geldi','İzinli')),
  note text,
  created_at timestamptz not null default now()
);

create table if not exists public.reading_records (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id) on delete cascade,
  title text not null,
  progress text,
  status text not null default 'Devam ediyor',
  recorded_on date not null default current_date,
  created_at timestamptz not null default now()
);

create table if not exists public.values_records (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id) on delete cascade,
  value_title text not null,
  teacher_note text,
  status text not null default 'Takip edilmeli',
  recorded_on date not null default current_date,
  created_at timestamptz not null default now()
);

create or replace function public.current_user_role()
returns text language sql stable security definer
set search_path = public
as $$ select role from public.profiles where id = auth.uid() $$;

create or replace function public.can_access_student(target_student uuid)
returns boolean language sql stable security definer
set search_path = public
as $$
  select
    public.current_user_role() = 'teacher'
    or exists(select 1 from public.students s where s.id = target_student and s.auth_user_id = auth.uid())
    or exists(select 1 from public.parent_student ps where ps.student_id = target_student and ps.parent_user_id = auth.uid())
$$;

alter table public.profiles enable row level security;
alter table public.students enable row level security;
alter table public.parent_student enable row level security;
alter table public.study_records enable row level security;
alter table public.exam_results enable row level security;
alter table public.attendance enable row level security;
alter table public.reading_records enable row level security;
alter table public.values_records enable row level security;

drop policy if exists "profiles self or teacher read" on public.profiles;
create policy "profiles self or teacher read" on public.profiles for select to authenticated
using (id = auth.uid() or public.current_user_role() = 'teacher');

drop policy if exists "teacher manages profiles" on public.profiles;
create policy "teacher manages profiles" on public.profiles for all to authenticated
using (public.current_user_role() = 'teacher') with check (public.current_user_role() = 'teacher');

drop policy if exists "student and linked adults read students" on public.students;
create policy "student and linked adults read students" on public.students for select to authenticated
using (public.can_access_student(id));

drop policy if exists "teacher manages students" on public.students;
create policy "teacher manages students" on public.students for all to authenticated
using (public.current_user_role() = 'teacher') with check (public.current_user_role() = 'teacher');

drop policy if exists "linked parent reads relation" on public.parent_student;
create policy "linked parent reads relation" on public.parent_student for select to authenticated
using (parent_user_id = auth.uid() or public.current_user_role() = 'teacher');

drop policy if exists "teacher manages parent relations" on public.parent_student;
create policy "teacher manages parent relations" on public.parent_student for all to authenticated
using (public.current_user_role() = 'teacher') with check (public.current_user_role() = 'teacher');

do $$
declare t text;
begin
 foreach t in array array['study_records','exam_results','attendance','reading_records','values_records'] loop
   execute format('drop policy if exists "authorized read %1$s" on public.%1$I', t);
   execute format('create policy "authorized read %1$s" on public.%1$I for select to authenticated using (public.can_access_student(student_id))', t);
   execute format('drop policy if exists "teacher writes %1$s" on public.%1$I', t);
   execute format('create policy "teacher writes %1$s" on public.%1$I for all to authenticated using (public.current_user_role() = ''teacher'') with check (public.current_user_role() = ''teacher'')', t);
 end loop;
end $$;
