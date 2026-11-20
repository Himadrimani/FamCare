-- Migration: 20261120153000_phase1_security_hardening.sql
-- Description: Phase 1 Security Hardening - Remediate unauthenticated access on Notifications, avatars bucket, and ping_logs.
-- Target Tables: public."Notifications", storage.objects, storage.buckets, public.ping_logs

BEGIN;

-- ============================================================================
-- 1. NOTIFICATIONS TABLE SECURITY HARDENING
-- ============================================================================

-- Ensure Row Level Security is enabled
ALTER TABLE public."Notifications" ENABLE ROW LEVEL SECURITY;

-- Drop insecure, wide-open public policies
DROP POLICY IF EXISTS "Users can read own family notifications" ON public."Notifications";
DROP POLICY IF EXISTS "Users can insert notifications" ON public."Notifications";
DROP POLICY IF EXISTS "Users can update notifications" ON public."Notifications";
DROP POLICY IF EXISTS "Users can delete notifications" ON public."Notifications";
DROP POLICY IF EXISTS "notifications_select_recipient" ON public."Notifications";
DROP POLICY IF EXISTS "notifications_insert_authorized" ON public."Notifications";
DROP POLICY IF EXISTS "notifications_update_recipient" ON public."Notifications";
DROP POLICY IF EXISTS "notifications_delete_recipient" ON public."Notifications";

-- Policy 1: Authenticated users can only read notifications addressed to them
CREATE POLICY "notifications_select_recipient"
ON public."Notifications"
FOR SELECT
TO authenticated
USING ("recipientProfileId" = (SELECT auth.uid()));

-- Policy 2: Authenticated users can insert notifications only within their family
CREATE POLICY "notifications_insert_authorized"
ON public."Notifications"
FOR INSERT
TO authenticated
WITH CHECK (
    "familyId" = (SELECT auth_family_id())
    AND (
        "recipientProfileId" = (SELECT auth.uid())
        OR is_family_member("recipientProfileId")
    )
);

-- Policy 3: Authenticated users can only update notifications addressed to them
CREATE POLICY "notifications_update_recipient"
ON public."Notifications"
FOR UPDATE
TO authenticated
USING ("recipientProfileId" = (SELECT auth.uid()))
WITH CHECK ("recipientProfileId" = (SELECT auth.uid()));

-- Policy 4: Authenticated users can only delete notifications addressed to them
CREATE POLICY "notifications_delete_recipient"
ON public."Notifications"
FOR DELETE
TO authenticated
USING ("recipientProfileId" = (SELECT auth.uid()));


-- ============================================================================
-- 2. STORAGE (AVATARS BUCKET) SECURITY HARDENING
-- ============================================================================

-- Drop insecure public mutation policies
DROP POLICY IF EXISTS "Anyone can upload avatars." ON storage.objects;
DROP POLICY IF EXISTS "Anyone can update avatars." ON storage.objects;
DROP POLICY IF EXISTS "Anyone can delete avatars." ON storage.objects;
DROP POLICY IF EXISTS "Avatars are publicly accessible." ON storage.objects;
DROP POLICY IF EXISTS "avatars_select_public" ON storage.objects;
DROP POLICY IF EXISTS "avatars_insert_owner" ON storage.objects;
DROP POLICY IF EXISTS "avatars_update_owner" ON storage.objects;
DROP POLICY IF EXISTS "avatars_delete_owner" ON storage.objects;

-- Policy 1: Public read access for avatars (allows family members to see profile pictures)
CREATE POLICY "avatars_select_public"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'avatars');

-- Policy 2: Authenticated users can only upload avatar files prefixed with their profileId/auth.uid()
CREATE POLICY "avatars_insert_owner"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'avatars'
    AND (
        lower(split_part(name, '_', 1)) = (SELECT auth.uid())::text
        OR (storage.foldername(name))[1] = (SELECT auth.uid())::text
        OR owner = (SELECT auth.uid())
        OR owner_id = (SELECT auth.uid())::text
    )
);

-- Policy 3: Authenticated users can only update their own avatar files
CREATE POLICY "avatars_update_owner"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
    bucket_id = 'avatars'
    AND (
        lower(split_part(name, '_', 1)) = (SELECT auth.uid())::text
        OR (storage.foldername(name))[1] = (SELECT auth.uid())::text
        OR owner = (SELECT auth.uid())
        OR owner_id = (SELECT auth.uid())::text
    )
)
WITH CHECK (
    bucket_id = 'avatars'
    AND (
        lower(split_part(name, '_', 1)) = (SELECT auth.uid())::text
        OR (storage.foldername(name))[1] = (SELECT auth.uid())::text
        OR owner = (SELECT auth.uid())
        OR owner_id = (SELECT auth.uid())::text
    )
);

-- Policy 4: Authenticated users can only delete their own avatar files
CREATE POLICY "avatars_delete_owner"
ON storage.objects
FOR DELETE
TO authenticated
USING (
    bucket_id = 'avatars'
    AND (
        lower(split_part(name, '_', 1)) = (SELECT auth.uid())::text
        OR (storage.foldername(name))[1] = (SELECT auth.uid())::text
        OR owner = (SELECT auth.uid())
        OR owner_id = (SELECT auth.uid())::text
    )
);

-- Configure bucket limits: Max 5MB, JPEG/PNG/WEBP only
UPDATE storage.buckets
SET
    file_size_limit = 5242880,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp']
WHERE id = 'avatars';


-- ============================================================================
-- 3. PING_LOGS TABLE SECURITY HARDENING
-- ============================================================================

-- Ensure RLS is active
ALTER TABLE public.ping_logs ENABLE ROW LEVEL SECURITY;

-- Drop the wide-open "Allow all" policy
DROP POLICY IF EXISTS "Allow all" ON public.ping_logs;
DROP POLICY IF EXISTS "ping_logs_service_role_only" ON public.ping_logs;

-- Restrict all access exclusively to the service_role (prevent anonymous/public tampering)
CREATE POLICY "ping_logs_service_role_only"
ON public.ping_logs
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

COMMIT;
