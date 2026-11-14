-- Değirmenlikızık Proje: veli hesabı ve öğrenci eşleştirmesi
-- Ön koşul: student_fields_migration.sql çalıştırılmış olmalı
-- (students.parent_name ve students.parent_email sütunları).
-- Veli, students.parent_email alanındaki adresle en az bir kez OTP girişi yapmış olmalı.
-- Bu sorgu mevcut öğretmen/öğrenci rollerini değiştirmez.

-- 1) Eşleşen Auth kullanıcıları için yalnızca profili olmayan veli kayıtlarını oluştur.
insert into public.profiles (id, full_name, role)
select
  u.id,
  coalesce(
    (
      select nullif(trim(s.parent_name), '')
      from public.students s
      where lower(trim(s.parent_email)) = lower(trim(u.email))
        and nullif(trim(s.parent_email), '') is not null
      order by s.created_at
      limit 1
    ),
    u.email
  ),
  'parent'
from auth.users u
where nullif(trim(u.email), '') is not null
  and exists (
    select 1
    from public.students s
    where lower(trim(s.parent_email)) = lower(trim(u.email))
      and nullif(trim(s.parent_email), '') is not null
  )
  and not exists (
    select 1 from public.profiles p where p.id = u.id
  );

-- 2) Sadece role=parent olan profillere, e-posta eşleşen çocukları bağla.
-- Aynı veli e-postası birden fazla öğrencide bulunabilir; hepsi bağlanır.
insert into public.parent_student (parent_user_id, student_id)
select distinct p.id, s.id
from public.profiles p
join auth.users u on u.id = p.id
join public.students s
  on lower(trim(s.parent_email)) = lower(trim(u.email))
where p.role = 'parent'
  and nullif(trim(u.email), '') is not null
  and nullif(trim(s.parent_email), '') is not null
on conflict (parent_user_id, student_id) do nothing;

-- 3) Eşleşmeleri kontrol et.
select
  p.full_name as parent_name,
  u.email as parent_email,
  s.full_name as student_name,
  s.grade
from public.parent_student ps
join public.profiles p on p.id = ps.parent_user_id and p.role = 'parent'
join auth.users u on u.id = p.id
join public.students s on s.id = ps.student_id
order by p.full_name, s.full_name;

-- Güvenlik notu:
-- Veli rolü ve parent_student ilişkileri yalnızca yönetici tarafından
-- Supabase SQL Editor üzerinden oluşturulmalıdır. Bu dosyada RLS gevşetilmez.
