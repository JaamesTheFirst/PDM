/*
  Warnings:

  - The `difficulty` column on the `routes` table would be dropped and recreated. This will lead to data loss if there is data in the column.
  - You are about to drop the column `preferredTransportTypes` on the `user_preferences` table. All the data in the column will be lost.
  - A unique constraint covering the columns `[externalId]` on the table `stations` will be added. If there are existing duplicate values, this will fail.
  - Added the required column `mainMode` to the `routes` table without a default value. This is not possible if the table is not empty.
  - Changed the type of `stationType` on the `stations` table. No cast exists, the column would be dropped and recreated, which cannot be done if there is data, since the column is required.
  - Added the required column `mode` to the `vehicles` table without a default value. This is not possible if the table is not empty.
  - Changed the type of `vehicleType` on the `vehicles` table. No cast exists, the column would be dropped and recreated, which cannot be done if there is data, since the column is required.
  - Changed the type of `energyType` on the `vehicles` table. No cast exists, the column would be dropped and recreated, which cannot be done if there is data, since the column is required.

*/
-- CreateEnum
CREATE TYPE "public"."TransportMode" AS ENUM ('WALKING', 'BIKE', 'BIKE_SHARE', 'SCOOTER', 'SCOOTER_SHARE', 'BUS', 'TRAIN', 'METRO', 'CAR', 'TAXI', 'EV_CAR');

-- CreateEnum
CREATE TYPE "public"."StationType" AS ENUM ('GENERIC', 'BUS_STOP', 'TRAIN_STATION', 'METRO_STATION', 'BIKE_STATION', 'SCOOTER_STATION', 'CHARGING_STATION');

-- CreateEnum
CREATE TYPE "public"."VehicleType" AS ENUM ('ELECTRIC_BUS', 'BIKE', 'SCOOTER', 'METRO', 'TRAIN', 'CAR', 'TAXI', 'EV_CAR');

-- CreateEnum
CREATE TYPE "public"."EnergyType" AS ENUM ('ELECTRIC', 'HYBRID', 'HUMAN_POWERED', 'FOSSIL');

-- CreateEnum
CREATE TYPE "public"."RouteDifficulty" AS ENUM ('EASY', 'MEDIUM', 'HARD');

-- CreateEnum
CREATE TYPE "public"."RouteStatus" AS ENUM ('PLANNED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "public"."EcoPeriodType" AS ENUM ('DAY', 'WEEK', 'MONTH', 'YEAR');

-- CreateEnum
CREATE TYPE "public"."ServiceAreaType" AS ENUM ('SCOOTER_ZONE', 'BIKE_ZONE', 'GENERIC');

-- AlterTable
ALTER TABLE "public"."routes" ADD COLUMN     "geometry" JSONB,
ADD COLUMN     "mainMode" "public"."TransportMode" NOT NULL,
ADD COLUMN     "modes" "public"."TransportMode"[],
ADD COLUMN     "polyline" TEXT,
DROP COLUMN "difficulty",
ADD COLUMN     "difficulty" "public"."RouteDifficulty";

-- AlterTable
ALTER TABLE "public"."stations" ADD COLUMN     "availableDocks" INTEGER,
ADD COLUMN     "availableVehicles" INTEGER,
ADD COLUMN     "capacity" INTEGER,
ADD COLUMN     "city" TEXT,
ADD COLUMN     "country" TEXT,
ADD COLUMN     "externalId" TEXT,
DROP COLUMN "stationType",
ADD COLUMN     "stationType" "public"."StationType" NOT NULL;

-- AlterTable
ALTER TABLE "public"."user_preferences" DROP COLUMN "preferredTransportTypes",
ADD COLUMN     "preferredTransportModes" "public"."TransportMode"[];

-- AlterTable
ALTER TABLE "public"."vehicles" ADD COLUMN     "currentStationId" TEXT,
ADD COLUMN     "mode" "public"."TransportMode" NOT NULL,
DROP COLUMN "vehicleType",
ADD COLUMN     "vehicleType" "public"."VehicleType" NOT NULL,
DROP COLUMN "energyType",
ADD COLUMN     "energyType" "public"."EnergyType" NOT NULL;

-- CreateTable
CREATE TABLE "public"."transit_lines" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "code" TEXT,
    "description" TEXT,
    "lineType" "public"."TransportMode" NOT NULL,
    "color" TEXT,
    "schedule" JSONB,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "transit_lines_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "public"."transit_line_stops" (
    "id" TEXT NOT NULL,
    "transitLineId" TEXT NOT NULL,
    "stationId" TEXT NOT NULL,
    "order" INTEGER NOT NULL,
    "distanceFromPrevMeters" INTEGER,
    "travelTimeFromPrevSeconds" INTEGER,

    CONSTRAINT "transit_line_stops_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "public"."service_areas" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "areaType" "public"."ServiceAreaType" NOT NULL,
    "polygon" JSONB,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "service_areas_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "public"."search_history" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "query" TEXT NOT NULL,
    "placeId" TEXT,
    "placeName" TEXT NOT NULL,
    "latitude" DOUBLE PRECISION,
    "longitude" DOUBLE PRECISION,
    "raw" JSONB,
    "searchedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "search_history_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "public"."routes_history" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "routeId" TEXT,
    "originName" TEXT NOT NULL,
    "originLatitude" DOUBLE PRECISION NOT NULL,
    "originLongitude" DOUBLE PRECISION NOT NULL,
    "destinationName" TEXT NOT NULL,
    "destinationLatitude" DOUBLE PRECISION NOT NULL,
    "destinationLongitude" DOUBLE PRECISION NOT NULL,
    "primaryMode" "public"."TransportMode" NOT NULL,
    "modes" "public"."TransportMode"[],
    "distanceMeters" INTEGER NOT NULL,
    "durationSeconds" INTEGER NOT NULL,
    "co2Kg" DOUBLE PRECISION NOT NULL,
    "co2SavedVsCarKg" DOUBLE PRECISION,
    "status" "public"."RouteStatus" NOT NULL DEFAULT 'PLANNED',
    "startedAt" TIMESTAMP(3) NOT NULL,
    "finishedAt" TIMESTAMP(3),
    "polyline" TEXT,
    "segments" JSONB,
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "routes_history_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "public"."eco_stats_aggregate" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "period" TEXT NOT NULL,
    "periodType" "public"."EcoPeriodType" NOT NULL,
    "totalDistanceMeters" INTEGER NOT NULL DEFAULT 0,
    "totalDurationSeconds" INTEGER NOT NULL DEFAULT 0,
    "totalCo2Kg" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "co2SavedVsCarKg" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "eco_stats_aggregate_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "public"."emission_factors" (
    "id" TEXT NOT NULL,
    "mode" "public"."TransportMode" NOT NULL,
    "kgCo2PerKm" DOUBLE PRECISION NOT NULL,
    "notes" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "emission_factors_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "transit_line_stops_stationId_idx" ON "public"."transit_line_stops"("stationId");

-- CreateIndex
CREATE UNIQUE INDEX "transit_line_stops_transitLineId_stationId_key" ON "public"."transit_line_stops"("transitLineId", "stationId");

-- CreateIndex
CREATE INDEX "search_history_userId_searchedAt_idx" ON "public"."search_history"("userId", "searchedAt" DESC);

-- CreateIndex
CREATE INDEX "routes_history_userId_startedAt_idx" ON "public"."routes_history"("userId", "startedAt" DESC);

-- CreateIndex
CREATE INDEX "routes_history_primaryMode_idx" ON "public"."routes_history"("primaryMode");

-- CreateIndex
CREATE UNIQUE INDEX "eco_stats_aggregate_userId_period_periodType_key" ON "public"."eco_stats_aggregate"("userId", "period", "periodType");

-- CreateIndex
CREATE UNIQUE INDEX "emission_factors_mode_key" ON "public"."emission_factors"("mode");

-- CreateIndex
CREATE UNIQUE INDEX "stations_externalId_key" ON "public"."stations"("externalId");

-- AddForeignKey
ALTER TABLE "public"."vehicles" ADD CONSTRAINT "vehicles_currentStationId_fkey" FOREIGN KEY ("currentStationId") REFERENCES "public"."stations"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "public"."transit_line_stops" ADD CONSTRAINT "transit_line_stops_transitLineId_fkey" FOREIGN KEY ("transitLineId") REFERENCES "public"."transit_lines"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "public"."transit_line_stops" ADD CONSTRAINT "transit_line_stops_stationId_fkey" FOREIGN KEY ("stationId") REFERENCES "public"."stations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "public"."search_history" ADD CONSTRAINT "search_history_userId_fkey" FOREIGN KEY ("userId") REFERENCES "public"."users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "public"."routes_history" ADD CONSTRAINT "routes_history_userId_fkey" FOREIGN KEY ("userId") REFERENCES "public"."users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "public"."routes_history" ADD CONSTRAINT "routes_history_routeId_fkey" FOREIGN KEY ("routeId") REFERENCES "public"."routes"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "public"."eco_stats_aggregate" ADD CONSTRAINT "eco_stats_aggregate_userId_fkey" FOREIGN KEY ("userId") REFERENCES "public"."users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
