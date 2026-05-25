import * as admin from "firebase-admin";
import { onValueCreated } from "firebase-functions/v2/database";
import { onValueDeleted } from "firebase-functions/v2/database";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";

const serviceAccount = require("../serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://obra-7ebd9-default-rtdb.firebaseio.com",
});

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
// HELPER - NORMALIZAR REQUESTS (MAP -> ARRAY)
// ============================================================

function _normalizeRequests(requests: any): string[] {
  if (!requests) return [];
  if (Array.isArray(requests)) return requests;
  if (typeof requests === "object") {
    return Object.values(requests).filter(
      (v) => typeof v === "string",
    ) as string[];
  }
  return [];
}

// ============================================================
// HELPER - BADGE ATÔMICO VIA TRANSACTION
// Substitui o antigo recalculateChatBadge que fazia 3 reads
// Agora usa transaction para increment/decrement (1 read + 1 write)
// ============================================================

async function adjustChatBadge(userId: string, delta: number) {
  try {
    const badgeRef = admin.database().ref(`badges/${userId}/unread_chats`);
    await badgeRef.transaction((current: number | null) => {
      const val = (current || 0) + delta;
      return Math.max(0, Math.min(val, 9));
    });
    logger.info(`Badge chat ajustado: ${userId} (delta: ${delta})`);
  } catch (error) {
    logger.error(`Erro ao ajustar badge chat de ${userId}:`, error);
  }
}

async function adjustRequestBadge(userId: string, delta: number) {
  try {
    const badgeRef = admin.database().ref(`badges/${userId}/unread_requests`);
    await badgeRef.transaction((current: number | null) => {
      const val = (current || 0) + delta;
      return Math.max(0, Math.min(val, 9));
    });
    logger.info(`Badge request ajustado: ${userId} (delta: ${delta})`);
  } catch (error) {
    logger.error(`Erro ao ajustar badge request de ${userId}:`, error);
  }
}

// ============================================================
// HELPER - RECALCULAR BADGE COMPLETO (usado apenas no cleanup semanal)
// ============================================================

async function recalculateChatBadge(userId: string) {
  try {
    const [employeeChatsSnap, contractorChatsSnap] = await Promise.all([
      admin.database().ref("Chats")
        .orderByChild("employee").equalTo(userId).once("value"),
      admin.database().ref("Chats")
        .orderByChild("contractor").equalTo(userId).once("value"),
    ]);

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

    await admin.database().ref(`badges/${userId}/unread_chats`).set(totalUnread);
    await admin.database().ref(`badges/${userId}/updated_at`).set(Date.now());

    logger.info(`Badge recalculado: ${userId} -> ${totalUnread} chats`);
  } catch (error) {
    logger.error(`Erro ao recalcular badge de ${userId}:`, error);
  }
}

// ============================================================
// HELPER - VERIFICAR E CORRIGIR BADGE (cleanup semanal)
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
    const badgeSnap = await admin.database()
      .ref(`badges/${userId}`).once("value");
    result.readsUsed++;

    if (badgeSnap.exists()) {
      const badgeData = badgeSnap.val() as BadgeData;
      result.currentBadge = {
        unread_chats: badgeData.unread_chats || 0,
        unread_requests: badgeData.unread_requests || 0,
      };
    }

    let unreadChats = 0;

    // Paralelizar as 2 queries de chats
    const [employeeChatsSnap, contractorChatsSnap] = await Promise.all([
      admin.database().ref("Chats")
        .orderByChild("employee").equalTo(userId).once("value"),
      admin.database().ref("Chats")
        .orderByChild("contractor").equalTo(userId).once("value"),
    ]);
    result.readsUsed += 2;

    if (employeeChatsSnap.exists()) {
      const chats = employeeChatsSnap.val() as Record<string, any>;
      for (const chatId in chats) {
        if ((chats[chatId].unreadCount?.employee || 0) === 1) unreadChats++;
      }
    }

    if (contractorChatsSnap.exists()) {
      const chats = contractorChatsSnap.val() as Record<string, any>;
      for (const chatId in chats) {
        if ((chats[chatId].unreadCount?.contractor || 0) === 1) unreadChats++;
      }
    }

    unreadChats = Math.min(unreadChats, 9);

    let unreadRequests = 0;

    if (userRole === "worker") {
      const profilesSnap = await admin.database().ref("professionals")
        .orderByChild("local_id").equalTo(userId).once("value");
      result.readsUsed++;

      if (profilesSnap.exists()) {
        const profiles = profilesSnap.val() as Record<string, any>;
        for (const profileId in profiles) {
          const requestViews = profiles[profileId].views?.request_views;
          if (requestViews) {
            for (const reqId in requestViews) {
              if (requestViews[reqId].viewed_by_owner === false)
                unreadRequests++;
            }
          }
        }
      }
    } else {
      const vacanciesSnap = await admin.database().ref("vacancy")
        .orderByChild("local_id").equalTo(userId).once("value");
      result.readsUsed++;

      if (vacanciesSnap.exists()) {
        const vacancies = vacanciesSnap.val() as Record<string, any>;
        for (const vacancyId in vacancies) {
          const requestViews = vacancies[vacancyId].views?.request_views;
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

    result.calculatedBadge = {
      unread_chats: unreadChats,
      unread_requests: unreadRequests,
    };

    const needsCorrection =
      result.currentBadge.unread_chats !== unreadChats ||
      result.currentBadge.unread_requests !== unreadRequests;

    if (needsCorrection) {
      logger.info(`Badge incorreto para ${userId} - corrigindo`);
      await admin.database().ref(`badges/${userId}`).set({
        unread_chats: unreadChats,
        unread_requests: unreadRequests,
        updated_at: Date.now(),
      });
      result.writesUsed++;
      result.wasCorrected = true;
    }

    result.success = true;
  } catch (error: any) {
    logger.error(`Erro ao verificar badge de ${userId}:`, error);
    result.error = error.message || String(error);
  }

  return result;
}

// ============================================================
// HELPER - VERIFICAR MÚLTIPLOS USUÁRIOS (chunks paralelos)
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

  const entries = Object.entries(userRoles);
  const CHUNK_SIZE = 10;

  for (let i = 0; i < entries.length; i += CHUNK_SIZE) {
    const chunk = entries.slice(i, i + CHUNK_SIZE);
    const results = await Promise.all(
      chunk.map(([userId, role]) => verifyAndFixBadge(userId, role)),
    );

    for (const result of results) {
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
  }

  logger.info(`Badge batch: ${batchResult.totalProcessed} processados, ` +
    `${batchResult.correctedCount} corrigidos, ${batchResult.errorCount} erros, ` +
    `${batchResult.totalReads} reads, ${batchResult.totalWrites} writes`);

  return batchResult;
}

// ============================================================
// HELPER - VERIFICAR TODOS OS BADGES
// ============================================================

async function verifyAllBadges(): Promise<BatchResult> {
  const badgesSnap = await admin.database().ref("badges").once("value");

  if (!badgesSnap.exists()) {
    logger.info("Nenhum badge encontrado");
    return {
      totalProcessed: 0, correctCount: 0, correctedCount: 0,
      errorCount: 0, totalReads: 0, totalWrites: 0,
    };
  }

  const badges = badgesSnap.val() as Record<string, any>;
  const userIds = Object.keys(badges);

  // Buscar roles em chunks paralelos para reduzir reads sequenciais
  const CHUNK_SIZE = 20;
  const userRoles: Record<string, "worker" | "contractor"> = {};

  for (let i = 0; i < userIds.length; i += CHUNK_SIZE) {
    const chunk = userIds.slice(i, i + CHUNK_SIZE);
    const snaps = await Promise.all(
      chunk.map((uid) =>
        admin.database().ref(`Users/${uid}/role`).once("value"),
      ),
    );

    for (let j = 0; j < chunk.length; j++) {
      const snap = snaps[j];
      if (snap.exists()) {
        const role = snap.val() as string;
        userRoles[chunk[j]] = (role === "contractor") ? "contractor" : "worker";
      }
    }
  }

  return await verifyMultipleUsers(userRoles);
}

// ============================================================
// CLOUD FUNCTION - BADGE CLEANUP SEMANAL (ÚNICO)
// Removido: manualBadgeCleanup (era duplicado desnecessário)
// ============================================================

export const weeklyBadgeCleanup = onSchedule(
  {
    schedule: "0 3 * * 0",
    timeZone: "America/Sao_Paulo",
    region: "us-central1",
  },
  async (_event) => {
    logger.info("MANUTENCAO SEMANAL - BADGE CLEANUP");

    try {
      await verifyAllBadges();
      logger.info("Manutencao semanal concluida");
    } catch (error) {
      logger.error("Erro critico na manutencao semanal:", error);
    }
  },
);

// ============================================================
// CLOUD FUNCTION - VERIFICAR BADGE INDIVIDUAL (HTTP)
// Adicionado: autenticação via Firebase Auth token
// ============================================================

export const verifyUserBadge = onRequest(
  { region: "us-central1", cors: true },
  async (request, response) => {
    // Verificar autenticação
    const authHeader = request.headers.authorization;
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      response.status(401).send({ error: "Unauthorized - missing Bearer token" });
      return;
    }

    try {
      await admin.auth().verifyIdToken(authHeader.split("Bearer ")[1]);
    } catch (_authError) {
      response.status(401).send({ error: "Unauthorized - invalid token" });
      return;
    }

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
    const userSnap = await admin.database()
      .ref(`Users/${userId}`).once("value");
    if (!userSnap.exists()) return { name: "Usuario", avatar: "" };
    const userData = userSnap.val() as Record<string, any>;
    return {
      name: userData?.Name || "Usuario",
      avatar: userData?.avatar || "",
    };
  } catch (_error) {
    return { name: "Usuario", avatar: "" };
  }
}

async function isUserOnlineInChat(
  chatId: string,
  userRole: "employee" | "contractor",
): Promise<boolean> {
  try {
    const statusSnap = await admin.database()
      .ref(`Chats/${chatId}/participants/${userRole}`).once("value");
    return statusSnap.val() === "online";
  } catch (_error) {
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
    const tokenSnap = await admin.database()
      .ref(`Users/${userId}/fcmToken`).once("value");

    if (!tokenSnap.exists()) return;

    const token = tokenSnap.val() as string;

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
      android: { priority: "high" },
      apns: {
        headers: { "apns-priority": "10", "apns-push-type": "alert" },
        payload: {
          aps: {
            alert: { title: senderName, body: displayText },
            sound: "default",
            badge: 1,
            "mutable-content": 1,
            "thread-id": chatId,
          },
        },
      },
    };

    await admin.messaging().send(message);
    logger.info(`Push chat enviada para ${userId}`);
  } catch (error: any) {
    logger.error(`Erro ao enviar push chat para ${userId}:`, error);
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
    const tokenSnap = await admin.database()
      .ref(`Users/${userId}/fcmToken`).once("value");

    if (!tokenSnap.exists()) return;

    const token = tokenSnap.val() as string;

    const message: admin.messaging.Message = {
      token,
      data: {
        ...data,
        senderAvatar: avatarUrl || "",
        notificationTitle: title,
        notificationBody: body,
      },
      android: { priority: "high" },
      apns: {
        headers: { "apns-priority": "10", "apns-push-type": "alert" },
        payload: {
          aps: {
            alert: { title, body },
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    await admin.messaging().send(message);
    logger.info(`Push enviada para ${userId}`);
  } catch (error: any) {
    logger.error(`Erro ao enviar push para ${userId}:`, error);
    if (
      error.code === "messaging/invalid-registration-token" ||
      error.code === "messaging/registration-token-not-registered"
    ) {
      await admin.database().ref(`Users/${userId}/fcmToken`).remove();
    }
  }
}

// ============================================================
// HELPER - LIMPAR CANDIDATURAS E BADGES
// Otimizado: batch updates em vez de writes individuais
// ============================================================

async function cleanupCandidaturesBadges(userId: string, userRole: string) {
  const database = admin.database();
  const batchUpdates: Record<string, any> = {};
  let badgeDecrementCount = 0;

  if (userRole === "worker") {
    const vacanciesSnap = await database.ref("vacancy")
      .orderByChild("status").equalTo("active").once("value");

    if (!vacanciesSnap.exists()) return;

    const vacancies = vacanciesSnap.val() as Record<string, any>;

    for (const [vacancyId, vacancyData] of Object.entries(vacancies)) {
      const requests = _normalizeRequests(vacancyData.requests);
      if (!requests.includes(userId)) continue;

      const requestViews = vacancyData.views?.request_views || {};
      const ownerId = vacancyData.local_id as string;

      if (requestViews[userId]?.viewed_by_owner === false && ownerId) {
        badgeDecrementCount++;
      }

      const filteredRequests = requests.filter((id) => id !== userId);
      batchUpdates[`vacancy/${vacancyId}/requests`] =
        filteredRequests.length > 0 ? filteredRequests : null;
      batchUpdates[`vacancy/${vacancyId}/views/request_views/${userId}`] = null;
    }
  } else {
    const professionalsSnap = await database.ref("professionals")
      .orderByChild("status").equalTo("active").once("value");

    if (!professionalsSnap.exists()) return;

    const professionals = professionalsSnap.val() as Record<string, any>;

    for (const [professionalId, professionalData] of Object.entries(professionals)) {
      const requests = _normalizeRequests(professionalData.requests);
      if (!requests.includes(userId)) continue;

      const requestViews = professionalData.views?.request_views || {};
      const ownerId = professionalData.local_id as string;

      if (requestViews[userId]?.viewed_by_owner === false && ownerId) {
        badgeDecrementCount++;
      }

      const filteredRequests = requests.filter((id) => id !== userId);
      batchUpdates[`professionals/${professionalId}/requests`] =
        filteredRequests.length > 0 ? filteredRequests : null;
      batchUpdates[`professionals/${professionalId}/views/request_views/${userId}`] = null;
    }
  }

  // Aplica todas as remoções de candidatura em 1 batch write
  if (Object.keys(batchUpdates).length > 0) {
    await database.ref().update(batchUpdates);
  }

  // Decrementa badges dos owners afetados via transactions
  // Coletamos os ownerIds com decrement necessário
  if (badgeDecrementCount > 0) {
    // Re-iterar para pegar ownerIds que precisam de decrement
    const nodeType = userRole === "worker" ? "vacancy" : "professionals";
    const snap = await database.ref(nodeType)
      .orderByChild("status").equalTo("active").once("value");

    if (snap.exists()) {
      const items = snap.val() as Record<string, any>;
      const ownerDecrements: Record<string, number> = {};

      for (const [_id, data] of Object.entries(items)) {
        const requestViews = data.views?.request_views || {};
        if (requestViews[userId]?.viewed_by_owner === false && data.local_id) {
          ownerDecrements[data.local_id] = (ownerDecrements[data.local_id] || 0) + 1;
        }
      }

      await Promise.all(
        Object.entries(ownerDecrements).map(([ownerId, count]) =>
          adjustRequestBadge(ownerId, -count),
        ),
      );
    }
  }

  logger.info(`Cleanup candidaturas: ${Object.keys(batchUpdates).length / 2} removidas, ` +
    `${badgeDecrementCount} badges decrementados`);
}

// ============================================================
// CLOUD FUNCTION - DELETAR USUARIO
// ============================================================

export const onUserDeleted = onValueDeleted(
  {
    ref: "/Users/{userId}",
    region: "us-central1",
  },
  async (event) => {
    const userId = event.params.userId;

    try {
      logger.info(`USUARIO DELETADO: ${userId}`);

      const beforeData = event.data.val() as any;
      const userRole = beforeData?.role || "worker";

      // PASSO 1: Marca como deletado
      const expiresAt = Date.now() + 24 * 60 * 60 * 1000;
      await admin.database().ref(`deleted_users/${userId}`).set({
        expires_at: expiresAt,
        role: userRole,
        deleted_at: Date.now(),
      });

      // PASSO 2: Limpa candidaturas e decrementa badges
      await cleanupCandidaturesBadges(userId, userRole);

      // PASSO 3: Remove badge do usuario
      await admin.database().ref(`badges/${userId}`).remove();

      logger.info(`Processo de exclusao completo para ${userId}`);
    } catch (error) {
      logger.error(`Erro ao processar exclusao de ${userId}:`, error);
    }
  },
);

// ============================================================
// CLOUD FUNCTION - LIMPAR USUARIOS DELETADOS ANTIGOS
// ============================================================

export const cleanupDeletedUsers = onSchedule(
  {
    schedule: "every 24 hours",
    timeZone: "America/Sao_Paulo",
    region: "us-central1",
  },
  async (_event) => {
    try {
      const now = Date.now();
      const deletedUsersSnap = await admin.database()
        .ref("deleted_users").once("value");

      if (!deletedUsersSnap.exists()) return;

      const deletedUsers = deletedUsersSnap.val() as Record<string, any>;
      const updates: Record<string, null> = {};

      for (const [userId, data] of Object.entries(deletedUsers)) {
        const expiresAt = data?.expires_at || data;
        if (now > expiresAt) {
          updates[`deleted_users/${userId}`] = null;
        }
      }

      if (Object.keys(updates).length > 0) {
        await admin.database().ref().update(updates);
        logger.info(`Cleanup: ${Object.keys(updates).length} usuarios deletados removidos`);
      }
    } catch (error) {
      logger.error("Erro na limpeza de usuarios deletados:", error);
    }
  },
);

// ============================================================
// CLOUD FUNCTION - NOVA MENSAGEM NO CHAT
// Otimizado: usa adjustChatBadge (transaction) em vez de
// recalculateChatBadge (3 reads + 1 write)
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
      const chatSnap = await admin.database()
        .ref(`Chats/${chatId}`).once("value");
      if (!chatSnap.exists()) return;

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

      // Primeira mensagem do chat - sem notificacao
      const isFirstMessage =
        !metadata?.last_message || metadata.last_message === "";

      if (isFirstMessage) {
        await admin.database()
          .ref(`Chats/${chatId}/unreadCount/${receiverRole}`).set(0);
        return;
      }

      const isOnline = await isUserOnlineInChat(chatId, receiverRole);
      const previousUnread = chatData.unreadCount?.[receiverRole] || 0;
      const newUnreadCount = isOnline ? 0 : 1;

      await admin.database()
        .ref(`Chats/${chatId}/unreadCount/${receiverRole}`).set(newUnreadCount);

      // Ajusta badge incrementalmente via transaction
      // Se unread mudou de 0 -> 1: incrementa badge
      // Se unread continua 1 -> 1: nao muda badge (ja contado)
      // Se receiver esta online (1 -> 0 ou 0 -> 0): nao incrementa
      if (newUnreadCount === 1 && previousUnread === 0) {
        await adjustChatBadge(receiver, +1);
      } else if (newUnreadCount === 0 && previousUnread === 1) {
        await adjustChatBadge(receiver, -1);
      }

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
    } catch (err) {
      logger.error(`Erro em onChatMessageCreated (${chatId}):`, err);
    }
  },
);

// ============================================================
// CLOUD FUNCTION - SOLICITACAO DE CHAT (PROFESSIONAL)
// UNIFICADO: combina onProfessionalChatRequestCreated +
// onProfessionalRequestViewCreated (que eram duplicados no mesmo path)
// ============================================================

export const onProfessionalChatRequestCreated = onValueCreated(
  {
    ref: "/professionals/{professionalId}/views/request_views/{requesterId}",
    region: "us-central1",
  },
  async (event) => {
    const professionalId = event.params.professionalId;
    const requesterId = event.params.requesterId;
    const requestData = event.data.val() as any;

    try {
      const professionalSnap = await admin.database()
        .ref(`professionals/${professionalId}`).once("value");

      if (!professionalSnap.exists()) return;

      const professionalData = professionalSnap.val() as Record<string, any>;
      const ownerId = professionalData.local_id as string;
      if (!ownerId) return;

      // 1. Incrementa badge via transaction
      await adjustRequestBadge(ownerId, +1);

      // 2. Envia push notification
      const requesterName = requestData.contractor_name || "Alguem";
      const requesterAvatar = requestData.contractor_avatar || "";

      await sendPushNotification(
        ownerId,
        "Nova Solicitacao de Chat",
        `${requesterName} quer conversar com voce sobre seu perfil profissional`,
        {
          type: "request",
          requestType: "professional",
          profileId: professionalId,
          vacancyId: "",
          userRole: professionalData.role || "worker",
        },
        requesterAvatar,
      );

      // 3. Cria notificacao no historico (antes era trigger separado)
      const now = Date.now();
      const notificationRef = admin.database()
        .ref(`notification_history/${ownerId}`).push();

      await notificationRef.set({
        type: "professional_request",
        target_id: professionalId,
        target_title: professionalData.profession || "Perfil Profissional",
        requester_id: requesterId,
        requester_name: requesterName,
        requester_avatar: requesterAvatar,
        status: "unviewed",
        created_at: now,
        updated_at: now,
        expires_at: now + 30 * 24 * 60 * 60 * 1000,
        viewed_at: null,
        responded_at: null,
      });

      logger.info(`Request professional processado: ${professionalId} por ${requesterId}`);
    } catch (err) {
      logger.error(`Erro em onProfessionalChatRequestCreated:`, err);
    }
  },
);

// ============================================================
// CLOUD FUNCTION - SOLICITACAO DE CHAT (VACANCY)
// UNIFICADO: combina onVacancyChatRequestCreated +
// onVacancyRequestViewCreated (que eram duplicados no mesmo path)
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
      // Verificar se no ainda existe (protecao contra retry)
      const existingSnap = await admin.database()
        .ref(`vacancy/${vacancyId}/views/request_views/${requesterId}`)
        .once("value");

      if (!existingSnap.exists() || existingSnap.val() === null) return;

      const vacancySnap = await admin.database()
        .ref(`vacancy/${vacancyId}`).once("value");
      if (!vacancySnap.exists()) return;

      const vacancyData = vacancySnap.val() as Record<string, any>;
      const ownerId = vacancyData.local_id as string;
      if (!ownerId) return;

      // 1. Incrementa badge via transaction
      await adjustRequestBadge(ownerId, +1);

      // 2. Envia push notification
      const candidateName = requestData.worker_name || "Candidato";
      const candidateAvatar = requestData.worker_avatar || "";

      await sendPushNotification(
        ownerId,
        "Nova Candidatura!",
        `${candidateName} se candidatou a sua vaga "${vacancyData.title || "Vaga"}"`,
        {
          type: "vacancy_request",
          vacancyId,
          candidateId: requesterId,
          candidateName,
          candidateAvatar,
        },
        candidateAvatar,
      );

      // 3. Cria notificacao no historico (antes era trigger separado)
      const now = Date.now();
      const notificationRef = admin.database()
        .ref(`notification_history/${ownerId}`).push();

      await notificationRef.set({
        type: "vacancy_request",
        target_id: vacancyId,
        target_title: vacancyData.title || "Vaga",
        requester_id: requesterId,
        requester_name: candidateName,
        requester_avatar: candidateAvatar,
        status: "unviewed",
        created_at: now,
        updated_at: now,
        expires_at: now + 30 * 24 * 60 * 60 * 1000,
        viewed_at: null,
        responded_at: null,
      });

      logger.info(`Request vacancy processado: ${vacancyId} por ${requesterId}`);
    } catch (err: any) {
      logger.error(`Erro em onVacancyChatRequestCreated:`, err);
    }
  },
);

// ============================================================
// CLOUD FUNCTION - CHAT CRIADO
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
        "Solicitacao Aceita!",
        `${contractorInfo.name} aceitou sua solicitacao de chat`,
        {
          type: "chat_accepted",
          chatId,
          senderId: contractor,
          senderName: contractorInfo.name,
          senderAvatar: contractorInfo.avatar || "",
        },
        contractorInfo.avatar,
      );
    } catch (err) {
      logger.error("Erro em onChatCreated:", err);
    }
  },
);

// ============================================================
// CLOUD FUNCTION - USUARIO BLOQUEADO
// Otimizado: substituido ref("Chats").get() (full table scan)
// por 2 queries indexadas + batch updates
// ============================================================

export const onUserBlocked = onValueCreated(
  {
    ref: "/Users/{userId}/blocked_users/{blockedUserId}",
    region: "us-central1",
  },
  async (event) => {
    const blockerId = event.params.userId;
    const blockedId = event.params.blockedUserId;

    try {
      logger.info(`USUARIO BLOQUEADO: ${blockerId} -> ${blockedId}`);

      const updates: Record<string, any> = {
        [`blocked_by/${blockedId}/${blockerId}`]: true,
      };

      let blockedChatId: string | null = null;

      // OTIMIZADO: 2 queries indexadas em vez de ref("Chats").get()
      const [asContractorSnap, asEmployeeSnap] = await Promise.all([
        admin.database().ref("Chats")
          .orderByChild("contractor").equalTo(blockerId).once("value"),
        admin.database().ref("Chats")
          .orderByChild("employee").equalTo(blockerId).once("value"),
      ]);

      // Procurar chat entre blockerId e blockedId
      const findChatBetween = (
        snapshot: admin.database.DataSnapshot,
        blockerField: string,
      ): string | null => {
        if (!snapshot.exists()) return null;
        const chats = snapshot.val() as Record<string, any>;
        const otherField = blockerField === "contractor" ? "employee" : "contractor";
        for (const [chatId, chatData] of Object.entries(chats)) {
          if (chatData[otherField] === blockedId && !chatData.block_dialog) {
            return chatId;
          }
        }
        return null;
      };

      blockedChatId =
        findChatBetween(asContractorSnap, "contractor") ||
        findChatBetween(asEmployeeSnap, "employee");

      if (blockedChatId) {
        updates[`Chats/${blockedChatId}/block_dialog`] = true;
        updates[`Chats/${blockedChatId}/blocked_by`] = blockerId;
        updates[`Chats/${blockedChatId}/blocked_at`] = Date.now();
        updates[`Chats/${blockedChatId}/unreadCount/employee`] = 0;
        updates[`Chats/${blockedChatId}/unreadCount/contractor`] = 0;
      }

      await admin.database().ref().update(updates);

      // Recalcula badge de chats para ambos (apenas se chat foi bloqueado)
      if (blockedChatId) {
        await Promise.all([
          recalculateChatBadge(blockerId),
          recalculateChatBadge(blockedId),
        ]);
      }

      // Helper reutilizavel: remove candidatura e acumula em batch
      const candidatureUpdates: Record<string, any> = {};
      const ownerDecrements: Record<string, number> = {};

      async function collectCandidatureRemovals(
        nodeType: "vacancy" | "professionals",
        candidateId: string,
        ownerId: string,
      ): Promise<void> {
        const snap = await admin.database().ref(nodeType)
          .orderByChild("local_id").equalTo(ownerId).once("value");

        if (!snap.exists()) return;

        const items = snap.val() as Record<string, any>;
        for (const [nodeId, nodeData] of Object.entries(items)) {
          const requests = _normalizeRequests(nodeData.requests);
          if (!requests.includes(candidateId)) continue;

          const requestViews: Record<string, any> =
            nodeData.views?.request_views ?? {};

          if (requestViews[candidateId]?.viewed_by_owner === false) {
            ownerDecrements[ownerId] = (ownerDecrements[ownerId] || 0) + 1;
          }

          const filteredRequests = requests.filter((id) => id !== candidateId);
          candidatureUpdates[`${nodeType}/${nodeId}/requests`] =
            filteredRequests.length > 0 ? filteredRequests : null;
          candidatureUpdates[`${nodeType}/${nodeId}/views/request_views/${candidateId}`] = null;
        }
      }

      // Executar as 4 verificacoes de candidaturas em paralelo (2+2)
      await Promise.all([
        collectCandidatureRemovals("vacancy", blockedId, blockerId),
        collectCandidatureRemovals("professionals", blockedId, blockerId),
        collectCandidatureRemovals("vacancy", blockerId, blockedId),
        collectCandidatureRemovals("professionals", blockerId, blockedId),
      ]);

      // Batch update de todas as candidaturas
      if (Object.keys(candidatureUpdates).length > 0) {
        await admin.database().ref().update(candidatureUpdates);
      }

      // Decrementa badges dos owners afetados via transaction
      await Promise.all(
        Object.entries(ownerDecrements).map(([ownerId, count]) =>
          adjustRequestBadge(ownerId, -count),
        ),
      );

      logger.info(`Bloqueio processado: ${blockerId} -> ${blockedId}`);
    } catch (error) {
      logger.error(`Erro ao processar bloqueio ${blockerId} -> ${blockedId}:`, error);
    }
  },
);

// ============================================================
// CLOUD FUNCTION - LIMPAR NOTIFICACOES EXPIRADAS (diario)
// Otimizado: batch delete em vez de deletes individuais
// ============================================================

export const cleanExpiredNotifications = onSchedule(
  {
    schedule: "every 24 hours",
    timeZone: "America/Sao_Paulo",
    region: "us-central1",
  },
  async (_event) => {
    try {
      const now = Date.now();
      const usersSnap = await admin.database()
        .ref("notification_history").once("value");

      if (!usersSnap.exists()) return;

      const users = usersSnap.val() as Record<string, any>;
      const updates: Record<string, null> = {};

      for (const [userId, notifications] of Object.entries(users)) {
        for (const [notifId, notifData] of Object.entries(
          notifications as Record<string, any>,
        )) {
          const expiresAt = notifData.expires_at as number;
          if (now > expiresAt) {
            updates[`notification_history/${userId}/${notifId}`] = null;
          }
        }
      }

      if (Object.keys(updates).length > 0) {
        await admin.database().ref().update(updates);
        logger.info(`Notificacoes expiradas: ${Object.keys(updates).length} removidas`);
      }
    } catch (error) {
      logger.error("Erro na limpeza de notificacoes:", error);
    }
  },
);

// ============================================================
// CLOUD FUNCTION - MIGRACAO BLOCKED USERS (one-time HTTP)
// Mantida com autenticacao adicionada
// ============================================================

export const migrateBlockedUsers = onRequest(
  { region: "us-central1", cors: true },
  async (req, res) => {
    // Verificar autenticacao
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      res.status(401).send({ error: "Unauthorized" });
      return;
    }

    try {
      await admin.auth().verifyIdToken(authHeader.split("Bearer ")[1]);
    } catch (_authError) {
      res.status(401).send({ error: "Invalid token" });
      return;
    }

    try {
      const usersSnap = await admin.database().ref("Users").once("value");

      if (!usersSnap.exists()) {
        res.status(200).send({ message: "Nenhum usuario encontrado" });
        return;
      }

      const users = usersSnap.val() as Record<string, any>;
      const updates: Record<string, any> = {};
      let migrated = 0;
      let skipped = 0;

      for (const [userId, userData] of Object.entries(users)) {
        const rawBlocked = userData?.blocked_users;
        if (!rawBlocked) { skipped++; continue; }

        if (
          typeof rawBlocked === "object" &&
          !Array.isArray(rawBlocked) &&
          Object.values(rawBlocked).every((v) => v === true)
        ) {
          for (const blockedId of Object.keys(rawBlocked)) {
            updates[`blocked_by/${blockedId}/${userId}`] = true;
          }
          skipped++;
          continue;
        }

        let blockedIds: string[] = [];
        if (Array.isArray(rawBlocked)) {
          blockedIds = rawBlocked.filter(
            (v: any) => typeof v === "string" && v.length > 0,
          );
        } else if (typeof rawBlocked === "object") {
          blockedIds = Object.values(rawBlocked).filter(
            (v) => typeof v === "string",
          ) as string[];
        }

        if (blockedIds.length === 0) { skipped++; continue; }

        const blockedMap: Record<string, boolean> = {};
        for (const id of blockedIds) {
          blockedMap[id] = true;
          updates[`blocked_by/${id}/${userId}`] = true;
        }
        updates[`Users/${userId}/blocked_users`] = blockedMap;
        migrated++;
      }

      if (Object.keys(updates).length > 0) {
        await admin.database().ref().update(updates);
      }

      res.status(200).send({ migrated, skipped });
    } catch (error) {
      logger.error("Erro na migracao:", error);
      res.status(500).send({ error: String(error) });
    }
  },
);

// ============================================================
// CLOUD FUNCTION - VERIFICAR PERFIS EXPIRANDO
// Otimizado: le apenas fcmToken em vez de User inteiro +
// batch write para last_expiration_notification
// ============================================================

export const checkExpiringProfessionals = onSchedule(
  {
    schedule: "every 1 hours",
    timeZone: "America/Sao_Paulo",
    region: "us-central1",
  },
  async (_event) => {
    try {
      const now = Date.now();
      const minTime = now + 1.5 * 60 * 60 * 1000;
      const maxTime = now + 2.5 * 60 * 60 * 1000;

      const professionalsSnap = await admin.database().ref("professionals")
        .orderByChild("status").equalTo("active").once("value");

      if (!professionalsSnap.exists()) return;

      const professionals = professionalsSnap.val() as Record<string, any>;
      let notificationsSent = 0;
      const batchUpdates: Record<string, any> = {};

      for (const [professionalId, professionalData] of Object.entries(professionals)) {
        try {
          const expiresAt = professionalData.expires_at;
          if (!expiresAt) continue;

          const expirationTimestamp = new Date(expiresAt).getTime();

          if (expirationTimestamp < minTime || expirationTimestamp > maxTime) continue;

          const localId = professionalData.local_id;
          if (!localId) continue;

          const lastNotifiedSnap = await admin.database()
            .ref(`professionals/${professionalId}/last_expiration_notification`)
            .once("value");

          const lastNotified = lastNotifiedSnap.val();
          if (lastNotified && now - lastNotified < 3 * 60 * 60 * 1000) continue;

          // Ler apenas fcmToken em vez do User inteiro
          const tokenSnap = await admin.database()
            .ref(`Users/${localId}/fcmToken`).once("value");

          if (!tokenSnap.exists()) continue;

          const fcmToken = tokenSnap.val() as string;

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
              notificationTitle: "Seu perfil esta expirando!",
              notificationBody: `Seu perfil profissional expira em ${timeMessage}. Renove agora para continuar visivel!`,
            },
            android: { priority: "high" },
            apns: {
              headers: { "apns-priority": "10", "apns-push-type": "alert" },
              payload: {
                aps: {
                  alert: {
                    title: "Seu perfil esta expirando!",
                    body: `Seu perfil profissional expira em ${timeMessage}. Renove agora para continuar visivel!`,
                  },
                  sound: "default",
                  badge: 1,
                },
              },
            },
          };

          await admin.messaging().send(message);

          // Acumula no batch em vez de escrever individualmente
          batchUpdates[
            `professionals/${professionalId}/last_expiration_notification`
          ] = now;

          notificationsSent++;
        } catch (error: any) {
          logger.error(`Erro ao processar perfil ${professionalId}:`, error);

          if (
            error.code === "messaging/invalid-registration-token" ||
            error.code === "messaging/registration-token-not-registered"
          ) {
            const localId = professionalData?.local_id;
            if (localId) {
              batchUpdates[`Users/${localId}/fcmToken`] = null;
            }
          }
        }
      }

      // Batch write para todas as notificacoes de expiracao
      if (Object.keys(batchUpdates).length > 0) {
        await admin.database().ref().update(batchUpdates);
      }

      if (notificationsSent > 0) {
        logger.info(`Expiracao: ${notificationsSent} notificacoes enviadas`);
      }
    } catch (error) {
      logger.error("Erro critico na verificacao de expiracao:", error);
    }
  },
);
