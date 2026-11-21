-- Rollback Migration: 20261120153000_phase1_security_hardening_rollback.sql
-- Description: Reverts Phase 1 security hardening back to the initial baseline state.

BEGIN;

-- ============================================================================
-- 1. ROLLBACK NOTIFICATIONS TABLE POLICIES
-- ============================================================================
DROP POLICY IF EXISTS "notifications_select_recipient" ON public."Notifications";
DROP POLICY IF EXISTS "notifications_insert_authorized" ON public."Notifications";
DROP POLICY IF EXISTS "notifications_update_recipient" ON public."Notifications";
DROP POLICY IF EXISTS "notifications_delete_recipient" ON public."Notifications";

CREATE POLICY "Users can read own family notifications" ON public."Notifications"
FOR SELECT TO public USING (true);

CREATE POLICY "Users can insert notifications" ON public."Notifications"
FOR INSERT TO public WITH CHECK (true);

CREATE POLICY "Users can update notifications" ON public."Notifications"
FOR UPDATE TO public USING (true);

CREATE POLICY "Users can delete notifications" ON public."Notifications"
FOR DELETE TO public USING (true);


-- ============================================================================
-- 2. ROLLBACK STORAGE (AVATARS BUCKET) POLICIES
-- ============================================================================
DROP POLICY IF EXISTS "avatars_select_public" ON storage.objects;
DROP POLICY IF EXISTS "avatars_insert_owner" ON storage.objects;
DROP POLICY IF EXISTS "avatars_update_owner" ON storage.objects;
DROP POLICY IF EXISTS "avatars_delete_owner" ON storage.objects;

CREATE POLICY "Anyone can delete avatars." ON storage.objects
FOR DELETE TO public USING (bucket_id = 'avatars'::text);

CREATE POLICY "Anyone can update avatars." ON storage.objects
FOR UPDATE TO public USING (bucket_id = 'avatars'::text);

CREATE POLICY "Anyone can upload avatars." ON storage.objects
FOR INSERT TO public WITH CHECK (bucket_id = 'avatars'::text);

CREATE POLICY "Avatars are publicly accessible." ON storage.objects
FOR SELECT TO public USING (bucket_id = 'avatars'::text);

UPDATE storage.buckets
SET
    file_size_limit = NULL,
    allowed_mime_types = NULL
WHERE id = 'avatars';


-- ============================================================================
-- 3. ROLLBACK PING_LOGS TABLE POLICIES
-- ============================================================================
DROP POLICY IF EXISTS "ping_logs_service_role_only" ON public.ping_logs;

CREATE POLICY "Allow all" ON public.ping_logs
FOR ALL TO public USING (true) WITH CHECK (true);

COMMIT;
