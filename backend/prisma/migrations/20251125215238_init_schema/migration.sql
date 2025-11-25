-- CreateTable
CREATE TABLE "public"."gbfs_systems" (
    "id" SERIAL NOT NULL,
    "countryCode" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "location" TEXT,
    "systemId" TEXT NOT NULL,
    "url" TEXT,
    "autoDiscoveryUrl" TEXT,
    "supportedVersions" TEXT,
    "authenticationInfoUrl" TEXT,

    CONSTRAINT "gbfs_systems_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "gbfs_systems_systemId_key" ON "public"."gbfs_systems"("systemId");
