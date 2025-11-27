/*
  Warnings:

  - A unique constraint covering the columns `[gbfsSystemId,externalId]` on the table `stations` will be added. If there are existing duplicate values, this will fail.

*/
-- DropIndex
DROP INDEX "public"."stations_externalId_key";

-- AlterTable
ALTER TABLE "public"."stations" ADD COLUMN     "gbfsSystemId" INTEGER;

-- CreateIndex
CREATE UNIQUE INDEX "stations_gbfsSystemId_externalId_key" ON "public"."stations"("gbfsSystemId", "externalId");

-- AddForeignKey
ALTER TABLE "public"."stations" ADD CONSTRAINT "stations_gbfsSystemId_fkey" FOREIGN KEY ("gbfsSystemId") REFERENCES "public"."gbfs_systems"("id") ON DELETE SET NULL ON UPDATE CASCADE;
