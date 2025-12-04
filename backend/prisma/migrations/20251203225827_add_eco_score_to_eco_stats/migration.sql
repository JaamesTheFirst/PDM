-- AlterTable
ALTER TABLE "public"."eco_stats_aggregate" ADD COLUMN     "totalEcoScore" DOUBLE PRECISION NOT NULL DEFAULT 0,
ADD COLUMN     "tripsCount" INTEGER NOT NULL DEFAULT 0;
