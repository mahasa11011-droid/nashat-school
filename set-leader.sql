-- =============================================================
-- تعيين رائدة النشاط / Set the activity leader
--
-- استخدمي هذا الملف عند:
--   • إضافة رائدة النشاط لأول مرة بعد تشغيل schema.sql
--   • تغيير الرائدة في بداية عام دراسي جديد
--   • تصحيح حساب أُضيف بالخطأ
--
-- آمن للتشغيل أكثر من مرة: يستبدل القائمة بالكامل في كل تشغيل،
-- ولا يغيّر شيئًا إطلاقًا إذا لم يجد البريد المطلوب.
--
-- Safe to re-run: it replaces the allow-list on every run, and changes
-- nothing at all if the email does not match an account.
-- =============================================================


-- -------------------------------------------------------------
-- الخطوة ١: اعرفي الحسابات الموجودة
--
-- شغّلي هذا الاستعلام وحده أولًا (حدّديه ثم Run)، وانسخي البريد
-- الذي تريدين الدخول به. لا تحتاجين إلى نسخ الـ UUID إطلاقًا.
-- -------------------------------------------------------------
-- select id as user_uid, email, created_at
-- from auth.users
-- order by created_at;


-- -------------------------------------------------------------
-- الخطوة ٢: ضعي البريد في السطر المُعلَّم أدناه، ثم شغّلي الملف كاملًا
-- -------------------------------------------------------------
do $$
declare
  leader_email text := 'PUT-THE-EMAIL-HERE';   -- ←←← التعديل الوحيد المطلوب
  uid uuid;
begin
  -- شبكة أمان: لو لم يكن schema.sql قد شُغّل بعد، ننشئ الجدول هنا.
  -- ملاحظة: هذا لا يغني عن schema.sql، فسياسات الحماية (RLS) هناك.
  create table if not exists leaders (
    user_id  uuid primary key references auth.users(id) on delete cascade,
    added_at timestamptz not null default now(),
    note     text
  );

  select id into uid
  from auth.users
  where lower(email) = lower(trim(leader_email));

  if uid is null then
    raise exception
      'لا يوجد حساب بهذا البريد: %. راجعي Authentication → Users وانسخيه كما هو.',
      leader_email;
  end if;

  -- نمسح القائمة أولًا حتى لا يبقى حساب قديم أو خاطئ مخوّلًا
  delete from leaders;
  insert into leaders (user_id, note) values (uid, 'رائدة النشاط');
end $$;


-- -------------------------------------------------------------
-- الخطوة ٣: التحقق
--
-- يجب أن يظهر صف واحد فقط، ببريد الرائدة الصحيحة.
-- صفر صفوف = لم يُضَف أحد. أكثر من صف = شيء غير متوقع، أعيدي التشغيل.
-- -------------------------------------------------------------
select u.email, l.user_id, l.added_at
from leaders l
join auth.users u on u.id = l.user_id
order by l.added_at;


-- -------------------------------------------------------------
-- بعد ذلك / Afterwards
--
-- ١. حذف حساب أُضيف بالخطأ:
--    Authentication → Users → الصف → Delete user
--    (صفّه في leaders يُحذف تلقائيًا بفضل on delete cascade)
--
-- ٢. تغيير كلمة المرور:
--    Authentication → Users → الصف → Reset password
--    كلمات المرور مخزّنة مشفّرة تشفيرًا أحاديًا، فلا يمكن استرجاع
--    كلمة مرور قديمة — يمكن تعيين واحدة جديدة فقط.
--
-- ٣. تأكّدي أن schema.sql قد شُغّل، وأن التسجيل الذاتي مغلق:
--    Authentication → Sign In / Providers → Email
--      → Allow new users to sign up = OFF
-- -------------------------------------------------------------
