-- CreateTable
CREATE TABLE "Tombstone" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "itemId" TEXT NOT NULL,
    "deletedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Tombstone_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "Tombstone_userId_deletedAt_idx" ON "Tombstone"("userId", "deletedAt");

-- CreateIndex
CREATE UNIQUE INDEX "Tombstone_userId_itemId_key" ON "Tombstone"("userId", "itemId");

-- AddForeignKey
ALTER TABLE "Tombstone" ADD CONSTRAINT "Tombstone_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
