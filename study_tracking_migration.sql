-- Çalışma takibi geliştirmesi: hedef, tarih, net ve öğretmen notu
alter table public.study_records
  add column if not exists target_questions integer,
  add column if not exists teacher_note text,
  add column if not exists recorded_on date default current_date,
  add column if not exists net numeric(7,2);

alter table public.study_records
  drop constraint if exists study_records_target_questions_nonnegative;

alter table public.study_records
  add constraint study_records_target_questions_nonnegative
  check (target_questions is null or target_questions >= 0);

alter table public.study_records
  drop constraint if exists study_records_question_counts_nonnegative;

alter table public.study_records
  add constraint study_records_question_counts_nonnegative
  check (
    total_questions >= 0 and correct >= 0 and wrong >= 0 and blank >= 0
    and correct + wrong + blank = total_questions
  );
