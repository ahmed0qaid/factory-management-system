const sdk = require('node-appwrite');

async function migratePhase9() {
  const client = new sdk.Client();
  client
    .setEndpoint('https://fra.cloud.appwrite.io/v1')
    .setProject('6a6a49d1000884049205')
    .setKey('standard_8831478838d66625e099e541665906fd006bd08bf2a3c096a2f8f9309808423ce8f9d92445107edbb603f6db41f75886a3e090cb5b8c1e38a8958ddf55527c53742cdb09a5ece5f901fac546e1540f37eefbe1dcfc4eb8e3b629bd485757dcd2c9eef58ca287bb38ee33c5538cac13c601c1a292125b91dd354467c72251ed93');

  const databases = new sdk.Databases(client);
  const dbId = 'hr';
  const tableId = 'overtime_records';

  // 1. Add fields to overtime_records
  const attrs = [
    { name: 'approval_note', type: 'string', size: 1000 },
    { name: 'rejection_reason', type: 'string', size: 1000 }
  ];
  
  for (const attr of attrs) {
    try {
      await databases.createStringAttribute(dbId, tableId, attr.name, attr.size, false);
      console.log(`Created attribute ${attr.name} on ${tableId}`);
    } catch(e) {
      console.log(`Attribute ${attr.name} error:`, e.message);
    }
  }

  console.log('Waiting for attributes to be ready before creating indexes...');
  await new Promise(r => setTimeout(r, 4000));

  // 2. Add indexes
  const indexes = [
    { table: 'overtime_records', name: 'ot_comp_appr_work_idx', type: 'key', attributes: ['company_id', 'approval_status', 'work_date'], orders: ['ASC', 'ASC', 'DESC'] },
    { table: 'overtime_records', name: 'ot_comp_emp_work_idx', type: 'key', attributes: ['company_id', 'employee_id', 'work_date'], orders: ['ASC', 'ASC', 'DESC'] },
    { table: 'overtime_records', name: 'ot_comp_pay_idx', type: 'key', attributes: ['company_id', 'payment_status'], orders: ['ASC', 'ASC'] },
    { table: 'overtime_records', name: 'ot_att_id_unique', type: 'unique', attributes: ['attendance_record_id'], orders: ['ASC'] }
  ];

  for (const idx of indexes) {
    try {
      await databases.createIndex(dbId, idx.table, idx.name, idx.type, idx.attributes, idx.orders);
      console.log(`Created index ${idx.name} on ${idx.table}`);
    } catch(e) {
      console.log(`Index ${idx.name} error:`, e.message);
    }
  }

  // 3. Print counts
  let stats = { total: 0, pending: 0, approved: 0, rejected: 0, paid: 0, unpaid: 0 };
  try {
    let offset = 0;
    let limit = 50;
    let hasMore = true;
    while (hasMore) {
      let docs = await databases.listDocuments(dbId, tableId, [sdk.Query.limit(limit), sdk.Query.offset(offset)]);
      for (const doc of docs.documents) {
        stats.total++;
        if (doc.approval_status === 'pending') stats.pending++;
        if (doc.approval_status === 'approved') stats.approved++;
        if (doc.approval_status === 'rejected') stats.rejected++;
        if (doc.payment_status === 'paid') stats.paid++;
        if (doc.payment_status === 'unpaid') stats.unpaid++;
      }
      offset += limit;
      if (docs.documents.length < limit) hasMore = false;
    }
    console.log('Overtime stats:', stats);
  } catch (e) {
    console.log('Stats error:', e.message);
  }

  console.log('Migration Phase 9 completed.');
}

migratePhase9();
