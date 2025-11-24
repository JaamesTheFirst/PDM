/*
  Warnings:

  - You are about to drop the column `preferredTransportModes` on the `user_preferences` table. All the data in the column will be lost.

*/
-- AlterTable
ALTER TABLE "user_preferences" DROP COLUMN "preferredTransportModes",
ADD COLUMN     "preferredTransportTypes" "TransportMode"[];
