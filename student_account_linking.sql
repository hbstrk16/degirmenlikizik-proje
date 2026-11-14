-- Değirmenlikızık Proje: öğrenci hesaplarını öğrenci kayıtlarıyla eşleştirme
-- Ön koşullar:
-- 1) students tablosunda email sütunu bulunmalı (student_fields_migration.sql).
-- 2) Öğrenci, uygulamadaki e-posta bağlantısıyla en az bir kez giriş yapmış olmalı.
-- 3) Bu sorguyu yalnızca proje yöneticisi Supabase SQL Editor'da çalıştırmalı.
--
-- Ön kontrol: aynı e-posta birden fazla öğrenci kaydında kullanılmamalı.
select lower(trim(email)) as email, count(*) as kayit_sayisi
from public.students
where email is not null and trim(email) <> ''
group by lower(trim(email))
having count(*) > 1;

-- Auth kullanıcısı bulunan ve henüz profili olmayan öğrencilere öğrenci rolü tanımlar.
-- Var olan öğretmen/veli profillerinin rolünü değiştirmez.
insert into public.profiles (id, full_name, role)
select u.id, s.full_name, 'student'
from auth.users u
join public.students s
  on lower(trim(s.email)) = lower(trim(u.email))
where s.email is not null
  and trim(s.email) <> ''
  and not exists (
    select 1 from public.profiles p where p.id = u.id
  )
on conflict (id) do nothing;

-- Yalnızca rolü student olan profilleri ilgili öğrenci kaydına bağlar.
update public.students s
set auth_user_id = u.id
from auth.users u
join public.profiles p
  on p.id = u.id
 and p.role = 'student'
where s.email is not null
  and trim(s.email) <> ''
  and lower(trim(s.email)) = lower(trim(u.email))
  and s.auth_user_id is distinct from u.id;

-- Sonuç kontrolü: eşleştirilen öğrenci hesaplarını listeler.
select full_name, grade, email, auth_user_id
from public.students
where auth_user_id is not null
order by full_name;
