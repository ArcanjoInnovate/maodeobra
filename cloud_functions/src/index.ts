import * as admin from "firebase-admin";
import { onValueCreated } from "firebase-functions/v2/database";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";

const serviceAccount = require("../serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://obra-7ebd9-default-rtdb.firebaseio.com",
});

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
// HELPER - NORMALIZAR REQUESTS (MAP → ARRAY)
// ============================================================

function _normalizeRequests(requests: any): string[] {
  if (!requests) return [];
  if (Array.isArray(requests)) return requests;
  // Se for Map/Object, pegar apenas os valores que são strings
  if (typeof requests === "object") {
    return Object.values(requests).filter(
      (v) => typeof v === "string",
    ) as string[];
  }
  return [];
}

// ============================================================
// HELPER - VERIFICAR E CORRIGIR BADGE DE UM USUÁRIO
// ============================================================

async function verifyAndFixBadge(
  userId: string,
  userRole: "worker" | "contractor",
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

    const badgeSnap = await admin
      .database()
      .ref(`badges/${userId}`)
      .once("value");
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
        const chat = chats[chatId];
        const unreadCount = chat.unreadCount?.employee || 0;
        if (unreadCount === 1) unreadChats++;
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
        const chat = chats[chatId];
        const unreadCount = chat.unreadCount?.contractor || 0;
        if (unreadCount === 1) unreadChats++;
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
          const profile = profiles[profileId];
          const requestViews = profile.views?.request_views;
          if (requestViews) {
            for (const reqId in requestViews) {
              if (requestViews[reqId].viewed_by_owner === false)
                unreadRequests++;
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
          const vacancy = vacancies[vacancyId];
          const requestViews = vacancy.views?.request_views;
          if (requestViews) {
            for (const reqId in requestViews) {
              if (requestViews[reqId].viewed_by_owner === false)
                unreadRequests++;
            }
          }
        }
      }
    }

    unreadRequests = Math.min(unreadRequests, 9);
    logger.info(`  Requests não lidos: ${unreadRequests}`);

    result.calculatedBadge = {
      unread_chats: unreadChats,
      unread_requests: unreadRequests,
    };

    const needsCorrection =
      result.currentBadge.unread_chats !==
        result.calculatedBadge.unread_chats ||
      result.currentBadge.unread_requests !==
        result.calculatedBadge.unread_requests;

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
  userRoles: Record<string, "worker" | "contractor">,
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
  logger.info(
    `║  VERIFICAÇÃO EM BATCH - ${Object.keys(userRoles).length} USUÁRIOS  ║`,
  );
  logger.info(`╚═══════════════════════════════════════╝\n`);

  for (const [userId, role] of Object.entries(userRoles)) {
    const result = await verifyAndFixBadge(userId, role);

    batchResult.totalProcessed++;
    batchResult.totalReads += result.readsUsed;
    batchResult.totalWrites += result.writesUsed;

    if (result.success) {
      if (result.wasCorrected) {
        batchResult.correctedCount++;
      } else {
        batchResult.correctCount++;
      }
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
    `   Média leituras/usuário: ${(batchResult.totalReads / batchResult.totalProcessed).toFixed(1)}`,
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
    const userSnap = await admin
      .database()
      .ref(`Users/${userId}`)
      .once("value");

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
// CLOUD FUNCTION - SCHEDULED BADGE CLEANUP (semanal)
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
  },
);

// ============================================================
// CLOUD FUNCTION - BADGE CLEANUP DIÁRIO
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
  },
);

// ============================================================
// CLOUD FUNCTION - VERIFICAR BADGE INDIVIDUAL (HTTP)
// ============================================================

export const verifyUserBadge = onRequest(
  { region: "us-central1", cors: true },
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
  },
);

// ============================================================
// HELPERS - PUSH NOTIFICATIONS
// ============================================================

async function getSenderInfo(userId: string) {
  try {
    const userSnap = await admin
      .database()
      .ref(`Users/${userId}`)
      .once("value");
    if (!userSnap.exists()) return { name: "Usuário", avatar: "" };
    const userData = userSnap.val() as Record<string, any>;
    return {
      name: userData?.Name || "Usuário",
      avatar: userData?.avatar || "",
    };
  } catch (error) {
    return { name: "Usuário", avatar: "" };
  }
}

async function isUserOnlineInChat(
  chatId: string,
  userRole: "employee" | "contractor",
): Promise<boolean> {
  try {
    const statusSnap = await admin
      .database()
      .ref(`Chats/${chatId}/participants/${userRole}`)
      .once("value");
    return statusSnap.val() === "online";
  } catch (error) {
    return false;
  }
}

async function sendChatPushNotification(
  userId: string,
  senderName: string,
  messageText: string,
  chatId: string,
  senderId: string,
  senderAvatarUrl?: string,
) {
  try {
    const tokenSnap = await admin
      .database()
      .ref(`Users/${userId}/fcmToken`)
      .once("value");

    if (!tokenSnap.exists()) {
      logger.warn(`⚠️ Usuário ${userId} sem FCM token`);
      return;
    }

    const token = tokenSnap.val() as string;
    logger.info(`✅ Token encontrado: ${token.substring(0, 30)}...`);

    const displayText =
      messageText && messageText.length > 80
        ? messageText.substring(0, 77) + "..."
        : messageText || "Nova mensagem";

    const message: admin.messaging.Message = {
      token,
      data: {
        type: "chat",
        chatId,
        senderId,
        senderName,
        senderAvatar: senderAvatarUrl || "",
        notificationTitle: senderName,
        notificationBody: displayText,
        notificationTag: chatId,
      },
      android: {
        priority: "high",
      },
      apns: {
        headers: {
          "apns-priority": "10",
          "apns-push-type": "alert",
        },
        payload: {
          aps: {
            alert: {
              title: senderName,
              body: displayText,
            },
            sound: "default",
            badge: 1,
            "mutable-content": 1,
            "thread-id": chatId,
          },
        },
      },
    };

    const response = await admin.messaging().send(message);
    logger.info(`✅ Push chat enviada para ${userId}! MessageID: ${response}`);
  } catch (error: any) {
    logger.error(`❌ Erro ao enviar push de chat:`, error);
    if (
      error.code === "messaging/invalid-registration-token" ||
      error.code === "messaging/registration-token-not-registered"
    ) {
      await admin.database().ref(`Users/${userId}/fcmToken`).remove();
    }
  }
}

async function sendPushNotification(
  userId: string,
  title: string,
  body: string,
  data: Record<string, string>,
  avatarUrl?: string,
) {
  try {
    const tokenSnap = await admin
      .database()
      .ref(`Users/${userId}/fcmToken`)
      .once("value");

    if (!tokenSnap.exists()) {
      logger.warn(`⚠️ Usuário ${userId} sem FCM token`);
      return;
    }

    const token = tokenSnap.val() as string;

    const message: admin.messaging.Message = {
      token,
      data: {
        ...data,
        senderAvatar: avatarUrl || "",
        notificationTitle: title,
        notificationBody: body,
      },
      android: {
        priority: "high",
      },
      apns: {
        headers: {
          "apns-priority": "10",
          "apns-push-type": "alert",
        },
        payload: {
          aps: {
            alert: { title, body },
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    const response = await admin.messaging().send(message);
    logger.info(`✅ Push enviada para ${userId}! MessageID: ${response}`);
  } catch (error: any) {
    logger.error(`❌ Erro ao enviar push para ${userId}:`, error);
    if (
      error.code === "messaging/invalid-registration-token" ||
      error.code === "messaging/registration-token-not-registered"
    ) {
      await admin.database().ref(`Users/${userId}/fcmToken`).remove();
    }
  }
}

async function recalculateChatBadge(userId: string) {
  try {
    logger.info(`\n🔄 RECALCULANDO BADGE: ${userId}`);

    const employeeChatsSnap = await admin
      .database()
      .ref("Chats")
      .orderByChild("employee")
      .equalTo(userId)
      .once("value");

    const contractorChatsSnap = await admin
      .database()
      .ref("Chats")
      .orderByChild("contractor")
      .equalTo(userId)
      .once("value");

    let totalUnread = 0;

    if (employeeChatsSnap.exists()) {
      const chats = employeeChatsSnap.val() as Record<string, any>;
      for (const chatId in chats) {
        if ((chats[chatId].unreadCount?.employee || 0) === 1) totalUnread++;
      }
    }

    if (contractorChatsSnap.exists()) {
      const chats = contractorChatsSnap.val() as Record<string, any>;
      for (const chatId in chats) {
        if ((chats[chatId].unreadCount?.contractor || 0) === 1) totalUnread++;
      }
    }

    totalUnread = Math.min(totalUnread, 9);

    const badgeSnap = await admin
      .database()
      .ref(`badges/${userId}`)
      .once("value");
    const currentBadge = badgeSnap.exists()
      ? badgeSnap.val()
      : { unread_requests: 0 };

    await admin
      .database()
      .ref(`badges/${userId}`)
      .set({
        unread_chats: totalUnread,
        unread_requests: currentBadge.unread_requests || 0,
        updated_at: Date.now(),
      });

    logger.info(`✅ Badge recalculado: ${totalUnread} chats não lidos`);
  } catch (error) {
    logger.error(`❌ Erro ao recalcular badge:`, error);
  }
}

async function incrementRequestBadge(userId: string) {
  try {
    // ✅ VERIFICA SE FOI CHAMADO DUAS VEZES (proteção)
    const recentSnap = await admin
      .database()
      .ref(`badges/${userId}/last_increment`)
      .once("value");

    const lastIncrement = recentSnap.val() as number | null;
    const now = Date.now();

    if (lastIncrement && now - lastIncrement < 2000) {
      // 2 segundos
      logger.warn(`⚠️ incrementRequestBadge bloqueado (duplicata): ${userId}`);
      return;
    }

    const badgeRef = admin.database().ref(`badges/${userId}`);
    const snap = await badgeRef.once("value");
    const current = snap.exists()
      ? snap.val()
      : { unread_chats: 0, unread_requests: 0 };

    await badgeRef.set({
      unread_chats: current.unread_chats || 0,
      unread_requests: Math.min((current.unread_requests || 0) + 1, 9),
      updated_at: now,
      last_increment: now, // ✅ Marca timestamp
    });

    logger.info(
      `✅ Badge incrementado: ${userId} → ${current.unread_requests + 1}`,
    );
  } catch (error) {
    logger.error("Erro ao incrementar badge:", error);
  }
}

async function decrementRequestBadge(userId: string) {
  try {
    const badgeRef = admin.database().ref(`badges/${userId}`);
    const snap = await badgeRef.once("value");
    const current = snap.exists()
      ? snap.val()
      : { unread_chats: 0, unread_requests: 0 };

    await badgeRef.set({
      unread_chats: current.unread_chats || 0,
      unread_requests: Math.max((current.unread_requests || 0) - 1, 0),
      updated_at: Date.now(),
    });

    logger.info(
      `✅ Badge decrementado: ${userId} → ${current.unread_requests - 1}`,
    );
  } catch (error) {
    logger.error(`❌ Erro ao decrementar badge:`, error);
  }
}

// ============================================================
// HELPER - LIMPAR CANDIDATURAS E BADGES
// ============================================================

async function cleanupCandidaturesBadges(userId: string, userRole: string) {
  const database = admin.database();

  logger.info(`\n🗑️ Limpando candidaturas de ${userId} (${userRole})`);

  if (userRole === "worker") {
    // Buscar vagas onde o worker se candidatou
    const vacanciesSnap = await database.ref("vacancy").once("value");

    if (vacanciesSnap.exists()) {
      const vacancies = vacanciesSnap.val() as Record<string, any>;

      for (const [vacancyId, vacancyData] of Object.entries(vacancies)) {
        // ✅ Normalizar requests (pode ser Map ou Array)
        const requests = _normalizeRequests(vacancyData.requests);

        if (requests.includes(userId)) {
          logger.info(`  📌 Removendo de vacancy/${vacancyId}`);

          // Verificar se não foi visualizado
          const requestViews = vacancyData.views?.request_views || {};
          if (requestViews[userId]?.viewed_by_owner === false) {
            const ownerId = vacancyData.local_id;
            logger.info(`  🔽 Decrementando badge do owner: ${ownerId}`);
            await decrementRequestBadge(ownerId);
          }

          // Remover das listas
          const filteredRequests = requests.filter(
            (id: string) => id !== userId,
          );
          await database
            .ref(`vacancy/${vacancyId}/requests`)
            .set(filteredRequests);
          await database
            .ref(`vacancy/${vacancyId}/views/request_views/${userId}`)
            .remove();
        }
      }
    }
  } else {
    // Buscar professionals onde o contractor se candidatou
    const professionalsSnap = await database.ref("professionals").once("value");

    if (professionalsSnap.exists()) {
      const professionals = professionalsSnap.val() as Record<string, any>;

      for (const [professionalId, professionalData] of Object.entries(
        professionals,
      )) {
        // ✅ Normalizar requests
        const requests = _normalizeRequests(professionalData.requests);

        if (requests.includes(userId)) {
          logger.info(`  📌 Removendo de professionals/${professionalId}`);

          const requestViews = professionalData.views?.request_views || {};
          if (requestViews[userId]?.viewed_by_owner === false) {
            const ownerId = professionalData.local_id;
            logger.info(`  🔽 Decrementando badge do owner: ${ownerId}`);
            await decrementRequestBadge(ownerId);
          }

          const filteredRequests = requests.filter(
            (id: string) => id !== userId,
          );
          await database
            .ref(`professionals/${professionalId}/requests`)
            .set(filteredRequests);
          await database
            .ref(
              `professionals/${professionalId}/views/request_views/${userId}`,
            )
            .remove();
        }
      }
    }
  }

  logger.info(`✅ Limpeza de candidaturas concluída\n`);
}

// ============================================================
// CLOUD FUNCTION - DELETAR USUÁRIO
// ✅ CORRIGIDO: Salva role ANTES de deletar Users
// ============================================================

import { onValueDeleted } from "firebase-functions/v2/database";

export const onUserDeleted = onValueDeleted(
  {
    ref: "/Users/{userId}",
    region: "us-central1",
  },
  async (event) => {
    const userId = event.params.userId;

    try {
      logger.info(`\n═══════════════════════════════════════════`);
      logger.info(`🗑️ USUÁRIO DELETADO: ${userId}`);
      logger.info(`═══════════════════════════════════════════\n`);

      // ✅ Pegar role ANTES de deletar (do snapshot antes da exclusão)
      const beforeData = event.data.val() as any;
      const userRole = beforeData?.role || "worker";

      logger.info(`👤 Role detectado: ${userRole}`);

      // ✅ Limpar candidaturas e ajustar badges dos outros
      await cleanupCandidaturesBadges(userId, userRole);

      // ✅ Marcar como deletado (expira em 24h) + SALVAR ROLE
      const expiresAt = Date.now() + 24 * 60 * 60 * 1000;
      await admin.database().ref(`deleted_users/${userId}`).set({
        expires_at: expiresAt,
        role: userRole, // ✅ Salvar role para referência futura
        deleted_at: Date.now(),
      });

      logger.info(
        `\n✅ Marcado como deletado até ${new Date(expiresAt).toISOString()}`,
      );
      logger.info(`═══════════════════════════════════════════\n`);
    } catch (error) {
      logger.error(`\n❌❌❌ ERRO AO PROCESSAR EXCLUSÃO ❌❌❌`);
      logger.error(`Erro:`, error);
    }
  },
);

// ============================================================
// CLOUD FUNCTION - LIMPAR USUÁRIOS DELETADOS ANTIGOS
// ============================================================

export const cleanupDeletedUsers = onSchedule(
  {
    schedule: "every 24 hours",
    timeZone: "America/Sao_Paulo",
    region: "us-central1",
  },
  async (_event) => {
    try {
      logger.info("\n🧹 Limpando usuários deletados antigos...");

      const now = Date.now();
      const deletedUsersSnap = await admin
        .database()
        .ref("deleted_users")
        .once("value");

      if (!deletedUsersSnap.exists()) {
        logger.info("ℹ️ Nenhum usuário deletado encontrado");
        return;
      }

      const deletedUsers = deletedUsersSnap.val() as Record<string, any>;
      let cleaned = 0;

      for (const [userId, data] of Object.entries(deletedUsers)) {
        const expiresAt = data?.expires_at || data; // Compatibilidade com formato antigo

        if (now > expiresAt) {
          await admin.database().ref(`deleted_users/${userId}`).remove();
          cleaned++;
          logger.info(`  🗑️ Removido: ${userId}`);
        }
      }

      logger.info(`✅ Limpeza concluída: ${cleaned} registros removidos\n`);
    } catch (error) {
      logger.error(`❌ Erro na limpeza:`, error);
    }
  },
);

// ============================================================
// FUNCTION - NEW CHAT MESSAGE
// ============================================================

export const onChatMessageCreated = onValueCreated(
  {
    ref: "/ChatMessages/{chatId}/{messageId}",
    region: "us-central1",
  },
  async (event) => {
    const chatId = event.params.chatId;
    const messageData = event.data.val() as any;

    if (messageData._placeholder || !messageData) return;

    try {
      logger.info(`\n════════════════════════════════════════`);
      logger.info(`📨 NOVA MENSAGEM: ${chatId}`);
      logger.info(`════════════════════════════════════════`);

      const chatSnap = await admin
        .database()
        .ref(`Chats/${chatId}`)
        .once("value");
      if (!chatSnap.exists()) {
        logger.warn(`⚠️ Chat ${chatId} não existe`);
        return;
      }

      const chatData = chatSnap.val() as {
        employee: string;
        contractor: string;
        unreadCount?: { employee: number; contractor: number };
        metadata?: { last_message?: string };
      };

      const { employee, contractor, metadata } = chatData;
      const senderRole = messageData.sender as "employee" | "contractor";
      const sender = senderRole === "employee" ? employee : contractor;
      const receiver = senderRole === "employee" ? contractor : employee;
      const receiverRole =
        senderRole === "employee" ? "contractor" : "employee";

      logger.info(`👤 Sender: ${sender} (${senderRole})`);
      logger.info(`👤 Receiver: ${receiver} (${receiverRole})`);

      // ✅ VERIFICA SE É A PRIMEIRA MENSAGEM DO CHAT
      const isFirstMessage =
        !metadata?.last_message || metadata.last_message === "";

      if (isFirstMessage) {
        logger.info(`🔕 Primeira mensagem do chat - pulando notificação`);

        await admin
          .database()
          .ref(`Chats/${chatId}/unreadCount/${receiverRole}`)
          .set(0);

        await recalculateChatBadge(receiver);

        logger.info(`\n✅ PRIMEIRA MENSAGEM PROCESSADA (SEM NOTIFICAÇÃO)`);
        logger.info(`════════════════════════════════════════\n`);
        return;
      }

      const isOnline = await isUserOnlineInChat(chatId, receiverRole);
      logger.info(`📶 Online: ${isOnline}`);

      const newUnreadCount = isOnline ? 0 : 1;

      await admin
        .database()
        .ref(`Chats/${chatId}/unreadCount/${receiverRole}`)
        .set(newUnreadCount);
      logger.info(`✅ unreadCount atualizado`);

      await recalculateChatBadge(receiver);

      if (!isOnline) {
        const senderInfo = await getSenderInfo(sender);

        await sendChatPushNotification(
          receiver,
          senderInfo.name,
          messageData.text || "Nova mensagem",
          chatId,
          sender,
          senderInfo.avatar || undefined,
        );
      }

      logger.info(`\n✅ PROCESSADO COM SUCESSO`);
      logger.info(`════════════════════════════════════════\n`);
    } catch (err) {
      logger.error(`\n❌❌❌ ERRO CRÍTICO ❌❌❌`);
      logger.error(`Erro:`, err);
    }
  },
);

// ============================================================
// FUNCTION - CHAT REQUEST NOTIFICATION (PROFESSIONAL)
// ============================================================

export const onProfessionalChatRequestCreated = onValueCreated(
  {
    ref: "/professionals/{professionalId}/views/request_views/{requesterId}",
    region: "us-central1",
  },
  async (event) => {
    const professionalId = event.params.professionalId;
    const requestData = event.data.val() as any;

    try {
      logger.info(`\n════════════════════════════════════════`);
      logger.info(`💼 NOVA SOLICITAÇÃO DE CHAT (PROFESSIONAL)`);
      logger.info(`════════════════════════════════════════`);

      const professionalSnap = await admin
        .database()
        .ref(`professionals/${professionalId}`)
        .once("value");

      if (!professionalSnap.exists()) {
        logger.warn(`⚠️ Profissional ${professionalId} não encontrado`);
        return;
      }

      const professionalData = professionalSnap.val() as Record<string, any>;
      const ownerId = professionalData.local_id as string;

      if (!ownerId) {
        logger.warn(`⚠️ Profissional ${professionalId} sem local_id`);
        return;
      }

      await incrementRequestBadge(ownerId);

      const requesterName = requestData.contractor_name || "Alguém";
      const requesterAvatar = requestData.contractor_avatar || "";

      await sendPushNotification(
        ownerId,
        "Nova Solicitação de Chat 💬",
        `${requesterName} quer conversar com você sobre seu perfil profissional`,
        {
          type: "request",
          requestType: "professional",
          profileId: professionalId,
          vacancyId: "",
          userRole: professionalData.role || "worker",
        },
        requesterAvatar,
      );

      logger.info(`✅ Notificação de chat request enviada!`);
      logger.info(`════════════════════════════════════════\n`);
    } catch (err) {
      logger.error(`❌❌❌ ERRO AO PROCESSAR CHAT REQUEST ❌❌❌`);
      logger.error(`Erro:`, err);
    }
  },
);

// ============================================================
// FUNCTION - CHAT REQUEST NOTIFICATION (VACANCY)
// ============================================================

export const onVacancyChatRequestCreated = onValueCreated(
  {
    ref: "/vacancy/{vacancyId}/views/request_views/{requesterId}",
    region: "us-central1",
  },
  async (event) => {
    const vacancyId = event.params.vacancyId;
    const requesterId = event.params.requesterId;
    const requestData = event.data.val() as any;

    try {
      // ✅ VERIFICA SE JÁ EXISTIA (evita duplicata)
      const existingSnap = await admin
        .database()
        .ref(`vacancy/${vacancyId}/views/request_views/${requesterId}`)
        .once("value");

      if (!existingSnap.exists() || existingSnap.val() === null) {
        logger.info(`⚠️ Nó removido durante processamento, ignorando`);
        return;
      }

      logger.info(`\n🎯 NOVA CANDIDATURA VACANCY (ÚNICA)`);
      logger.info(`Vaga: ${vacancyId} | Candidato: ${requesterId}`);

      const vacancySnap = await admin
        .database()
        .ref(`vacancy/${vacancyId}`)
        .once("value");

      const vacancyData = vacancySnap.val() as Record<string, any>;
      const ownerId = vacancyData.local_id as string;

      if (!ownerId) {
        logger.warn(`⚠️ Vaga sem local_id`);
        return;
      }

      // ✅ INCREMENTA BADGE (ÚNICO)
      await incrementRequestBadge(ownerId);

      const candidateName = requestData.worker_name || "Candidato";
      const candidateAvatar = requestData.worker_avatar || "";

      // ✅ PUSH NOTIFICATION
      await sendPushNotification(
        ownerId,
        "🎯 Nova Candidatura!",
        `${candidateName} se candidatou à sua vaga "${vacancyData.title || "Vaga"}"`,
        {
          type: "vacancy_request",
          vacancyId,
          candidateId: requesterId,
          candidateName,
          candidateAvatar,
        },
        candidateAvatar,
      );

      logger.info(`✅ Badge + Push enviados para: ${ownerId}`);
      logger.info(`\n✅ PROCESSADO SEM DUPLICATA`);
    } catch (err: any) {
      logger.error(`❌ ERRO NA CANDIDATURA:`, err);
    }
  },
);
// ============================================================
// FUNCTION - CHAT CREATED
// ============================================================

export const onChatCreated = onValueCreated(
  {
    ref: "/Chats/{chatId}",
    region: "us-central1",
  },
  async (event) => {
    const chatId = event.params.chatId;
    const chatData = event.data.val() as any;

    if (!chatData) return;

    try {
      const { employee, contractor } = chatData;

      const contractorInfo = await getSenderInfo(contractor);

      await sendPushNotification(
        employee,
        "Solicitação Aceita! 🎉",
        `${contractorInfo.name} aceitou sua solicitação de chat`,
        {
          type: "chat_accepted",
          chatId,
          senderId: contractor,
          senderName: contractorInfo.name,
          senderAvatar: contractorInfo.avatar || "",
        },
        contractorInfo.avatar,
      );

      logger.info(
        `✅ Notificação de chat aceito enviada para employee: ${employee}`,
      );
    } catch (err) {
      logger.error("Erro em onChatCreated", { error: err });
    }
  },
);

// ============================================================
// FUNCTION - CHECK EXPIRING PROFESSIONALS
// ============================================================

export const checkExpiringProfessionals = onSchedule(
  {
    schedule: "every 1 hours",
    timeZone: "America/Sao_Paulo",
    region: "us-central1",
  },
  async (_event) => {
    logger.info("\n═══════════════════════════════════════════");
    logger.info("🕐 VERIFICANDO PERFIS PRÓXIMOS DA EXPIRAÇÃO");
    logger.info("═══════════════════════════════════════════\n");

    try {
      const now = Date.now();
      const minTime = now + 1.5 * 60 * 60 * 1000;
      const maxTime = now + 2.5 * 60 * 60 * 1000;

      logger.info(`⏰ Janela de verificação:`);
      logger.info(`   Min: ${new Date(minTime).toISOString()}`);
      logger.info(`   Max: ${new Date(maxTime).toISOString()}\n`);

      const professionalsSnap = await admin
        .database()
        .ref("professionals")
        .orderByChild("status")
        .equalTo("active")
        .once("value");

      if (!professionalsSnap.exists()) {
        logger.info("ℹ️ Nenhum perfil profissional ativo encontrado");
        return;
      }

      const professionals = professionalsSnap.val() as Record<string, any>;
      const totalProfessionals = Object.keys(professionals).length;

      logger.info(`📊 Total de perfis ativos: ${totalProfessionals}\n`);

      let notificationsSent = 0;
      let errors = 0;
      let skipped = 0;

      for (const [professionalId, professionalData] of Object.entries(
        professionals,
      )) {
        try {
          const expiresAt = professionalData.expires_at;

          if (!expiresAt) {
            skipped++;
            continue;
          }

          const expirationTimestamp = new Date(expiresAt).getTime();

          if (
            expirationTimestamp >= minTime &&
            expirationTimestamp <= maxTime
          ) {
            const localId = professionalData.local_id;

            if (!localId) {
              skipped++;
              continue;
            }

            const lastNotifiedSnap = await admin
              .database()
              .ref(
                `professionals/${professionalId}/last_expiration_notification`,
              )
              .once("value");

            const lastNotified = lastNotifiedSnap.val();
            if (lastNotified && now - lastNotified < 3 * 60 * 60 * 1000) {
              skipped++;
              continue;
            }

            const userSnap = await admin
              .database()
              .ref(`Users/${localId}`)
              .once("value");

            if (!userSnap.exists()) {
              skipped++;
              continue;
            }

            const userData = userSnap.val() as Record<string, any>;
            const fcmToken = userData.fcmToken;

            if (!fcmToken) {
              skipped++;
              continue;
            }

            const timeLeft = expirationTimestamp - now;
            const hoursLeft = Math.floor(timeLeft / (60 * 60 * 1000));
            const minutesLeft = Math.floor(
              (timeLeft % (60 * 60 * 1000)) / (60 * 1000),
            );
            const timeMessage =
              hoursLeft > 0
                ? `${hoursLeft}h ${minutesLeft}min`
                : `${minutesLeft} minutos`;

            const message: admin.messaging.Message = {
              token: fcmToken,
              data: {
                type: "expiration_warning",
                professionalId,
                expiresAt,
                hoursLeft: hoursLeft.toString(),
                minutesLeft: minutesLeft.toString(),
                notificationTitle: "⏰ Seu perfil está expirando!",
                notificationBody: `Seu perfil profissional expira em ${timeMessage}. Renove agora para continuar visível!`,
              },
              android: {
                priority: "high",
              },
              apns: {
                headers: {
                  "apns-priority": "10",
                  "apns-push-type": "alert",
                },
                payload: {
                  aps: {
                    alert: {
                      title: "⏰ Seu perfil está expirando!",
                      body: `Seu perfil profissional expira em ${timeMessage}. Renove agora para continuar visível!`,
                    },
                    sound: "default",
                    badge: 1,
                  },
                },
              },
            };

            await admin.messaging().send(message);

            await admin
              .database()
              .ref(
                `professionals/${professionalId}/last_expiration_notification`,
              )
              .set(now);

            notificationsSent++;
            logger.info(
              `✅ Notificação de expiração enviada: ${professionalId}`,
            );
          }
        } catch (error: any) {
          errors++;
          logger.error(`❌ Erro ao processar perfil ${professionalId}:`, error);

          if (
            error.code === "messaging/invalid-registration-token" ||
            error.code === "messaging/registration-token-not-registered"
          ) {
            const localId = professionalData?.local_id;
            if (localId) {
              await admin.database().ref(`Users/${localId}/fcmToken`).remove();
            }
          }
        }
      }

      logger.info("\n═══════════════════════════════════════════");
      logger.info("✅ VERIFICAÇÃO CONCLUÍDA");
      logger.info(`   Total: ${totalProfessionals}`);
      logger.info(`   📨 Enviadas: ${notificationsSent}`);
      logger.info(`   ⏭️ Puladas: ${skipped}`);
      logger.info(`   ❌ Erros: ${errors}`);
      logger.info("═══════════════════════════════════════════\n");
    } catch (error) {
      logger.error("\n❌❌❌ ERRO CRÍTICO NA VERIFICAÇÃO ❌❌❌");
      logger.error("Erro:", error);
    }
  },
);
