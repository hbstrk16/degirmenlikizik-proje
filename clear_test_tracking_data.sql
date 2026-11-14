-- DENEME VERİLERİNİ TEMİZLEME
-- Kullanıcı onayıyla yalnızca aşağıdaki dört kayıt grubu temizlenir.
-- Öğrenci listesi, sınıflar, deneme sınavı sonuçları ve hedefler korunur.
-- Supabase SQL Editor'da çalıştırın.

begin;

delete from public.study_records;
delete from public.reading_records;
delete from public.saturday_lesson_ratings;
delete from public.attendance_records;

commit;

-- Kontrol: Dört tabloda da kayıt sayısı 0 olmalı.
select 'study_records' as tablo, count(*) as kalan_kayit from public.study_records
union all
select 'reading_records', count(*) from public.reading_records
union all
select 'saturday_lesson_ratings', count(*) from public.saturday_lesson_ratings
union all
select 'attendance_records', count(*) from public.attendance_records;
