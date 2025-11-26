-- CreateTable
CREATE TABLE "public"."gira_stations" (
    "id" SERIAL NOT NULL,
    "externalId" TEXT,
    "name" TEXT,
    "address" TEXT,
    "parish" TEXT,
    "latitude" DOUBLE PRECISION,
    "longitude" DOUBLE PRECISION,
    "capacity" INTEGER,
    "raw" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "gira_stations_pkey" PRIMARY KEY ("id")
);
