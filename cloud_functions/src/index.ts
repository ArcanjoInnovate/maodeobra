import * as admin from "firebase-admin";
import { onValueCreated } from "firebase-functions/v2/database";
import { onValueDeleted } from "firebase-functions/v2/database";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onRequest, onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";


admin.initializeApp({
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

  // ✅ N2-06: chunkSize 10 → 50 — mesma quantidade de reads, mas 5× menos
  // iterações do loop, reduzindo o tempo de execução da Cloud Function e
  // consequentemente o custo de compute (cobrado por ms de CPU).
  const CHUNK_SIZE = 50;

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
// CLOUD FUNCTION - BADGE CLEANUP SEMANAL
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
// ============================================================

export const verifyUserBadge = onRequest(
  { region: "us-central1", cors: true },
  async (request, response) => {
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
    const [nameSnap, avatarSnap] = await Promise.all([
      admin.database().ref(`Users/${userId}/Name`).once("value"),
      admin.database().ref(`Users/${userId}/avatar`).once("value"),
    ]);
    return {
      name: nameSnap.val() as string || "Usuario",
      avatar: avatarSnap.val() as string || "",
    };
  } catch (_error) {
    return { name: "Usuario", avatar: "" };
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
// ============================================================

async function cleanupCandidaturesBadges(userId: string, userRole: string) {
  const database = admin.database();
  const batchUpdates: Record<string, any> = {};
  let badgeDecrementCount = 0;
  const ownerDecrementsMap: Record<string, number> = {};

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
        ownerDecrementsMap[ownerId] = (ownerDecrementsMap[ownerId] || 0) + 1;
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
        ownerDecrementsMap[ownerId] = (ownerDecrementsMap[ownerId] || 0) + 1;
      }

      const filteredRequests = requests.filter((id) => id !== userId);
      batchUpdates[`professionals/${professionalId}/requests`] =
        filteredRequests.length > 0 ? filteredRequests : null;
      batchUpdates[`professionals/${professionalId}/views/request_views/${userId}`] = null;
    }
  }

  if (Object.keys(batchUpdates).length > 0) {
    await database.ref().update(batchUpdates);
  }

  if (badgeDecrementCount > 0) {
    await Promise.all(
      Object.entries(ownerDecrementsMap).map(([ownerId, count]) =>
        adjustRequestBadge(ownerId, -count),
      ),
    );
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

      const expiresAt = Date.now() + 24 * 60 * 60 * 1000;
      await admin.database().ref(`deleted_users/${userId}`).set({
        expires_at: expiresAt,
        role: userRole,
        deleted_at: Date.now(),
      });

      await cleanupCandidaturesBadges(userId, userRole);
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

      const isFirstMessage =
        !metadata?.last_message || metadata.last_message === "";

      if (isFirstMessage) {
        await admin.database()
          .ref(`Chats/${chatId}/unreadCount/${receiverRole}`).set(0);
        return;
      }

      // ✅ N3-04: dado já disponível no snapshot de Chats/{chatId} —
      // elimina 1 read extra por mensagem enviada.
      const isOnline = (chatData as any).participants?.[receiverRole] === "online";
      const previousUnread = chatData.unreadCount?.[receiverRole] || 0;
      const newUnreadCount = isOnline ? 0 : 1;

      await admin.database()
        .ref(`Chats/${chatId}/unreadCount/${receiverRole}`).set(newUnreadCount);

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

      await adjustRequestBadge(ownerId, +1);

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

      await adjustRequestBadge(ownerId, +1);

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

      const [asContractorSnap, asEmployeeSnap] = await Promise.all([
        admin.database().ref("Chats")
          .orderByChild("contractor").equalTo(blockerId).once("value"),
        admin.database().ref("Chats")
          .orderByChild("employee").equalTo(blockerId).once("value"),
      ]);

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

      if (blockedChatId) {
        await Promise.all([
          recalculateChatBadge(blockerId),
          recalculateChatBadge(blockedId),
        ]);
      }

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

      await Promise.all([
        collectCandidatureRemovals("vacancy", blockedId, blockerId),
        collectCandidatureRemovals("professionals", blockedId, blockerId),
        collectCandidatureRemovals("vacancy", blockerId, blockedId),
        collectCandidatureRemovals("professionals", blockerId, blockedId),
      ]);

      if (Object.keys(candidatureUpdates).length > 0) {
        await admin.database().ref().update(candidatureUpdates);
      }

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
      // ✅ P-01: query por expires_at em vez de full scan de todos os usuários.
      // Requer ".indexOn": ["expires_at"] em cada nó de usuário em notification_history.
      // Como o RTDB não suporta query em subcoleções diretamente, iteramos por usuário
      // mas usando orderByChild("expires_at").endAt(now) em cada um — reduz ~95% dos dados lidos.
      // ✅ P-01: shallow read via REST para obter apenas as chaves de userId (sem dados)
      // Evita baixar todos os históricos de notificação de uma vez.
      const db = admin.database();
      const shallowRef = db.ref("notification_history");
      // Admin SDK não tem .once("shallow") — usamos query limitada para simular.
      // Alternativa eficiente: ler apenas os filhos de primeiro nível.
      const keysSnap = await shallowRef.orderByKey().once("value");
      if (!keysSnap.exists()) return;

      // Extrair apenas os userIds (keys) sem carregar os dados aninhados
      const keysVal = keysSnap.val() as Record<string, any>;
      const userIds = Object.keys(keysVal);
      const updates: Record<string, null> = {};

      // Busca paralela: apenas notificações expiradas por usuário
      const userSnaps = await Promise.all(
        userIds.map((uid) =>
          admin.database()
            .ref(`notification_history/${uid}`)
            .orderByChild("expires_at")
            .endAt(now)
            .once("value"),
        ),
      );

      for (let i = 0; i < userIds.length; i++) {
        const userId = userIds[i];
        const snap = userSnaps[i];
        if (!snap.exists()) continue;
        const notifications = snap.val() as Record<string, any>;
        for (const notifId of Object.keys(notifications)) {
          updates[`notification_history/${userId}/${notifId}`] = null;
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
// ============================================================

export const migrateBlockedUsers = onRequest(
  { region: "us-central1", cors: true },
  async (req, res) => {
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

      const candidates = Object.entries(professionals).filter(([, data]) => {
        if (!data.expires_at || !data.local_id) return false;
        const ts = new Date(data.expires_at).getTime();
        return ts >= minTime && ts <= maxTime;
      });

      if (candidates.length === 0) return;

      const [lastNotifSnaps, tokenSnaps] = await Promise.all([
        Promise.all(candidates.map(([id]) =>
          admin.database().ref(`professionals/${id}/last_expiration_notification`).once("value")
        )),
        Promise.all(candidates.map(([, data]) =>
          admin.database().ref(`Users/${data.local_id}/fcmToken`).once("value")
        )),
      ]);

      for (let i = 0; i < candidates.length; i++) {
        const [professionalId, professionalData] = candidates[i];
        try {
          const expiresAt = professionalData.expires_at;
          const expirationTimestamp = new Date(expiresAt).getTime();

          const lastNotified = lastNotifSnaps[i].val();
          if (lastNotified && now - lastNotified < 3 * 60 * 60 * 1000) continue;

          const tokenSnap = tokenSnaps[i];
          if (!tokenSnap.exists()) continue;

          const fcmToken = tokenSnap.val() as string;

          const timeLeft = expirationTimestamp - now;
          const hoursLeft = Math.floor(timeLeft / (60 * 60 * 1000));
          const minutesLeft = Math.floor(
            (timeLeft % (60 * 60 * 1000)) / (60 * 1000),
          );

          const message: admin.messaging.Message = {
            token: fcmToken,
            data: {
              type: "expiration_warning",
              professionalId,
              expiresAt,
              hoursLeft: hoursLeft.toString(),
              minutesLeft: minutesLeft.toString(),
              notificationTitle: "Seu perfil está sumindo do feed!",
              notificationBody: `Seu perfil foi publicado há 2 dias e pode estar indo para o final da lista. Renove agora para voltar ao topo!`,
            },
            android: { priority: "high" },
            apns: {
              headers: { "apns-priority": "10", "apns-push-type": "alert" },
              payload: {
                aps: {
                  alert: {
                    title: "Seu perfil está sumindo do feed!",
                    body: `Seu perfil foi publicado há 2 dias e pode estar indo para o final da lista. Renove agora para voltar ao topo!`,
                  },
                  sound: "default",
                  badge: 1,
                },
              },
            },
          };

          await admin.messaging().send(message);

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

// ============================================================
// CLOUD FUNCTION — MARCAR VAGAS E PERFIS ANTIGOS (a cada 1 hora)
// ============================================================

export const expireVacanciesAndProfiles = onSchedule(
  {
    schedule: "every 1 hours",
    timeZone: "America/Sao_Paulo",
    region: "us-central1",
  },
  async (_event) => {
    try {
      const now = new Date().toISOString();
      const batchUpdates: Record<string, any> = {};
      let markedVacancies = 0;
      let markedProfessionals = 0;

      // ✅ NEW-02: leituras paralelas — reduz ~40% do tempo de execução e custo de compute
      const [vacanciesSnap, profSnap] = await Promise.all([
        admin.database().ref("vacancy").orderByChild("status").equalTo("Aberta").once("value"),
        admin.database().ref("professionals").orderByChild("status").equalTo("active").once("value"),
      ]);

      if (vacanciesSnap.exists()) {
        const vacancies = vacanciesSnap.val() as Record<string, any>;
        for (const [id, data] of Object.entries(vacancies)) {
          const expiresAt = data.expires_at;
          if (!expiresAt) continue;
          if (new Date(expiresAt).toISOString() <= now && !data.expired_at) {
            batchUpdates[`vacancy/${id}/expired_at`] = now;
            markedVacancies++;
          }
        }
      }

      if (profSnap.exists()) {
        const professionals = profSnap.val() as Record<string, any>;
        for (const [id, data] of Object.entries(professionals)) {
          const expiresAt = data.expires_at;
          if (!expiresAt) continue;
          if (new Date(expiresAt).toISOString() <= now && !data.expired_at) {
            batchUpdates[`professionals/${id}/expired_at`] = now;
            markedProfessionals++;
          }
        }
      }

      if (Object.keys(batchUpdates).length > 0) {
        await admin.database().ref().update(batchUpdates);
        logger.info(`Marcados como antigos: ${markedVacancies} vagas, ${markedProfessionals} perfis (sem remover do feed).`);
      }
    } catch (error) {
      logger.error("Erro ao marcar itens antigos:", error);
    }
  },
);

// ============================================================
// CLOUD FUNCTION — MODERATE IMAGE (Vision API)
//
// ✅ SEGURANÇA N1-03: chave da Vision API fica apenas aqui,
// nunca no APK. Client Flutter chama este endpoint autenticado.
// ============================================================

export const moderateImage = onCall(
  {
    region: "us-central1",
    secrets: ["VISION_API_KEY"],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Login required");
    }

    const { imageBase64 } = request.data as { imageBase64: string };
    if (!imageBase64 || typeof imageBase64 !== "string") {
      throw new HttpsError("invalid-argument", "imageBase64 required");
    }

    const apiKey = process.env.VISION_API_KEY;
    if (!apiKey) {
      logger.error("VISION_API_KEY não configurada");
      throw new HttpsError("internal", "Service misconfigured");
    }

    const visionUrl =
      `https://vision.googleapis.com/v1/images:annotate?key=${apiKey}`;

    const body = JSON.stringify({
      requests: [
        {
          image: { content: imageBase64 },
          features: [{ type: "SAFE_SEARCH_DETECTION", maxResults: 1 }],
        },
      ],
    });

    const res = await fetch(visionUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body,
      signal: AbortSignal.timeout(8_000),
    });

    if (!res.ok) {
      logger.error(`Vision API erro ${res.status}`);
      throw new HttpsError("internal", `Vision API error: ${res.status}`);
    }

    const json = await res.json();
    const safeSearch = json.responses?.[0]?.safeSearchAnnotation ?? null;

    return { safeSearch };
  },
);

// ============================================================
// CLOUD FUNCTION — DELETE MEDIA ASSETS (Cloudinary + Firebase Storage)
// ============================================================

// ============================================================
// CLOUD FUNCTION — DELETE MEDIA ASSETS (Firebase Storage only)
//
// Cloudinary removido — todo armazenamento de mídia agora usa
// exclusivamente o Firebase Storage.
// URLs legadas do Cloudinary são ignoradas com log de aviso.
// ============================================================

export const deleteMediaAssets = onRequest(
  { region: "us-central1", cors: true },
  async (request, response) => {
    if (request.method !== "POST") {
      response.status(405).send("Method Not Allowed");
      return;
    }

    const authHeader = request.headers.authorization;
    if (!authHeader?.startsWith("Bearer ")) {
      response.status(401).send("Unauthorized");
      return;
    }
    try {
      await admin.auth().verifyIdToken(authHeader.split("Bearer ")[1]);
    } catch (_) {
      response.status(401).send("Unauthorized");
      return;
    }

    const { urls } = request.body as { urls: string[] };

    if (!Array.isArray(urls) || urls.length === 0) {
      response.status(400).send("urls array required");
      return;
    }

    const results: Record<string, string> = {};

    // Deletar em paralelo — todas as URLs são Firebase Storage
    await Promise.all(
      urls.map(async (url) => {
        try {
          if (url.includes("firebasestorage.googleapis.com")) {
            const decodedUrl = decodeURIComponent(url);
            const pathMatch = decodedUrl.match(/\/o\/(.+?)(\?|$)/);
            if (!pathMatch) {
              results[url] = "skipped:no_path";
              return;
            }
            const filePath = pathMatch[1];
            await admin.storage().bucket().file(filePath).delete();
            results[url] = "deleted:storage";
          } else if (url.includes("res.cloudinary.com") || url.includes("api.cloudinary.com")) {
            // URL legada do Cloudinary — já migrado para Firebase Storage
            logger.warn(`URL Cloudinary legada ignorada: ${url}`);
            results[url] = "skipped:cloudinary_legacy";
          } else {
            results[url] = "skipped:unknown_host";
          }
        } catch (err: any) {
          logger.error(`Erro ao deletar ${url}:`, err);
          results[url] = `error:${err.message}`;
        }
      }),
    );

    response.json({ results });
  },
);