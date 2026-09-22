-- wideget-core: empty faithful mirror of castfolio TALENT-AGENCY (Prisma) app
-- (source castfolio schema) into wideget-core schema `castfolio_agency`.
-- Source: castfolio project (vrbawgqrhigtkyiengkm). Applied to wideget-core
-- (ossqwphalaxhmadmffsn) 2026-07-08 via MCP. DATA EXCLUDED.
-- This app integrates Supabase Auth via User.supabaseUid (unique). RLS is ENABLED on
-- every table with service_role-only access for now; per-table authenticated policies
-- (anchored on castfolio_agency."User".supabaseUid = auth.uid()::text and ownership
-- chains via userId/projectId/orderId/...) are to be defined at app onboarding.

create schema if not exists castfolio_agency;
grant usage on schema castfolio_agency to authenticated, anon, service_role;

-- Enums (idempotent)
do $$ begin create type castfolio_agency."AccountStatus" as enum ('ACTIVE','SUSPENDED','DELETED'); exception when duplicate_object then null; end $$;
do $$ begin create type castfolio_agency."DataEnteredBy" as enum ('TALENT','USER','BOTH'); exception when duplicate_object then null; end $$;
do $$ begin create type castfolio_agency."IntakeMode" as enum ('SELF_SUBMISSION','OPERATOR_ENTRY','HYBRID'); exception when duplicate_object then null; end $$;
do $$ begin create type castfolio_agency."MediaType" as enum ('HERO_PHOTO','PROFILE_PHOTO','PORTFOLIO_PHOTO','AUDIO_SAMPLE','OTHER'); exception when duplicate_object then null; end $$;
do $$ begin create type castfolio_agency."NotificationChannel" as enum ('DASHBOARD','EMAIL'); exception when duplicate_object then null; end $$;
do $$ begin create type castfolio_agency."OrderStatus" as enum ('DRAFT','PAYMENT_PENDING','PAID','DELIVERED','SETTLED','CANCELLED','DISPUTED','REFUNDED'); exception when duplicate_object then null; end $$;
do $$ begin create type castfolio_agency."PageStatus" as enum ('DRAFT','PREVIEW','PUBLISHED','INACTIVE'); exception when duplicate_object then null; end $$;
do $$ begin create type castfolio_agency."PaymentMethod" as enum ('ONLINE_CARD','ONLINE_KAKAO','ONLINE_NAVER','ONLINE_TRANSFER','OFFLINE_CASH','OFFLINE_TRANSFER','OFFLINE_OTHER'); exception when duplicate_object then null; end $$;
do $$ begin create type castfolio_agency."ProjectStatus" as enum ('NEW','COLLECTING_MATERIALS','DRAFTING','UNDER_REVIEW','READY_FOR_DELIVERY','DELIVERED','CLOSED','DISPUTED'); exception when duplicate_object then null; end $$;
do $$ begin create type castfolio_agency."QuoteStatus" as enum ('DRAFT','SENT','EXPIRED','SUPERSEDED','ACCEPTED','REJECTED'); exception when duplicate_object then null; end $$;
do $$ begin create type castfolio_agency."SettlementStatus" as enum ('PENDING','COMPLETED','OVERDUE','CARRIED_OVER'); exception when duplicate_object then null; end $$;
do $$ begin create type castfolio_agency."SourceChannel" as enum ('KAKAO','EMAIL','PHONE','OFFLINE','UPLOAD_LINK','MIXED'); exception when duplicate_object then null; end $$;
do $$ begin create type castfolio_agency."SubmissionStatus" as enum ('PENDING','PARTIAL','COMPLETE'); exception when duplicate_object then null; end $$;
do $$ begin create type castfolio_agency."TalentStatus" as enum ('ACTIVE','INACTIVE','DELETED'); exception when duplicate_object then null; end $$;
do $$ begin create type castfolio_agency."UserRole" as enum ('MASTER_ADMIN','USER'); exception when duplicate_object then null; end $$;
do $$ begin create type castfolio_agency."UserType" as enum ('INDIVIDUAL','SOLE_PROPRIETOR','CORPORATION'); exception when duplicate_object then null; end $$;
do $$ begin create type castfolio_agency."VerificationStatus" as enum ('NOT_REQUESTED','REQUESTED','APPROVED','REVISION_REQUESTED'); exception when duplicate_object then null; end $$;

-- Tables (FK dependency order). All PKs are text (Prisma cuid).
create table if not exists castfolio_agency."User" (
  "id" text not null, "email" text not null, "name" text not null,
  "role" castfolio_agency."UserRole" not null default 'USER'::castfolio_agency."UserRole",
  "userType" castfolio_agency."UserType", "company" text, "phone" text,
  "commissionRate" numeric(65,30) not null default 0.15,
  "status" castfolio_agency."AccountStatus" not null default 'ACTIVE'::castfolio_agency."AccountStatus",
  "supabaseUid" text not null, "brandLogoUrl" text, "brandColor" text,
  "createdAt" timestamp(3) not null default CURRENT_TIMESTAMP, "updatedAt" timestamp(3) not null,
  constraint "User_pkey" primary key ("id")
);
create table if not exists castfolio_agency."NotificationTemplate" (
  "id" text not null, "type" text not null, "titleKo" text not null, "titleEn" text not null, "titleCn" text,
  "bodyKo" text not null, "bodyEn" text not null, "bodyCn" text,
  "createdAt" timestamp(3) not null default CURRENT_TIMESTAMP, "updatedAt" timestamp(3) not null,
  constraint "NotificationTemplate_pkey" primary key ("id")
);
create table if not exists castfolio_agency."RiskFlag" (
  "id" text not null, "targetType" text not null, "targetId" text not null, "reason" text not null,
  "severity" text not null, "resolvedAt" timestamp(3), "resolvedBy" text,
  "createdAt" timestamp(3) not null default CURRENT_TIMESTAMP,
  constraint "RiskFlag_pkey" primary key ("id")
);
create table if not exists castfolio_agency."Talent" (
  "id" text not null, "userId" text not null, "nameKo" text not null, "nameEn" text not null, "nameCn" text,
  "email" text, "phone" text, "kakaoId" text, "position" text not null,
  "status" castfolio_agency."TalentStatus" not null default 'ACTIVE'::castfolio_agency."TalentStatus",
  "createdAt" timestamp(3) not null default CURRENT_TIMESTAMP, "updatedAt" timestamp(3) not null,
  constraint "Talent_pkey" primary key ("id"),
  constraint "Talent_userId_fkey" foreign key ("userId") references castfolio_agency."User"("id") on update cascade on delete restrict
);
create table if not exists castfolio_agency."ProductPackage" (
  "id" text not null, "userId" text not null, "name" text not null, "description" text,
  "isTemplate" boolean not null default false, "isActive" boolean not null default true,
  "sortOrder" integer not null default 0,
  "createdAt" timestamp(3) not null default CURRENT_TIMESTAMP, "updatedAt" timestamp(3) not null,
  constraint "ProductPackage_pkey" primary key ("id"),
  constraint "ProductPackage_userId_fkey" foreign key ("userId") references castfolio_agency."User"("id") on update cascade on delete restrict
);
create table if not exists castfolio_agency."SettlementBatch" (
  "id" text not null, "userId" text not null, "periodStart" timestamp(3) not null, "periodEnd" timestamp(3) not null,
  "totalSales" numeric(65,30) not null, "totalCommission" numeric(65,30) not null, "totalUserAmount" numeric(65,30) not null,
  "status" castfolio_agency."SettlementStatus" not null default 'PENDING'::castfolio_agency."SettlementStatus",
  "minimumMet" boolean not null default true, "completedAt" timestamp(3),
  "createdAt" timestamp(3) not null default CURRENT_TIMESTAMP,
  constraint "SettlementBatch_pkey" primary key ("id"),
  constraint "SettlementBatch_userId_fkey" foreign key ("userId") references castfolio_agency."User"("id") on update cascade on delete restrict
);
create table if not exists castfolio_agency."AdminNote" (
  "id" text not null, "authorId" text not null, "targetType" text not null, "targetId" text not null,
  "note" text not null, "isInternal" boolean not null default true,
  "createdAt" timestamp(3) not null default CURRENT_TIMESTAMP,
  constraint "AdminNote_pkey" primary key ("id"),
  constraint "AdminNote_authorId_fkey" foreign key ("authorId") references castfolio_agency."User"("id") on update cascade on delete restrict
);
create table if not exists castfolio_agency."AuditLog" (
  "id" text not null, "actorId" text not null, "actorRole" text not null, "action" text not null,
  "targetType" text not null, "targetId" text not null, "before" jsonb, "after" jsonb, "reason" text, "ipAddress" text,
  "createdAt" timestamp(3) not null default CURRENT_TIMESTAMP,
  constraint "AuditLog_pkey" primary key ("id"),
  constraint "AuditLog_actorId_fkey" foreign key ("actorId") references castfolio_agency."User"("id") on update cascade on delete restrict
);
create table if not exists castfolio_agency."Notification" (
  "id" text not null, "userId" text not null, "channel" castfolio_agency."NotificationChannel" not null,
  "type" text not null, "title" text not null, "body" text not null, "link" text,
  "isRead" boolean not null default false, "metadata" jsonb,
  "createdAt" timestamp(3) not null default CURRENT_TIMESTAMP,
  constraint "Notification_pkey" primary key ("id"),
  constraint "Notification_userId_fkey" foreign key ("userId") references castfolio_agency."User"("id") on update cascade on delete restrict
);
create table if not exists castfolio_agency."Project" (
  "id" text not null, "userId" text not null, "talentId" text not null, "name" text not null, "purpose" text,
  "status" castfolio_agency."ProjectStatus" not null default 'NEW'::castfolio_agency."ProjectStatus",
  "intakeMode" castfolio_agency."IntakeMode" not null default 'SELF_SUBMISSION'::castfolio_agency."IntakeMode",
  "sourceChannel" castfolio_agency."SourceChannel", "dataEnteredBy" castfolio_agency."DataEnteredBy",
  "verificationStatus" castfolio_agency."VerificationStatus" not null default 'NOT_REQUESTED'::castfolio_agency."VerificationStatus",
  "verifiedAt" timestamp(3), "createdAt" timestamp(3) not null default CURRENT_TIMESTAMP, "updatedAt" timestamp(3) not null,
  constraint "Project_pkey" primary key ("id"),
  constraint "Project_userId_fkey" foreign key ("userId") references castfolio_agency."User"("id") on update cascade on delete restrict,
  constraint "Project_talentId_fkey" foreign key ("talentId") references castfolio_agency."Talent"("id") on update cascade on delete restrict
);
create table if not exists castfolio_agency."PricingChangeLog" (
  "id" text not null, "userId" text not null, "packageId" text not null, "field" text not null,
  "oldValue" text not null, "newValue" text not null, "reason" text,
  "createdAt" timestamp(3) not null default CURRENT_TIMESTAMP,
  constraint "PricingChangeLog_pkey" primary key ("id"),
  constraint "PricingChangeLog_userId_fkey" foreign key ("userId") references castfolio_agency."User"("id") on update cascade on delete restrict,
  constraint "PricingChangeLog_packageId_fkey" foreign key ("packageId") references castfolio_agency."ProductPackage"("id") on update cascade on delete restrict
);
create table if not exists castfolio_agency."PricingPolicyVersion" (
  "id" text not null, "packageId" text not null, "versionNumber" integer not null, "basePrice" numeric(65,30) not null,
  "promoPrice" numeric(65,30), "promoStartAt" timestamp(3), "promoEndAt" timestamp(3),
  "isActive" boolean not null default true, "options" jsonb, "changeSummary" text,
  "createdAt" timestamp(3) not null default CURRENT_TIMESTAMP,
  constraint "PricingPolicyVersion_pkey" primary key ("id"),
  constraint "PricingPolicyVersion_packageId_fkey" foreign key ("packageId") references castfolio_agency."ProductPackage"("id") on update cascade on delete restrict
);
create table if not exists castfolio_agency."RevisionPolicy" (
  "id" text not null, "packageId" text not null, "freeRevisions" integer not null default 0,
  "extraRevisionFee" numeric(65,30) not null default 0, "revisionWindowDays" integer not null default 14,
  "freeScope" jsonb, "paidScope" jsonb, "excludedScope" jsonb,
  "createdAt" timestamp(3) not null default CURRENT_TIMESTAMP, "updatedAt" timestamp(3) not null,
  constraint "RevisionPolicy_pkey" primary key ("id"),
  constraint "RevisionPolicy_packageId_fkey" foreign key ("packageId") references castfolio_agency."ProductPackage"("id") on update cascade on delete restrict
);
create table if not exists castfolio_agency."IntakeForm" (
  "id" text not null, "projectId" text not null, "talentId" text not null, "token" text not null,
  "expiresAt" timestamp(3), "customFields" jsonb, "createdAt" timestamp(3) not null default CURRENT_TIMESTAMP,
  constraint "IntakeForm_pkey" primary key ("id"),
  constraint "IntakeForm_projectId_fkey" foreign key ("projectId") references castfolio_agency."Project"("id") on update cascade on delete restrict,
  constraint "IntakeForm_talentId_fkey" foreign key ("talentId") references castfolio_agency."Talent"("id") on update cascade on delete restrict
);
create table if not exists castfolio_agency."IntakeSubmission" (
  "id" text not null, "formId" text not null, "data" jsonb not null, "submittedBy" text not null,
  "source" castfolio_agency."SourceChannel",
  "status" castfolio_agency."SubmissionStatus" not null default 'PENDING'::castfolio_agency."SubmissionStatus",
  "createdAt" timestamp(3) not null default CURRENT_TIMESTAMP,
  constraint "IntakeSubmission_pkey" primary key ("id"),
  constraint "IntakeSubmission_formId_fkey" foreign key ("formId") references castfolio_agency."IntakeForm"("id") on update cascade on delete restrict
);
create table if not exists castfolio_agency."MediaAsset" (
  "id" text not null, "projectId" text not null, "type" castfolio_agency."MediaType" not null,
  "originalUrl" text not null, "optimizedUrl" text, "thumbnailUrl" text, "fileName" text not null,
  "fileSize" integer not null, "mimeType" text not null, "width" integer, "height" integer, "uploadedBy" text not null,
  "createdAt" timestamp(3) not null default CURRENT_TIMESTAMP,
  constraint "MediaAsset_pkey" primary key ("id"),
  constraint "MediaAsset_projectId_fkey" foreign key ("projectId") references castfolio_agency."Project"("id") on update cascade on delete restrict
);
create table if not exists castfolio_agency."ProjectTimeline" (
  "id" text not null, "projectId" text not null, "event" text not null, "description" text not null,
  "actorId" text, "actorName" text, "metadata" jsonb, "createdAt" timestamp(3) not null default CURRENT_TIMESTAMP,
  constraint "ProjectTimeline_pkey" primary key ("id"),
  constraint "ProjectTimeline_projectId_fkey" foreign key ("projectId") references castfolio_agency."Project"("id") on update cascade on delete restrict
);
create table if not exists castfolio_agency."Page" (
  "id" text not null, "projectId" text not null, "slug" text not null, "previewToken" text not null,
  "theme" text not null, "accentColor" text,
  "status" castfolio_agency."PageStatus" not null default 'DRAFT'::castfolio_agency."PageStatus",
  "contentKo" jsonb not null default '{}'::jsonb, "contentEn" jsonb not null default '{}'::jsonb,
  "contentCn" jsonb not null default '{}'::jsonb, "draftContent" jsonb,
  "sectionOrder" text[] default ARRAY['hero'::text,'profile'::text,'career'::text,'portfolio'::text,'strength'::text,'contact'::text,'footer'::text],
  "disabledSections" text[] default ARRAY[]::text[], "noindex" boolean not null default true, "ogImageUrl" text,
  "showPhone" boolean not null default false, "emailBotProtect" boolean not null default true,
  "viewsCount" integer not null default 0, "publishedAt" timestamp(3),
  "createdAt" timestamp(3) not null default CURRENT_TIMESTAMP, "updatedAt" timestamp(3) not null,
  constraint "Page_pkey" primary key ("id"),
  constraint "Page_projectId_fkey" foreign key ("projectId") references castfolio_agency."Project"("id") on update cascade on delete restrict
);
create table if not exists castfolio_agency."PageVersion" (
  "id" text not null, "projectId" text not null, "versionName" text not null, "draftSnapshot" jsonb not null,
  "theme" text not null, "accentColor" text, "sectionOrder" text[], "savedBy" text not null, "reason" text,
  "createdAt" timestamp(3) not null default CURRENT_TIMESTAMP,
  constraint "PageVersion_pkey" primary key ("id"),
  constraint "PageVersion_projectId_fkey" foreign key ("projectId") references castfolio_agency."Project"("id") on update cascade on delete restrict
);
create table if not exists castfolio_agency."PageView" (
  "id" text not null, "pageId" text not null, "ipHash" text not null, "userAgent" text, "referrer" text, "country" text,
  "viewedAt" timestamp(3) not null default CURRENT_TIMESTAMP,
  constraint "PageView_pkey" primary key ("id"),
  constraint "PageView_pageId_fkey" foreign key ("pageId") references castfolio_agency."Page"("id") on update cascade on delete restrict
);
create table if not exists castfolio_agency."QRAsset" (
  "id" text not null, "pageId" text not null, "pngUrl" text, "svgUrl" text, "pdfUrl" text,
  "showPhoto" boolean not null default false, "nameDisplay" text not null,
  "createdAt" timestamp(3) not null default CURRENT_TIMESTAMP, "updatedAt" timestamp(3) not null,
  constraint "QRAsset_pkey" primary key ("id"),
  constraint "QRAsset_pageId_fkey" foreign key ("pageId") references castfolio_agency."Page"("id") on update cascade on delete restrict
);
create table if not exists castfolio_agency."Quote" (
  "id" text not null, "projectId" text not null, "userId" text not null, "token" text not null,
  "status" castfolio_agency."QuoteStatus" not null default 'DRAFT'::castfolio_agency."QuoteStatus",
  "totalAmount" numeric(65,30) not null, "validUntil" timestamp(3) not null, "message" text,
  "pricingSnapshot" jsonb not null, "sentAt" timestamp(3), "createdAt" timestamp(3) not null default CURRENT_TIMESTAMP,
  constraint "Quote_pkey" primary key ("id"),
  constraint "Quote_userId_fkey" foreign key ("userId") references castfolio_agency."User"("id") on update cascade on delete restrict,
  constraint "Quote_projectId_fkey" foreign key ("projectId") references castfolio_agency."Project"("id") on update cascade on delete restrict
);
create table if not exists castfolio_agency."QuoteLineItem" (
  "id" text not null, "quoteId" text not null, "packageId" text not null, "description" text not null,
  "amount" numeric(65,30) not null, "quantity" integer not null default 1,
  constraint "QuoteLineItem_pkey" primary key ("id"),
  constraint "QuoteLineItem_packageId_fkey" foreign key ("packageId") references castfolio_agency."ProductPackage"("id") on update cascade on delete restrict,
  constraint "QuoteLineItem_quoteId_fkey" foreign key ("quoteId") references castfolio_agency."Quote"("id") on update cascade on delete restrict
);
create table if not exists castfolio_agency."Order" (
  "id" text not null, "quoteId" text, "projectId" text not null, "userId" text not null, "orderNumber" text not null,
  "status" castfolio_agency."OrderStatus" not null default 'DRAFT'::castfolio_agency."OrderStatus",
  "totalAmount" numeric(65,30) not null, "commissionRate" numeric(65,30) not null,
  "commissionAmount" numeric(65,30) not null, "userAmount" numeric(65,30) not null,
  "paymentMethod" castfolio_agency."PaymentMethod", "paymentProofUrl" text, "paidAt" timestamp(3),
  "pricingSnapshot" jsonb not null, "revisionSnapshot" jsonb, "deliveredAt" timestamp(3), "settledAt" timestamp(3),
  "createdAt" timestamp(3) not null default CURRENT_TIMESTAMP, "updatedAt" timestamp(3) not null,
  constraint "Order_pkey" primary key ("id"),
  constraint "Order_projectId_fkey" foreign key ("projectId") references castfolio_agency."Project"("id") on update cascade on delete restrict,
  constraint "Order_userId_fkey" foreign key ("userId") references castfolio_agency."User"("id") on update cascade on delete restrict,
  constraint "Order_quoteId_fkey" foreign key ("quoteId") references castfolio_agency."Quote"("id") on update cascade on delete set null
);
create table if not exists castfolio_agency."OrderLineItem" (
  "id" text not null, "orderId" text not null, "description" text not null, "amount" numeric(65,30) not null,
  "quantity" integer not null default 1, "type" text not null,
  constraint "OrderLineItem_pkey" primary key ("id"),
  constraint "OrderLineItem_orderId_fkey" foreign key ("orderId") references castfolio_agency."Order"("id") on update cascade on delete restrict
);
create table if not exists castfolio_agency."CommissionLedger" (
  "id" text not null, "orderId" text not null, "userId" text not null, "settlementId" text,
  "orderAmount" numeric(65,30) not null, "commissionRate" numeric(65,30) not null,
  "commissionAmount" numeric(65,30) not null, "userAmount" numeric(65,30) not null, "type" text not null,
  "createdAt" timestamp(3) not null default CURRENT_TIMESTAMP,
  constraint "CommissionLedger_pkey" primary key ("id"),
  constraint "CommissionLedger_orderId_fkey" foreign key ("orderId") references castfolio_agency."Order"("id") on update cascade on delete restrict,
  constraint "CommissionLedger_userId_fkey" foreign key ("userId") references castfolio_agency."User"("id") on update cascade on delete restrict,
  constraint "CommissionLedger_settlementId_fkey" foreign key ("settlementId") references castfolio_agency."SettlementBatch"("id") on update cascade on delete set null
);
create table if not exists castfolio_agency."PaymentRecord" (
  "id" text not null, "orderId" text not null, "amount" numeric(65,30) not null,
  "method" castfolio_agency."PaymentMethod" not null, "pgTxId" text, "status" text not null, "proofUrl" text,
  "createdAt" timestamp(3) not null default CURRENT_TIMESTAMP,
  constraint "PaymentRecord_pkey" primary key ("id"),
  constraint "PaymentRecord_orderId_fkey" foreign key ("orderId") references castfolio_agency."Order"("id") on update cascade on delete restrict
);
create table if not exists castfolio_agency."RefundRecord" (
  "id" text not null, "orderId" text not null, "amount" numeric(65,30) not null, "reason" text not null,
  "refundedCommission" numeric(65,30) not null, "status" text not null, "processedBy" text,
  "createdAt" timestamp(3) not null default CURRENT_TIMESTAMP,
  constraint "RefundRecord_pkey" primary key ("id"),
  constraint "RefundRecord_orderId_fkey" foreign key ("orderId") references castfolio_agency."Order"("id") on update cascade on delete restrict
);

-- Unique indexes (Prisma @unique / @@unique)
create unique index if not exists "IntakeForm_token_key" on castfolio_agency."IntakeForm" (token);
create unique index if not exists "NotificationTemplate_type_key" on castfolio_agency."NotificationTemplate" (type);
create unique index if not exists "Order_orderNumber_key" on castfolio_agency."Order" ("orderNumber");
create unique index if not exists "Order_quoteId_key" on castfolio_agency."Order" ("quoteId");
create unique index if not exists "Page_previewToken_key" on castfolio_agency."Page" ("previewToken");
create unique index if not exists "Page_projectId_key" on castfolio_agency."Page" ("projectId");
create unique index if not exists "Page_slug_key" on castfolio_agency."Page" (slug);
create unique index if not exists "QRAsset_pageId_key" on castfolio_agency."QRAsset" ("pageId");
create unique index if not exists "Quote_token_key" on castfolio_agency."Quote" (token);
create unique index if not exists "RevisionPolicy_packageId_key" on castfolio_agency."RevisionPolicy" ("packageId");
create unique index if not exists "User_email_key" on castfolio_agency."User" (email);
create unique index if not exists "User_supabaseUid_key" on castfolio_agency."User" ("supabaseUid");

-- Enable RLS on all (service_role-only until onboarding defines supabaseUid-based policies)
do $$
declare t text;
begin
  foreach t in array array[
    'User','NotificationTemplate','RiskFlag','Talent','ProductPackage','SettlementBatch','AdminNote',
    'AuditLog','Notification','Project','PricingChangeLog','PricingPolicyVersion','RevisionPolicy',
    'IntakeForm','IntakeSubmission','MediaAsset','ProjectTimeline','Page','PageVersion','PageView',
    'QRAsset','Quote','QuoteLineItem','Order','OrderLineItem','CommissionLedger','PaymentRecord','RefundRecord'
  ] loop
    execute format('alter table castfolio_agency.%I enable row level security', t);
    execute format('grant all on castfolio_agency.%I to service_role', t);
  end loop;
end $$;
