// functions/src/badge-cleanup.ts
// Firebase Cloud Function para limpar badges automaticamente

import * as admin from "firebase-admin";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";

// ============================================================
// TYPES
// ============================================================

interface BadgeData {
  unread_chats: number;
  unread_requests: number;
}

interface VerificationResult {
  userId: string;
  success: boolean;
  wasCorrected: boolean;
  currentBadge: BadgeData;
  calculatedBadge: BadgeData;
  readsUsed: number;
  writesUsed: number;
  error?: string;
}

interface BatchResult {
  totalProcessed: number;
  correctCount: number;
  correctedCount: number;
  errorCount: number;
  totalReads: number;
  totalWrites: number;
}

// ============================================================
// HELPER - VERIFICAR E CORRIGIR BADGE DE UM USUÁRIO
// ============================================================

async function verifyAndFixBadge(
  userId: string,
  userRole: "worker" | "contractor"
): Promise<VerificationResult> {
  const result: VerificationResult = {
    userId,
    success: false,
    wasCorrected: false,
    currentBadge: { unread_chats: 0, unread_requests: 0 },
    calculatedBadge: { unread_chats: 0, unread_requests: 0 },
    readsUsed: 0,
    writesUsed: 0,
  };

  try {
    logger.info(`\n🔍 Verificando badge: ${userId} (${userRole})`);

    const badgeSnap = await admin.database().ref(`badges/${userId}`).once("value");
    result.readsUsed++;

    if (badgeSnap.exists()) {
      const badgeData = badgeSnap.val() as BadgeData;
      result.currentBadge = {
        unread_chats: badgeData.unread_chats || 0,
        unread_requests: badgeData.unread_requests || 0,
      };
    }

    logger.info(`  Badge atual: ${JSON.stringify(result.currentBadge)}`);

    let unreadChats = 0;

    const employeeChatsSnap = await admin
      .database()
      .ref("Chats")
      .orderByChild("employee")
      .equalTo(userId)
      .once("value");
    result.readsUsed++;

    if (employeeChatsSnap.exists()) {
      const chats = employeeChatsSnap.val() as Record<string, any>;
      for (const chatId in chats) {
        if ((chats[chatId].unreadCount?.employee || 0) === 1) unreadChats++;
      }
    }

    const contractorChatsSnap = await admin
      .database()
      .ref("Chats")
      .orderByChild("contractor")
      .equalTo(userId)
      .once("value");
    result.readsUsed++;

    if (contractorChatsSnap.exists()) {
      const chats = contractorChatsSnap.val() as Record<string, any>;
      for (const chatId in chats) {
        if ((chats[chatId].unreadCount?.contractor || 0) === 1) unreadChats++;
      }
    }

    unreadChats = Math.min(unreadChats, 9);
    logger.info(`  Chats não lidos: ${unreadChats}`);

    let unreadRequests = 0;

    if (userRole === "worker") {
      const profilesSnap = await admin
        .database()
        .ref("professionals")
        .orderByChild("local_id")
        .equalTo(userId)
        .once("value");
      result.readsUsed++;

      if (profilesSnap.exists()) {
        const profiles = profilesSnap.val() as Record<string, any>;
        for (const profileId in profiles) {
          const requestViews = profiles[profileId].views?.request_views;
          if (requestViews) {
            for (const reqId in requestViews) {
              if (requestViews[reqId].viewed_by_owner === false) unreadRequests++;
            }
          }
        }
      }
    } else {
      const vacanciesSnap = await admin
        .database()
        .ref("vacancy")
        .orderByChild("local_id")
        .equalTo(userId)
        .once("value");
      result.readsUsed++;

      if (vacanciesSnap.exists()) {
        const vacancies = vacanciesSnap.val() as Record<string, any>;
        for (const vacancyId in vacancies) {
          const requestViews = vacancies[vacancyId].views?.request_views;
          if (requestViews) {
            for (const reqId in requestViews) {
              if (requestViews[reqId].viewed_by_owner === false) unreadRequests++;
            }
          }
        }
      }
    }

    unreadRequests = Math.min(unreadRequests, 9);
    logger.info(`  Requests não lidos: ${unreadRequests}`);

    result.calculatedBadge = { unread_chats: unreadChats, unread_requests: unreadRequests };

    const needsCorrection =
      result.currentBadge.unread_chats !== result.calculatedBadge.unread_chats ||
      result.currentBadge.unread_requests !== result.calculatedBadge.unread_requests;

    if (needsCorrection) {
      logger.info(`  ⚠️ Badge incorreto! Corrigindo...`);
      logger.info(`    Antes: ${JSON.stringify(result.currentBadge)}`);
      logger.info(`    Depois: ${JSON.stringify(result.calculatedBadge)}`);

      await admin.database().ref(`badges/${userId}`).set({
        unread_chats: result.calculatedBadge.unread_chats,
        unread_requests: result.calculatedBadge.unread_requests,
        updated_at: Date.now(),
      });
      result.writesUsed++;
      result.wasCorrected = true;
      logger.info(`  ✅ Badge corrigido!`);
    } else {
      logger.info(`  ✅ Badge está correto`);
    }

    result.success = true;
  } catch (error: any) {
    logger.error(`  ❌ Erro ao verificar badge:`, error);
    result.error = error.message || String(error);
  }

  return result;
}

// ============================================================
// HELPER - VERIFICAR MÚLTIPLOS USUÁRIOS
// ============================================================

async function verifyMultipleUsers(
  userRoles: Record<string, "worker" | "contractor">
): Promise<BatchResult> {
  const batchResult: BatchResult = {
    totalProcessed: 0,
    correctCount: 0,
    correctedCount: 0,
    errorCount: 0,
    totalReads: 0,
    totalWrites: 0,
  };

  logger.info(`\n╔═══════════════════════════════════════╗`);
  logger.info(`║  VERIFICAÇÃO EM BATCH - ${Object.keys(userRoles).length} USUÁRIOS  ║`);
  logger.info(`╚═══════════════════════════════════════╝\n`);

  for (const [userId, role] of Object.entries(userRoles)) {
    const result = await verifyAndFixBadge(userId, role);

    batchResult.totalProcessed++;
    batchResult.totalReads += result.readsUsed;
    batchResult.totalWrites += result.writesUsed;

    if (result.success) {
      result.wasCorrected ? batchResult.correctedCount++ : batchResult.correctCount++;
    } else {
      batchResult.errorCount++;
    }
  }

  logger.info(`\n╔═══════════════════════════════════════╗`);
  logger.info(`║       RELATÓRIO FINAL - BATCH        ║`);
  logger.info(`╚═══════════════════════════════════════╝`);
  logger.info(`📊 Total processado: ${batchResult.totalProcessed}`);
  logger.info(`✅ Corretos: ${batchResult.correctCount}`);
  logger.info(`🔧 Corrigidos: ${batchResult.correctedCount}`);
  logger.info(`❌ Erros: ${batchResult.errorCount}`);
  logger.info(`\n📈 Operações Firebase:`);
  logger.info(`   Leituras: ${batchResult.totalReads}`);
  logger.info(`   Escritas: ${batchResult.totalWrites}`);
  logger.info(
    `   Média leituras/usuário: ${(batchResult.totalReads / batchResult.totalProcessed).toFixed(1)}`
  );
  logger.info(`═══════════════════════════════════════\n`);

  return batchResult;
}

// ============================================================
// HELPER - VERIFICAR TODOS OS BADGES
// ============================================================

async function verifyAllBadges(): Promise<BatchResult> {
  logger.info(`\n🔍 Buscando todos os badges...`);

  const badgesSnap = await admin.database().ref("badges").once("value");

  if (!badgesSnap.exists()) {
    logger.info(`⚠️ Nenhum badge encontrado no banco`);
    return {
      totalProcessed: 0,
      correctCount: 0,
      correctedCount: 0,
      errorCount: 0,
      totalReads: 0,
      totalWrites: 0,
    };
  }

  const badges = badgesSnap.val() as Record<string, any>;
  logger.info(`📊 Encontrados ${Object.keys(badges).length} badges\n`);

  const userRoles: Record<string, "worker" | "contractor"> = {};

  for (const userId of Object.keys(badges)) {
    const userSnap = await admin.database().ref(`Users/${userId}`).once("value");

    if (userSnap.exists()) {
      const userData = userSnap.val() as Record<string, any>;
      const role = userData.role as string | undefined;

      if (role === "worker" || role === "contractor") {
        userRoles[userId] = role as "worker" | "contractor";
      } else {
        logger.warn(`⚠️ Usuário ${userId} sem role definido, assumindo worker`);
        userRoles[userId] = "worker";
      }
    } else {
      logger.warn(`⚠️ Usuário ${userId} não encontrado em Users, pulando`);
    }
  }

  return await verifyMultipleUsers(userRoles);
}

// ============================================================
// CLOUD FUNCTION - SCHEDULED BADGE CLEANUP
// ✅ Handler retorna void — onSchedule não aceita return com objeto
// ============================================================

export const weeklyBadgeCleanup = onSchedule(
  {
    schedule: "0 3 * * 0",
    timeZone: "America/Sao_Paulo",
    region: "us-central1",
  },
  async (_event) => {
    logger.info("\n═══════════════════════════════════════════");
    logger.info("🕐 MANUTENÇÃO SEMANAL - BADGE CLEANUP");
    logger.info("═══════════════════════════════════════════\n");
    logger.info(`Horário: ${new Date().toISOString()}`);

    try {
      await verifyAllBadges();
      logger.info("\n✅ MANUTENÇÃO CONCLUÍDA COM SUCESSO");
      logger.info("═══════════════════════════════════════════\n");
    } catch (error) {
      logger.error("\n❌❌❌ ERRO CRÍTICO NA MANUTENÇÃO ❌❌❌");
      logger.error("Erro:", error);
    }
  }
);

// ============================================================
// CLOUD FUNCTION - ON-DEMAND BADGE CLEANUP
// ✅ Handler retorna void
// ============================================================

export const manualBadgeCleanup = onSchedule(
  {
    schedule: "every 24 hours",
    timeZone: "America/Sao_Paulo",
    region: "us-central1",
  },
  async (_event) => {
    logger.info("\n═══════════════════════════════════════════");
    logger.info("🔧 LIMPEZA MANUAL - BADGE CLEANUP");
    logger.info("═══════════════════════════════════════════\n");

    try {
      await verifyAllBadges();
      logger.info("\n✅ LIMPEZA CONCLUÍDA");
    } catch (error) {
      logger.error("❌ Erro na limpeza manual:", error);
    }
  }
);

// ============================================================
// CLOUD FUNCTION - VERIFICAR BADGE INDIVIDUAL (HTTP)
// ============================================================

export const verifyUserBadge = onRequest(
  {
    region: "us-central1",
    cors: true,
  },
  async (request, response) => {
    const userId = request.query.userId as string;
    const userRole = request.query.role as "worker" | "contractor";

    if (!userId || !userRole) {
      response.status(400).send({ error: "Missing userId or role parameter" });
      return;
    }

    try {
      const result = await verifyAndFixBadge(userId, userRole);
      response.status(200).send({ success: true, result });
    } catch (error) {
      response.status(500).send({ success: false, error: String(error) });
    }
  }
);