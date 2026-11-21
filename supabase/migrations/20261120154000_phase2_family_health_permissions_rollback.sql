-- Rollback Migration: 20261120154000_phase2_family_health_permissions_rollback.sql
-- Description: Reverts Phase 2 Granular Health Sharing back to Phase 1 state.

BEGIN;

-- 1. Revert Health Tables policies back to family-based access
DROP POLICY IF EXISTS "actdaily_select_permission" ON public."Health_ActivityDaily";
CREATE POLICY "actdaily_select_family" ON public."Health_ActivityDaily"
FOR SELECT TO authenticated USING (is_family_member("profileId"));

DROP POLICY IF EXISTS "sleepdaily_select_permission" ON public."Health_SleepDaily";
CREATE POLICY "sleepdaily_select_family" ON public."Health_SleepDaily"
FOR SELECT TO authenticated USING (is_family_member("profileId"));

DROP POLICY IF EXISTS "vitdaily_select_permission" ON public."Health_VitalsDaily";
CREATE POLICY "vitdaily_select_family" ON public."Health_VitalsDaily"
FOR SELECT TO authenticated USING (is_family_member("profileId"));

DROP POLICY IF EXISTS "acthourly_select_owner_only" ON public."Health_ActivityHourly";
CREATE POLICY "acthourly_select_family" ON public."Health_ActivityHourly"
FOR SELECT TO authenticated USING (is_family_member("profileId"));

DROP POLICY IF EXISTS "vithourly_select_owner_only" ON public."Health_VitalsHourly";
CREATE POLICY "vithourly_select_family" ON public."Health_VitalsHourly"
FOR SELECT TO authenticated USING (is_family_member("profileId"));

-- 2. Drop authorization function
DROP FUNCTION IF EXISTS public.has_health_permission(UUID, TEXT, TEXT);

-- 3. Drop FamilyHealthPermissions table
DROP TABLE IF EXISTS public."FamilyHealthPermissions" CASCADE;

COMMIT;
