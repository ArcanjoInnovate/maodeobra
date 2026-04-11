// recalculate-badges.js
// Execute: node recalculate-badges.js

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://obra-7ebd9-default-rtdb.firebaseio.com'
});

const db = admin.database();

async function recalculateAllBadges() {
  console.log('🔄 RECALCULANDO TODOS OS BADGES\n');

  try {
    // 1. Pega todos os chats
    const chatsSnap = await db.ref('Chats').once('value');
    
    if (!chatsSnap.exists()) {
      console.log('❌ Nenhum chat encontrado');
      return;
    }

    const chats = chatsSnap.val();
    const userUnreadCounts = {};

    console.log(`📊 Total de chats: ${Object.keys(chats).length}\n`);

    // 2. Conta quantos chats não lidos cada usuário tem
    for (const chatId in chats) {
      const chat = chats[chatId];
      
      const employeeId = chat.employee;
      const contractorId = chat.contractor;
      const unreadCount = chat.unreadCount || {};

      // Inicializa contadores se não existir
      if (!userUnreadCounts[employeeId]) {
        userUnreadCounts[employeeId] = { employee: 0, contractor: 0, total: 0 };
      }
      if (!userUnreadCounts[contractorId]) {
        userUnreadCounts[contractorId] = { employee: 0, contractor: 0, total: 0 };
      }

      // Conta chats não lidos para employee
      if (unreadCount.employee === 1) {
        userUnreadCounts[employeeId].employee++;
        userUnreadCounts[employeeId].total++;
        console.log(`✉️ ${employeeId} (employee) tem 1 não lido no chat ${chatId}`);
      }

      // Conta chats não lidos para contractor
      if (unreadCount.contractor === 1) {
        userUnreadCounts[contractorId].contractor++;
        userUnreadCounts[contractorId].total++;
        console.log(`✉️ ${contractorId} (contractor) tem 1 não lido no chat ${chatId}`);
      }
    }

    console.log('\n════════════════════════════════════════');
    console.log('📊 RESUMO POR USUÁRIO:');
    console.log('════════════════════════════════════════\n');

    const updates = {};

    // 3. Atualiza os badges
    for (const userId in userUnreadCounts) {
      const counts = userUnreadCounts[userId];
      const totalUnread = Math.min(counts.total, 9); // Limita a 9

      console.log(`👤 ${userId}:`);
      console.log(`   Como employee: ${counts.employee} não lidos`);
      console.log(`   Como contractor: ${counts.contractor} não lidos`);
      console.log(`   TOTAL: ${counts.total} → Badge: ${totalUnread}`);
      console.log('');

      // Atualiza badge
      updates[`badges/${userId}/unread_chats`] = totalUnread;
      updates[`badges/${userId}/updated_at`] = Date.now();
    }

    console.log('════════════════════════════════════════');
    console.log('💾 SALVANDO BADGES...');
    console.log('════════════════════════════════════════\n');

    // 4. Aplica todos os updates
    await db.ref().update(updates);

    console.log('✅✅✅ RECÁLCULO COMPLETO! ✅✅✅\n');
    console.log('📋 Resumo:');
    console.log(`   Usuários processados: ${Object.keys(userUnreadCounts).length}`);
    console.log(`   Badges atualizados: ${Object.keys(updates).length / 2}`);
    console.log('\n🎯 Verifique o banco de dados agora!');

  } catch (error) {
    console.error('❌ Erro:', error);
  }

  process.exit(0);
}

recalculateAllBadges();