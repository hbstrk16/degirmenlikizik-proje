-- Değirmenlikızık Proje: Supabase başlangıç şeması
-- Bu dosyayı Supabase SQL Editor içinde, yalnızca bir kez çalıştırın.
-- İlk öğretmen hesabı, Auth kullanıcısı oluşturulduktan sonra ayrı bir
-- yönetici sorgusuyla eklenecektir. Herkese açık öğretmen kaydı YOKTUR.

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

-- Güvenlik fonksiyonları: SECURITY DEFINER, RLS döngülerini önler.
-- Boş search_path ve tam nitelikli tablo adları nesne taklidi riskini azaltır.
create or replace function public.current_user_role()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select p.role
  from public.profiles as p
  where p.id = auth.uid()
$$;

create or replace function public.can_access_student(target_student uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    public.current_user_role() = 'teacher'
    or exists (
      select 1 from public.students as s
      where s.id = target_student and s.auth_user_id = auth.uid()
    )
    or exists (
      select 1 from public.parent_student as ps
      where ps.student_id = target_student and ps.parent_user_id = auth.uid()
    )
$$;

alter table public.profiles enable row level security;
alter table public.students enable row level security;
alter table public.parent_student enable row level security;
alter table public.study_records enable row level security;
alter table public.exam_results enable row level security;
alter table public.attendance enable row level security;
alter table public.reading_records enable row level security;
alter table public.values_records enable row level security;

-- Anonim kullanıcılar tablolara erişemez. Giriş yapmış kullanıcıların
-- SQL izinleri olsa da hangi satırları görebileceklerini RLS belirler.
revoke all on table
  public.profiles, public.students, public.parent_student,
  public.study_records, public.exam_results, public.attendance,
  public.reading_records, public.values_records
from anon;

grant select, insert, update, delete on table
  public.profiles, public.students, public.parent_student,
  public.study_records, public.exam_results, public.attendance,
  public.reading_records, public.values_records
to authenticated;

-- Profil: kullanıcı yalnızca kendi profilini okuyabilir; profil/rol
-- oluşturma ve yönetme yalnızca önceden yetkilendirilmiş öğretmene açıktır.
drop policy if exists "profiles self or teacher read" on public.profiles;
create policy "profiles self or teacher read"
on public.profiles for select to authenticated
using (id = auth.uid() or public.current_user_role() = 'teacher');

drop policy if exists "teacher manages profiles" on public.profiles;
create policy "teacher manages profiles"
on public.profiles for all to authenticated
using (public.current_user_role() = 'teacher')
with check (public.current_user_role() = 'teacher');

-- Öğrenci kayıtları: öğrenci kendisini, veli yalnızca ilişkilendirildiği
-- öğrenciyi okur. Yazma işlemleri öğretmene aittir.
drop policy if exists "student and linked adults read students" on public.students;
create policy "student and linked adults read students"
on public.students for select to authenticated
using (public.can_access_student(id));

drop policy if exists "teacher manages students" on public.students;
create policy "teacher manages students"
on public.students for all to authenticated
using (public.current_user_role() = 'teacher')
with check (public.current_user_role() = 'teacher');

drop policy if exists "linked parent reads relation" on public.parent_student;
create policy "linked parent reads relation"
on public.parent_student for select to authenticated
using (parent_user_id = auth.uid() or public.current_user_role() = 'teacher');

drop policy if exists "teacher manages parent relations" on public.parent_student;
create policy "teacher manages parent relations"
on public.parent_student for all to authenticated
using (public.current_user_role() = 'teacher')
with check (public.current_user_role() = 'teacher');

-- Çalışma, deneme, devam, okuma ve değerler kayıtları:
-- öğrenci/veli yalnızca yetkili olduğu öğrencinin kayıtlarını okur;
-- ekleme, değiştirme ve silme öğretmene aittir.
do $$
declare t text;
begin
  foreach t in array array[
    'study_records', 'exam_results', 'attendance',
    'reading_records', 'values_records'
  ] loop
    execute format(
      'drop policy if exists %I on public.%I',
      'authorized read ' || t, t
    );
    execute format(
      'create policy %I on public.%I for select to authenticated using (public.can_access_student(student_id))',
      'authorized read ' || t, t
    );
    execute format(
      'drop policy if exists %I on public.%I',
      'teacher writes ' || t, t
    );
    execute format(
      'create policy %I on public.%I for all to authenticated using (public.current_user_role() = ''teacher'') with check (public.current_user_role() = ''teacher'')',
      'teacher writes ' || t, t
    );
  end loop;
end $$;

-- Fonksiyonları yalnızca giriş yapmış kullanıcılar çalıştırabilir.
revoke all on function public.current_user_role() from public, anon;
revoke all on function public.can_access_student(uuid) from public, anon;
grant execute on function public.current_user_role() to authenticated;
grant execute on function public.can_access_student(uuid) to authenticated;

-- İLK ÖĞRETMENİ OLUŞTURMA:
-- Şemayı çalıştırdıktan sonra Supabase > Authentication > Users bölümünde
-- öğretmen hesabını yönetici olarak oluşturun. Ardından SQL Editor'da
-- ayrı bir sorguyla, kendi e-posta adresinizi yazarak profili ekleyin:
--
-- insert into public.profiles (id, full_name, role)
-- select id, 'Öğretmen', 'teacher'
-- from auth.users
-- where email = 'BURAYA_KENDI_EPOSTANIZI_YAZIN'
-- on conflict (id) do update
-- set full_name = excluded.full_name, role = excluded.role;
--
-- Bu sorguyu yalnızca proje sahibinin SQL Editor'ında çalıştırın.
-- Veritabanı parolasını, service_role anahtarını veya secret anahtarları
-- hiçbir zaman web sitesine koymayın.
