-- Migration: 20261120154000_phase2_family_health_permissions.sql
-- Description: Phase 2 Granular Health Sharing - FamilyHealthPermissions table, RLS policies, authorization helper, and conservative migration seeding.

BEGIN;

-- ============================================================================
-- 1. CREATE FamilyHealthPermissions TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public."FamilyHealthPermissions" (
    "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "familyId" UUID NOT NULL REFERENCES public."Families"("familyId") ON DELETE CASCADE,
    "ownerProfileId" UUID NOT NULL REFERENCES public."Profiles"("profileId") ON DELETE CASCADE,
    "viewerProfileId" UUID NOT NULL REFERENCES public."Profiles"("profileId") ON DELETE CASCADE,
    "metricType" TEXT NOT NULL,
    "permissionLevel" TEXT NOT NULL DEFAULT 'summary_only',
    "isAllowed" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMPTZ NOT NULL DEFAULT now(),
    "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT now(),
    "expiresAt" TIMESTAMPTZ NULL,

    CONSTRAINT "familyhealthpermissions_owner_diff_viewer" CHECK ("ownerProfileId" != "viewerProfileId"),
    CONSTRAINT "familyhealthpermissions_metric_check" CHECK ("metricType" IN ('steps', 'calories', 'distance', 'heartRate', 'restingHeartRate', 'heart_rate', 'hrv', 'sleep', 'summary')),
    CONSTRAINT "familyhealthpermissions_level_check" CHECK ("permissionLevel" IN ('none', 'summary_only', 'full_detail')),
    CONSTRAINT "familyhealthpermissions_unique_grant" UNIQUE ("ownerProfileId", "viewerProfileId", "metricType")
);

-- Indexes for fast RLS lookups
CREATE INDEX IF NOT EXISTS "idx_health_perms_owner_metric" ON public."FamilyHealthPermissions" ("ownerProfileId", "metricType");
CREATE INDEX IF NOT EXISTS "idx_health_perms_viewer_metric" ON public."FamilyHealthPermissions" ("viewerProfileId", "metricType");
CREATE INDEX IF NOT EXISTS "idx_health_perms_family" ON public."FamilyHealthPermissions" ("familyId");

-- Enable Row Level Security
ALTER TABLE public."FamilyHealthPermissions" ENABLE ROW LEVEL SECURITY;

-- Drop old policies if they exist
DROP POLICY IF EXISTS "health_perms_select_owner_or_viewer" ON public."FamilyHealthPermissions";
DROP POLICY IF EXISTS "health_perms_insert_owner" ON public."FamilyHealthPermissions";
DROP POLICY IF EXISTS "health_perms_update_owner" ON public."FamilyHealthPermissions";
DROP POLICY IF EXISTS "health_perms_delete_owner" ON public."FamilyHealthPermissions";

-- Policy 1: Both owner and viewer can inspect permission records
CREATE POLICY "health_perms_select_owner_or_viewer"
ON public."FamilyHealthPermissions"
FOR SELECT
TO authenticated
USING (
    "ownerProfileId" = (SELECT auth.uid())
    OR "viewerProfileId" = (SELECT auth.uid())
);

-- Policy 2: Only owner can grant/insert permissions for their family members
CREATE POLICY "health_perms_insert_owner"
ON public."FamilyHealthPermissions"
FOR INSERT
TO authenticated
WITH CHECK (
    "ownerProfileId" = (SELECT auth.uid())
    AND "familyId" = (SELECT auth_family_id())
    AND is_family_member("viewerProfileId")
);

-- Policy 3: Only owner can update permissions
CREATE POLICY "health_perms_update_owner"
ON public."FamilyHealthPermissions"
FOR UPDATE
TO authenticated
USING ("ownerProfileId" = (SELECT auth.uid()))
WITH CHECK ("ownerProfileId" = (SELECT auth.uid()));

-- Policy 4: Only owner can delete/revoke permissions
CREATE POLICY "health_perms_delete_owner"
ON public."FamilyHealthPermissions"
FOR DELETE
TO authenticated
USING ("ownerProfileId" = (SELECT auth.uid()));


-- ============================================================================
-- 2. CREATE has_health_permission AUTHORIZATION FUNCTION
-- ============================================================================

CREATE OR REPLACE FUNCTION public.has_health_permission(
    target_owner_id UUID,
    metric TEXT,
    required_level TEXT DEFAULT 'summary_only'
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT (
        -- User can always access their own data
        target_owner_id = (SELECT auth.uid())
        OR EXISTS (
            SELECT 1
            FROM public."FamilyHealthPermissions" p
            WHERE p."ownerProfileId" = target_owner_id
              AND p."viewerProfileId" = (SELECT auth.uid())
              AND (
                  p."metricType" = metric
                  OR (metric IN ('heartRate', 'restingHeartRate') AND p."metricType" IN ('heartRate', 'heart_rate'))
              )
              AND p."isAllowed" = true
              AND (p."expiresAt" IS NULL OR p."expiresAt" > now())
              AND (
                  required_level = 'none'
                  OR (required_level = 'summary_only' AND p."permissionLevel" IN ('summary_only', 'full_detail'))
                  OR (required_level = 'full_detail' AND p."permissionLevel" = 'full_detail')
              )
        )
    );
$$;

REVOKE ALL ON FUNCTION public.has_health_permission(UUID, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.has_health_permission(UUID, TEXT, TEXT) TO authenticated, service_role;


-- ============================================================================
-- 3. HARDEN RLS ON HEALTH TABLES TO ENFORCE PERMISSIONS
-- ============================================================================

-- 3A. Health_ActivityDaily
DROP POLICY IF EXISTS "actdaily_select_family" ON public."Health_ActivityDaily";
DROP POLICY IF EXISTS "actdaily_select_permission" ON public."Health_ActivityDaily";

CREATE POLICY "actdaily_select_permission"
ON public."Health_ActivityDaily"
FOR SELECT
TO authenticated
USING (
    "profileId" = (SELECT auth.uid())
    OR has_health_permission("profileId", "type", 'summary_only')
    OR has_health_permission("profileId", 'summary', 'summary_only')
);

-- 3B. Health_SleepDaily
DROP POLICY IF EXISTS "sleepdaily_select_family" ON public."Health_SleepDaily";
DROP POLICY IF EXISTS "sleepdaily_select_permission" ON public."Health_SleepDaily";

CREATE POLICY "sleepdaily_select_permission"
ON public."Health_SleepDaily"
FOR SELECT
TO authenticated
USING (
    "profileId" = (SELECT auth.uid())
    OR has_health_permission("profileId", 'sleep', 'summary_only')
);

-- 3C. Health_VitalsDaily
DROP POLICY IF EXISTS "vitdaily_select_family" ON public."Health_VitalsDaily";
DROP POLICY IF EXISTS "vitdaily_select_permission" ON public."Health_VitalsDaily";

CREATE POLICY "vitdaily_select_permission"
ON public."Health_VitalsDaily"
FOR SELECT
TO authenticated
USING (
    "profileId" = (SELECT auth.uid())
    OR has_health_permission("profileId", "type", 'summary_only')
);

-- 3D. Health_ActivityHourly (Raw hourly data is private to the owner)
DROP POLICY IF EXISTS "acthourly_select_family" ON public."Health_ActivityHourly";
DROP POLICY IF EXISTS "acthourly_select_owner_only" ON public."Health_ActivityHourly";

CREATE POLICY "acthourly_select_owner_only"
ON public."Health_ActivityHourly"
FOR SELECT
TO authenticated
USING ("profileId" = (SELECT auth.uid()));

-- 3E. Health_VitalsHourly (Raw hourly vitals are private to the owner)
DROP POLICY IF EXISTS "vithourly_select_family" ON public."Health_VitalsHourly";
DROP POLICY IF EXISTS "vithourly_select_owner_only" ON public."Health_VitalsHourly";

CREATE POLICY "vithourly_select_owner_only"
ON public."Health_VitalsHourly"
FOR SELECT
TO authenticated
USING ("profileId" = (SELECT auth.uid()));


-- ============================================================================
-- 4. CONSERVATIVE INITIAL SEEDING FOR EXISTING ACTIVE FAMILIES
-- ============================================================================

INSERT INTO public."FamilyHealthPermissions" (
    "familyId",
    "ownerProfileId",
    "viewerProfileId",
    "metricType",
    "permissionLevel",
    "isAllowed"
)
SELECT
    m1."familyId",
    m1."profileId" AS "ownerProfileId",
    m2."profileId" AS "viewerProfileId",
    metric.val AS "metricType",
    CASE
        WHEN metric.val IN ('summary', 'steps', 'calories', 'distance') THEN 'summary_only'
        ELSE 'none'
    END AS "permissionLevel",
    CASE
        WHEN metric.val IN ('summary', 'steps', 'calories', 'distance') THEN true
        ELSE false
    END AS "isAllowed"
FROM public."Profiles" m1
JOIN public."Profiles" m2 ON m1."familyId" = m2."familyId" AND m1."profileId" != m2."profileId"
CROSS JOIN (
    VALUES
        ('summary'),
        ('steps'),
        ('calories'),
        ('distance'),
        ('heartRate'),
        ('hrv'),
        ('sleep')
) AS metric(val)
WHERE m1."familyId" IS NOT NULL
ON CONFLICT ("ownerProfileId", "viewerProfileId", "metricType") DO NOTHING;

COMMIT;
