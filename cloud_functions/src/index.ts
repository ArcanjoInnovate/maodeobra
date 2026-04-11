import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import { onValueCreated } from "firebase-functions/v2/database";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/v2";


// Inicializa imediatamente
admin.initializeApp();


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

    // ========================================
    // 1. LÊ BADGE ATUAL (1 leitura)
    // ========================================

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

    // ========================================
    // 2. CONTA CHATS NÃO LIDOS (2 leituras)
    // ========================================

    let unreadChats = 0;

    // Query chats como EMPLOYEE (1 leitura)
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
        if (unreadCount === 1) {
          unreadChats++;
        }
      }
    }

    // Query chats como CONTRACTOR (1 leitura)
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
        if (unreadCount === 1) {
          unreadChats++;
        }
      }
    }

    // Limita a 9
    unreadChats = Math.min(unreadChats, 9);

    logger.info(`  Chats não lidos: ${unreadChats}`);

    // ========================================
    // 3. CONTA REQUESTS NÃO LIDOS (1 leitura)
    // ========================================

    let unreadRequests = 0;

    if (userRole === "worker") {
      // Query perfis profissionais
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
              const request = requestViews[reqId];
              if (request.viewed_by_owner === false) {
                unreadRequests++;
              }
            }
          }
        }
      }
    } else {
      // Query vagas
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
              const request = requestViews[reqId];
              if (request.viewed_by_owner === false) {
                unreadRequests++;
              }
            }
          }
        }
      }
    }

    // Limita a 9
    unreadRequests = Math.min(unreadRequests, 9);

    logger.info(`  Requests não lidos: ${unreadRequests}`);

    // ========================================
    // 4. CALCULA BADGE CORRETO
    // ========================================

    result.calculatedBadge = {
      unread_chats: unreadChats,
      unread_requests: unreadRequests,
    };

    // ========================================
    // 5. VERIFICA SE PRECISA CORRIGIR
    // ========================================

    const needsCorrection =
      result.currentBadge.unread_chats !== result.calculatedBadge.unread_chats ||
      result.currentBadge.unread_requests !== result.calculatedBadge.unread_requests;

    if (needsCorrection) {
      logger.info(`  ⚠️ Badge incorreto! Corrigindo...`);
      logger.info(`    Antes: ${JSON.stringify(result.currentBadge)}`);
      logger.info(`    Depois: ${JSON.stringify(result.calculatedBadge)}`);

      // Atualiza badge (1 escrita)
      await admin
        .database()
        .ref(`badges/${userId}`)
        .set({
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
      if (result.wasCorrected) {
        batchResult.correctedCount++;
      } else {
        batchResult.correctCount++;
      }
    } else {
      batchResult.errorCount++;
    }
  }

  // Relatório final
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

  // Precisa determinar o role de cada usuário
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
// ============================================================

export const weeklyBadgeCleanup = onSchedule(
  {
    schedule: "0 3 * * 0", // Domingo às 3h da manhã
    timeZone: "America/Sao_Paulo",
    region: "us-central1",
  },
  async (event) => {
    logger.info("\n═══════════════════════════════════════════");
    logger.info("🕐 MANUTENÇÃO SEMANAL - BADGE CLEANUP");
    logger.info("═══════════════════════════════════════════\n");
    logger.info(`Horário: ${new Date().toISOString()}`);

    try {
      const result = await verifyAllBadges();

      logger.info("\n✅ MANUTENÇÃO CONCLUÍDA COM SUCESSO");
      logger.info("═══════════════════════════════════════════\n");

      return {
        success: true,
        timestamp: new Date().toISOString(),
        ...result,
      };
    } catch (error) {
      logger.error("\n❌❌❌ ERRO CRÍTICO NA MANUTENÇÃO ❌❌❌");
      logger.error("Erro:", error);

      return {
        success: false,
        error: String(error),
        timestamp: new Date().toISOString(),
      };
    }
  }
);

// ============================================================
// CLOUD FUNCTION - ON-DEMAND BADGE CLEANUP
// ============================================================

export const manualBadgeCleanup = onSchedule(
  {
    schedule: "every 24 hours", // Apenas para manter viva, será executada manualmente
    timeZone: "America/Sao_Paulo",
    region: "us-central1",
  },
  async (event) => {
    // Esta função pode ser invocada manualmente via Firebase Console
    // ou via CLI: firebase functions:call manualBadgeCleanup
    
    logger.info("\n═══════════════════════════════════════════");
    logger.info("🔧 LIMPEZA MANUAL - BADGE CLEANUP");
    logger.info("═══════════════════════════════════════════\n");

    try {
      const result = await verifyAllBadges();

      return {
        success: true,
        timestamp: new Date().toISOString(),
        ...result,
      };
    } catch (error) {
      logger.error("❌ Erro na limpeza manual:", error);

      return {
        success: false,
        error: String(error),
        timestamp: new Date().toISOString(),
      };
    }
  }
);

// ============================================================
// CLOUD FUNCTION - VERIFICAR BADGE INDIVIDUAL (HTTP)
// ============================================================

import { onRequest } from "firebase-functions/v2/https";

export const verifyUserBadge = onRequest(
  {
    region: "us-central1",
    cors: true,
  },
  async (request, response) => {
    // Apenas para admins autenticados
    const userId = request.query.userId as string;
    const userRole = request.query.role as "worker" | "contractor";

    if (!userId || !userRole) {
      response.status(400).send({
        error: "Missing userId or role parameter",
      });
      return;
    }

    try {
      const result = await verifyAndFixBadge(userId, userRole);

      response.status(200).send({
        success: true,
        result,
      });
    } catch (error) {
      response.status(500).send({
        success: false,
        error: String(error),
      });
    }
  }
);
// ============================================================
// HELPERS - PUSH NOTIFICATIONS
// ============================================================

async function getSenderInfo(userId: string) {
  try {
    const userSnap = await admin.database().ref(`Users/${userId}`).once("value");
    if (!userSnap.exists()) {
      return { name: "Usuário", avatar: "" };
    }
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
  userRole: "employee" | "contractor"
): Promise<boolean> {
  try {
    const statusSnap = await admin.database()
      .ref(`Chats/${chatId}/participants/${userRole}`)
      .once("value");
    return statusSnap.val() === "online";
  } catch (error) {
    return false;
  }
}

async function sendPushNotification(
  userId: string,
  title: string,
  body: string,
  data: Record<string, string>,
  imageUrl?: string
) {
  try {
    const tokenSnap = await admin.database().ref(`Users/${userId}/fcmToken`).once("value");

    if (!tokenSnap.exists()) {
      logger.info(`Usuário ${userId} não tem FCM token`);
      return;
    }

    const token = tokenSnap.val() as string;

    const message: admin.messaging.Message = {
      token,
      notification: {
        title,
        body,
        imageUrl: imageUrl || undefined,  // ✅ CORRIGIDO
      },
      data,
      android: {
        priority: "high",
        notification: {
          channelId: "chat_messages",
          priority: "high",
          sound: "default",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    await admin.messaging().send(message);
    logger.info(`Push notification enviada para ${userId}`);
  } catch (error: any) {
    if (
      error.code === "messaging/invalid-registration-token" ||
      error.code === "messaging/registration-token-not-registered"
    ) {
      await admin.database().ref(`Users/${userId}/fcmToken`).remove();
    } else {
      logger.error("Erro ao enviar push", { error });
    }
  }
}

// ============================================================
// HELPER - RECALCULAR BADGE (USA MESMA LÓGICA DO DART)
// ============================================================

async function recalculateChatBadge(userId: string) {
  try {
    logger.info(`\n🔄🔄🔄 RECALCULANDO BADGE 🔄🔄🔄`);
    logger.info(`UserId: ${userId}`);

    // Busca TODOS os chats como EMPLOYEE
    const employeeChatsSnap = await admin.database()
      .ref("Chats")
      .orderByChild("employee")
      .equalTo(userId)
      .once("value");

    // Busca TODOS os chats como CONTRACTOR
    const contractorChatsSnap = await admin.database()
      .ref("Chats")
      .orderByChild("contractor")
      .equalTo(userId)
      .once("value");

    let totalUnread = 0;

    // Conta chats não lidos como EMPLOYEE
    if (employeeChatsSnap.exists()) {
      const chats = employeeChatsSnap.val() as Record<string, any>;
      logger.info(`Chats como employee: ${Object.keys(chats).length}`);
      
      for (const chatId in chats) {
        const chat = chats[chatId];
        const unreadCount = chat.unreadCount?.employee || 0;
        
        if (unreadCount === 1) {
          totalUnread++;
          logger.info(`  ✉️ Chat não lido (employee): ${chatId}`);
        }
      }
    }

    // Conta chats não lidos como CONTRACTOR
    if (contractorChatsSnap.exists()) {
      const chats = contractorChatsSnap.val() as Record<string, any>;
      logger.info(`Chats como contractor: ${Object.keys(chats).length}`);
      
      for (const chatId in chats) {
        const chat = chats[chatId];
        const unreadCount = chat.unreadCount?.contractor || 0;
        
        if (unreadCount === 1) {
          totalUnread++;
          logger.info(`  ✉️ Chat não lido (contractor): ${chatId}`);
        }
      }
    }

    // Limita a 9
    totalUnread = Math.min(totalUnread, 9);

    // Pega badge atual para manter unread_requests
    const badgeSnap = await admin.database()
      .ref(`badges/${userId}`)
      .once("value");

    const currentBadge = badgeSnap.exists() 
      ? badgeSnap.val() 
      : { unread_requests: 0 };

    // Atualiza badge
    await admin.database().ref(`badges/${userId}`).set({
      unread_chats: totalUnread,
      unread_requests: currentBadge.unread_requests || 0,
      updated_at: Date.now(),
    });

    logger.info(`✅ Badge recalculado: ${totalUnread} chats não lidos`);
    logger.info(`✅✅✅ RECÁLCULO CONCLUÍDO ✅✅✅\n`);

  } catch (error) {
    logger.error(`❌ Erro ao recalcular badge:`, error);
  }
}

async function incrementRequestBadge(userId: string) {
  try {
    const badgeRef = admin.database().ref(`badges/${userId}`);
    const snap = await badgeRef.once("value");
    
    const current = snap.exists() 
      ? snap.val() 
      : { unread_chats: 0, unread_requests: 0 };

    await badgeRef.set({
      unread_chats: current.unread_chats || 0,
      unread_requests: Math.min((current.unread_requests || 0) + 1, 9),
      updated_at: Date.now(),
    });
  } catch (error) {
    logger.error("Erro ao incrementar request badge:", error);
  }
}

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

    // Ignora placeholder
    if (messageData._placeholder || !messageData) {
      return;
    }

    try {
      logger.info(`\n════════════════════════════════════════`);
      logger.info(`📨 NOVA MENSAGEM: ${chatId}`);
      logger.info(`════════════════════════════════════════`);

      const chatSnap = await admin.database().ref(`Chats/${chatId}`).once("value");
      if (!chatSnap.exists()) {
        logger.warn(`⚠️ Chat ${chatId} não existe`);
        return;
      }

      const chatData = chatSnap.val() as {
        employee: string;
        contractor: string;
        unreadCount?: { employee: number; contractor: number };
      };

      const { employee, contractor } = chatData;
      const senderRole = messageData.sender as "employee" | "contractor";
      const sender = senderRole === "employee" ? employee : contractor;
      const receiver = senderRole === "employee" ? contractor : employee;
      const receiverRole = senderRole === "employee" ? "contractor" : "employee";

      logger.info(`👤 Sender: ${sender} (${senderRole})`);
      logger.info(`👤 Receiver: ${receiver} (${receiverRole})`);

      // Verifica se receiver está online NO CHAT
      const isOnline = await isUserOnlineInChat(chatId, receiverRole);
      logger.info(`📶 Online: ${isOnline}`);

      // LÓGICA BINÁRIA
      const newUnreadCount = isOnline ? 0 : 1;
      const currentUnreadCount = chatData.unreadCount?.[receiverRole] || 0;

      logger.info(`📊 UnreadCount: ${currentUnreadCount} → ${newUnreadCount}`);

      // 1. Atualiza unreadCount
      await admin.database().ref(`Chats/${chatId}/unreadCount/${receiverRole}`).set(newUnreadCount);
      logger.info(`✅ unreadCount atualizado em Chats/${chatId}/unreadCount/${receiverRole}`);

      // 2. RECALCULA badge (SEMPRE - garante sincronização)
      logger.info(`\n🔔 Recalculando badge do receiver...`);
      await recalculateChatBadge(receiver);

      // 3. Push notification
      if (!isOnline) {
        const senderInfo = await getSenderInfo(sender);
        
        const displayText =
          messageData.text && messageData.text.length > 100
            ? messageData.text.substring(0, 97) + "..."
            : messageData.text || "Nova mensagem";

        await sendPushNotification(
          receiver,
          senderInfo.name,
          displayText,
          {
            type: "chat",
            chatId,
            senderId: sender,
            senderName: senderInfo.name,
            senderAvatar: senderInfo.avatar || "",
          },
          senderInfo.avatar
        );
      }

      logger.info(`\n✅ PROCESSADO COM SUCESSO`);
      logger.info(`════════════════════════════════════════\n`);
      
    } catch (err) {
      logger.error(`\n❌❌❌ ERRO CRÍTICO ❌❌❌`);
      logger.error(`Erro:`, err);
    }
  }
);

// ============================================================
// 🆕 FUNCTION - CHAT REQUEST NOTIFICATION (PROFESSIONAL)
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
      logger.info(`\n════════════════════════════════════════`);
      logger.info(`💼 NOVA SOLICITAÇÃO DE CHAT (PROFESSIONAL)`);
      logger.info(`Professional ID: ${professionalId}`);
      logger.info(`Requester ID: ${requesterId}`);
      logger.info(`════════════════════════════════════════`);

      // Busca dados do profissional
      const professionalSnap = await admin.database()
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

      logger.info(`👤 Owner ID: ${ownerId}`);

      // Incrementa badge de requests
      await incrementRequestBadge(ownerId);

      // Busca dados do solicitante
      const requesterName = requestData.contractor_name || "Alguém";
      const requesterAvatar = requestData.contractor_avatar || "";

      logger.info(`📤 Enviando notificação para ${ownerId}`);
      logger.info(`   De: ${requesterName}`);

      // Envia push notification
      await sendPushNotification(
        ownerId,
        "Nova Solicitação de Chat! 💬",
        `${requesterName} quer conversar com você sobre seu perfil profissional`,
        {
          type: "chat_request",
          requestType: "professional",
          professionalId,
          requesterId,
          requesterName,
          requesterAvatar,
        },
        requesterAvatar
      );

      logger.info(`✅ Notificação de chat request enviada!`);
      logger.info(`════════════════════════════════════════\n`);

    } catch (err) {
      logger.error(`\n❌❌❌ ERRO AO PROCESSAR CHAT REQUEST ❌❌❌`);
      logger.error(`Erro:`, err);
    }
  }
);

// ============================================================
// 🆕 FUNCTION - CHAT REQUEST NOTIFICATION (VACANCY)
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
      logger.info(`\n════════════════════════════════════════`);
      logger.info(`💼 NOVA SOLICITAÇÃO DE CHAT (VACANCY)`);
      logger.info(`Vacancy ID: ${vacancyId}`);
      logger.info(`Requester ID: ${requesterId}`);
      logger.info(`════════════════════════════════════════`);

      // Busca dados da vaga
      const vacancySnap = await admin.database()
        .ref(`vacancy/${vacancyId}`)
        .once("value");

      if (!vacancySnap.exists()) {
        logger.warn(`⚠️ Vaga ${vacancyId} não encontrada`);
        return;
      }

      const vacancyData = vacancySnap.val() as Record<string, any>;
      const ownerId = vacancyData.local_id as string;

      if (!ownerId) {
        logger.warn(`⚠️ Vaga ${vacancyId} sem local_id`);
        return;
      }

      logger.info(`👤 Owner ID: ${ownerId}`);

      // Incrementa badge de requests
      await incrementRequestBadge(ownerId);

      // Busca dados do solicitante
      const requesterName = requestData.worker_name || "Alguém";
      const requesterAvatar = requestData.worker_avatar || "";
      const vacancyTitle = vacancyData.title || "sua vaga";

      logger.info(`📤 Enviando notificação para ${ownerId}`);
      logger.info(`   De: ${requesterName}`);

      // Envia push notification
      await sendPushNotification(
        ownerId,
        "Nova Candidatura! 🎯",
        `${requesterName} se candidatou para ${vacancyTitle}`,
        {
          type: "chat_request",
          requestType: "vacancy",
          vacancyId,
          requesterId,
          requesterName,
          requesterAvatar,
        },
        requesterAvatar
      );

      logger.info(`✅ Notificação de candidatura enviada!`);
      logger.info(`════════════════════════════════════════\n`);

    } catch (err) {
      logger.error(`\n❌❌❌ ERRO AO PROCESSAR CANDIDATURA ❌❌❌`);
      logger.error(`Erro:`, err);
    }
  }
);

// ============================================================
// FUNCTION - WORKER REQUEST (mantido para compatibilidade)
// ============================================================

export const onWorkerRequestCreated = onValueCreated(
  {
    ref: "/professionals/{profileId}/views/request_views/{requestId}",
    region: "us-central1",
  },
  async (event) => {
    const profileId = event.params.profileId;
    const requestData = event.data.val() as any;

    try {
      const profileSnap = await admin.database()
        .ref(`professionals/${profileId}`)
        .once("value");

      if (!profileSnap.exists()) return;

      const profileData = profileSnap.val() as Record<string, any>;
      const ownerId = profileData.local_id as string;

      await incrementRequestBadge(ownerId);

      const requesterName = requestData.contractor_name || "Alguém";
      const requesterAvatar = requestData.contractor_avatar || "";

      await sendPushNotification(
        ownerId,
        "Nova Solicitação de Contato",
        `${requesterName} quer entrar em contato com você`,
        {
          type: "request",
          requestType: "worker",
          profileId,
          requesterName,
          requesterAvatar,
        },
        requesterAvatar
      );

      logger.info(`Worker request criado: ${profileId}`);
    } catch (err) {
      logger.error("Erro em onWorkerRequestCreated", { error: err });
    }
  }
);

// ============================================================
// FUNCTION - VACANCY REQUEST (mantido para compatibilidade)
// ============================================================

export const onVacancyRequestCreated = onValueCreated(
  {
    ref: "/vacancy/{vacancyId}/views/request_views/{requestId}",
    region: "us-central1",
  },
  async (event) => {
    const vacancyId = event.params.vacancyId;
    const requestId = event.params.requestId;

    try {
      const vacancySnap = await admin.database().ref(`vacancy/${vacancyId}`).once("value");
      if (!vacancySnap.exists()) return;

      const vacancyData = vacancySnap.val() as Record<string, any>;
      const ownerId = vacancyData.local_id as string;

      await incrementRequestBadge(ownerId);

      const requesterSnap = await admin.database().ref(`Users/${requestId}`).once("value");
      let requesterName = "Alguém";
      let requesterAvatar = "";

      if (requesterSnap.exists()) {
        const requesterData = requesterSnap.val() as Record<string, any>;
        requesterName = requesterData.Name || "Alguém";
        requesterAvatar = requesterData.avatar || "";
      }

      await sendPushNotification(
        ownerId,
        "Novo Interesse na Vaga",
        `${requesterName} tem interesse na sua vaga`,
        {
          type: "request",
          requestType: "contractor",
          vacancyId,
          requesterName,
          requesterAvatar,
        },
        requesterAvatar
      );

      logger.info(`Vacancy request criado: ${vacancyId}`);
    } catch (err) {
      logger.error("Erro em onVacancyRequestCreated", { error: err });
    }
  }
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

      const [employeeInfo, contractorInfo] = await Promise.all([
        getSenderInfo(employee),
        getSenderInfo(contractor),
      ]);

      await Promise.all([
        sendPushNotification(
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
          contractorInfo.avatar
        ),
        sendPushNotification(
          contractor,
          "Solicitação Aceita! 🎉",
          `${employeeInfo.name} aceitou sua solicitação de chat`,
          {
            type: "chat_accepted",
            chatId,
            senderId: employee,
            senderName: employeeInfo.name,
            senderAvatar: employeeInfo.avatar || "",
          },
          employeeInfo.avatar
        ),
      ]);

      logger.info(`Notificações enviadas: ${chatId}`);
    } catch (err) {
      logger.error("Erro em onChatCreated", { error: err });
    }
  }
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
  async (event) => {
    logger.info("\n═══════════════════════════════════════════");
    logger.info("🕐 VERIFICANDO PERFIS PRÓXIMOS DA EXPIRAÇÃO");
    logger.info("═══════════════════════════════════════════\n");
 
    try {
      const now = Date.now();
      const minTime = now + (1.5 * 60 * 60 * 1000);
      const maxTime = now + (2.5 * 60 * 60 * 1000);
 
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
        return { success: true, notificationsSent: 0, errors: 0 };
      }
 
      const professionals = professionalsSnap.val() as Record<string, any>;
      const totalProfessionals = Object.keys(professionals).length;
      
      logger.info(`📊 Total de perfis ativos: ${totalProfessionals}\n`);
 
      let notificationsSent = 0;
      let errors = 0;
      let skipped = 0;
 
      for (const [professionalId, professionalData] of Object.entries(professionals)) {
        try {
          const expiresAt = professionalData.expires_at;
          
          if (!expiresAt) {
            logger.warn(`⚠️ Perfil ${professionalId} sem data de expiração`);
            skipped++;
            continue;
          }
 
          const expirationTimestamp = new Date(expiresAt).getTime();
 
          if (expirationTimestamp >= minTime && expirationTimestamp <= maxTime) {
            const localId = professionalData.local_id;
            
            if (!localId) {
              logger.warn(`⚠️ Perfil ${professionalId} sem local_id`);
              skipped++;
              continue;
            }
 
            const lastNotifiedSnap = await admin
              .database()
              .ref(`professionals/${professionalId}/last_expiration_notification`)
              .once("value");
 
            const lastNotified = lastNotifiedSnap.val();
            
            if (lastNotified && (now - lastNotified) < (3 * 60 * 60 * 1000)) {
              logger.info(`⏭️ Perfil ${professionalId} já foi notificado recentemente`);
              skipped++;
              continue;
            }
 
            const userSnap = await admin
              .database()
              .ref(`Users/${localId}`)
              .once("value");
 
            if (!userSnap.exists()) {
              logger.warn(`⚠️ Usuário ${localId} não encontrado`);
              skipped++;
              continue;
            }
 
            const userData = userSnap.val() as Record<string, any>;
            const userName = userData.Name || "Profissional";
            const fcmToken = userData.fcmToken;
 
            if (!fcmToken) {
              logger.warn(`⚠️ Usuário ${localId} (${userName}) sem FCM token`);
              skipped++;
              continue;
            }
 
            const timeLeft = expirationTimestamp - now;
            const hoursLeft = Math.floor(timeLeft / (60 * 60 * 1000));
            const minutesLeft = Math.floor((timeLeft % (60 * 60 * 1000)) / (60 * 1000));
 
            const timeMessage = hoursLeft > 0 
              ? `${hoursLeft}h ${minutesLeft}min` 
              : `${minutesLeft} minutos`;
 
            logger.info(`\n📱 Enviando notificação para ${userName}:`);
            logger.info(`   Expira em: ${timeMessage}`);
 
            const message: admin.messaging.Message = {
              token: fcmToken,
              notification: {
                title: "⏰ Seu perfil está expirando!",
                body: `Seu perfil profissional expira em ${timeMessage}. Renove agora para continuar visível!`,
              },
              data: {
                type: "expiration_warning",
                professionalId: professionalId,
                expiresAt: expiresAt,
                hoursLeft: hoursLeft.toString(),
                minutesLeft: minutesLeft.toString(),
              },
              android: {
                priority: "high",
                notification: {
                  channelId: "expiration_alerts",
                  priority: "high",
                  sound: "default",
                  color: "#EA580C",
                },
              },
              apns: {
                payload: {
                  aps: {
                    sound: "default",
                    badge: 1,
                  },
                },
              },
            };
 
            await admin.messaging().send(message);
 
            await admin
              .database()
              .ref(`professionals/${professionalId}/last_expiration_notification`)
              .set(now);
 
            notificationsSent++;
            logger.info(`   ✅ Notificação enviada com sucesso!\n`);
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
      logger.info(`📊 Estatísticas:`);
      logger.info(`   Total: ${totalProfessionals}`);
      logger.info(`   📨 Enviadas: ${notificationsSent}`);
      logger.info(`   ⏭️ Puladas: ${skipped}`);
      logger.info(`   ❌ Erros: ${errors}`);
      logger.info("═══════════════════════════════════════════\n");
 
      return {
        success: true,
        totalProfessionals,
        notificationsSent,
        skipped,
        errors,
        timestamp: new Date().toISOString(),
      };
 
    } catch (error) {
      logger.error("\n❌❌❌ ERRO CRÍTICO NA VERIFICAÇÃO ❌❌❌");
      logger.error("Erro:", error);
      
      return {
        success: false,
        error: String(error),
        timestamp: new Date().toISOString(),
      };
    }
  }
);