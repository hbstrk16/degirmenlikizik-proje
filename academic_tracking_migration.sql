-- Değirmenlikızık Proje: akademik takip uyumluluk güncellemesi
-- Supabase SQL Editor'da bir kez çalıştırılabilir; tekrar çalıştırmaya uygundur.
-- Bu migration mevcut öğrenci kayıtlarını silmez veya RLS güvenliğini gevşetmez.

-- 1) Etüt oturumlarının (gün/saat dilimi) kayıtta tutulması.
alter table public.study_records
  add column if not exists session_label text;

-- 2) Ders bazlı LGS deneme sonuçları.
alter table public.exam_results
  add column if not exists turkish_correct integer not null default 0,
  add column if not exists turkish_wrong integer not null default 0,
  add column if not exists turkish_net numeric(7,2),
  add column if not exists math_correct integer not null default 0,
  add column if not exists math_wrong integer not null default 0,
  add column if not exists math_net numeric(7,2),
  add column if not exists science_correct integer not null default 0,
  add column if not exists science_wrong integer not null default 0,
  add column if not exists science_net numeric(7,2),
  add column if not exists revolution_correct integer not null default 0,
  add column if not exists revolution_wrong integer not null default 0,
  add column if not exists revolution_net numeric(7,2),
  add column if not exists religion_correct integer not null default 0,
  add column if not exists religion_wrong integer not null default 0,
  add column if not exists religion_net numeric(7,2),
  add column if not exists english_correct integer not null default 0,
  add column if not exists english_wrong integer not null default 0,
  add column if not exists english_net numeric(7,2);

-- Eski deneme kayıtlarının ders netlerini mevcut doğru/yanlış verisinden hesapla.
update public.exam_results set
  turkish_net = turkish_correct - turkish_wrong::numeric / 3,
  math_net = math_correct - math_wrong::numeric / 3,
  science_net = science_correct - science_wrong::numeric / 3,
  revolution_net = revolution_correct - revolution_wrong::numeric / 3,
  religion_net = religion_correct - religion_wrong::numeric / 3,
  english_net = english_correct - english_wrong::numeric / 3
where turkish_net is null or math_net is null or science_net is null
   or revolution_net is null or religion_net is null or english_net is null;

-- 3) Öğrenci bazlı ders net hedefleri.
create table if not exists public.exam_targets (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null unique references public.students(id) on delete cascade,
  turkish_correct_target integer not null default 0,
  turkish_wrong_target integer not null default 0,
  turkish_net_target numeric(7,2) not null default 0,
  math_correct_target integer not null default 0,
  math_wrong_target integer not null default 0,
  math_net_target numeric(7,2) not null default 0,
  science_correct_target integer not null default 0,
  science_wrong_target integer not null default 0,
  science_net_target numeric(7,2) not null default 0,
  revolution_correct_target integer not null default 0,
  revolution_wrong_target integer not null default 0,
  revolution_net_target numeric(7,2) not null default 0,
  religion_correct_target integer not null default 0,
  religion_wrong_target integer not null default 0,
  religion_net_target numeric(7,2) not null default 0,
  english_correct_target integer not null default 0,
  english_wrong_target integer not null default 0,
  english_net_target numeric(7,2) not null default 0,
  total_net_target numeric(7,2) not null default 0,
  created_at timestamptz not null default now()
);

-- Mevcut exam_targets tablosu önceden oluşturulmuşsa eksik alanları ekle.
alter table public.exam_targets
  add column if not exists turkish_correct_target integer not null default 0,
  add column if not exists turkish_wrong_target integer not null default 0,
  add column if not exists turkish_net_target numeric(7,2) not null default 0,
  add column if not exists math_correct_target integer not null default 0,
  add column if not exists math_wrong_target integer not null default 0,
  add column if not exists math_net_target numeric(7,2) not null default 0,
  add column if not exists science_correct_target integer not null default 0,
  add column if not exists science_wrong_target integer not null default 0,
  add column if not exists science_net_target numeric(7,2) not null default 0,
  add column if not exists revolution_correct_target integer not null default 0,
  add column if not exists revolution_wrong_target integer not null default 0,
  add column if not exists revolution_net_target numeric(7,2) not null default 0,
  add column if not exists religion_correct_target integer not null default 0,
  add column if not exists religion_wrong_target integer not null default 0,
  add column if not exists religion_net_target numeric(7,2) not null default 0,
  add column if not exists english_correct_target integer not null default 0,
  add column if not exists english_wrong_target integer not null default 0,
  add column if not exists english_net_target numeric(7,2) not null default 0,
  add column if not exists total_net_target numeric(7,2) not null default 0,
  add column if not exists created_at timestamptz not null default now();

create unique index if not exists exam_targets_student_id_uidx
  on public.exam_targets(student_id);

-- 4) Uygulamanın kullandığı devam/devamsızlık tablosu.
-- Başlangıç şemasındaki public.attendance tablosunu silmeden,
-- uygulama ile uyumlu public.attendance_records tablosunu kurar.
create table if not exists public.attendance_records (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id) on delete cascade,
  attendance_date date not null default current_date,
  status text not null check(status in ('Geldi','Tam gün devamsız','Yarım gün devamsız','Geç geldi','İzinli')),
  note text,
  created_at timestamptz not null default now()
);

-- Eski başlangıç şemasındaki devam kayıtlarını yeni tabloya güvenli aktar.
-- Aynı kayıt kimliği daha önce taşındıysa tekrar eklenmez.
insert into public.attendance_records (id,student_id,attendance_date,status,note,created_at)
select
  a.id,
  a.student_id,
  a.attendance_date,
  case a.status
    when 'Gelmedi' then 'Tam gün devamsız'
    else a.status
  end,
  a.note,
  a.created_at
from public.attendance a
where a.status in ('Geldi','Gelmedi','Geç geldi','İzinli')
on conflict (id) do nothing;

-- 5) Yetkilendirme: öğrenci/veli yalnızca bağlı olduğu öğrencinin
-- kayıtlarını okuyabilir; yazma işlemleri öğretmene aittir.
alter table public.exam_targets enable row level security;
alter table public.attendance_records enable row level security;

grant select, insert, update, delete on table
  public.exam_targets, public.attendance_records
to authenticated;

revoke all on table public.exam_targets, public.attendance_records from anon;

drop policy if exists "authorized read exam_targets" on public.exam_targets;
create policy "authorized read exam_targets"
on public.exam_targets for select to authenticated
using (public.can_access_student(student_id));

drop policy if exists "teacher writes exam_targets" on public.exam_targets;
create policy "teacher writes exam_targets"
on public.exam_targets for all to authenticated
using (public.current_user_role() = 'teacher')
with check (public.current_user_role() = 'teacher');

drop policy if exists "authorized read attendance_records" on public.attendance_records;
create policy "authorized read attendance_records"
on public.attendance_records for select to authenticated
using (public.can_access_student(student_id));

drop policy if exists "teacher writes attendance_records" on public.attendance_records;
create policy "teacher writes attendance_records"
on public.attendance_records for all to authenticated
using (public.current_user_role() = 'teacher')
with check (public.current_user_role() = 'teacher');

-- Kontrol: tablo ve kolonlar Supabase Table Editor'da görünmelidir.
select 'exam_targets' as table_name, count(*) as record_count from public.exam_targets
union all
select 'attendance_records', count(*) from public.attendance_records;
