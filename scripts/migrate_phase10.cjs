require('dotenv').config();
const { Client, Databases, IndexType } = require('node-appwrite');

const client = new Client()
  .setEndpoint(process.env.APPWRITE_ENDPOINT || process.env.APPWRITE_ENDPOINT)
  .setProject(process.env.APPWRITE_PROJECT_ID)
  .setKey(process.env.APPWRITE_API_KEY);

const databases = new Databases(client);
const dbId = process.env.APPWRITE_DATABASE_ID;
const advancesTable = 'advances';
const installmentsTable = 'advance_installments';

async function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function runMigration() {
  console.log('Starting Phase 10 Migration...');

  // 1. Create advance_installments table
  console.log(`Creating table: ${installmentsTable}...`);
  try {
    await databases.createCollection(
      dbId,
      installmentsTable,
      'Advance Installments',
      [],
      false
    );
    console.log('Created advance_installments table.');
  } catch (e) {
    if (e.code === 409) {
      console.log('advance_installments table already exists.');
    } else {
      throw e;
    }
  }

  // 2. Add attributes to advance_installments
  const installmentAttrs = [
    { key: 'company_id', type: 'string', size: 255, required: true },
    { key: 'advance_id', type: 'string', size: 255, required: true },
    { key: 'employee_id', type: 'string', size: 255, required: true },
    { key: 'installment_number', type: 'integer', required: true },
    { key: 'due_month', type: 'string', size: 7, required: true }, // YYYY-MM
    { key: 'amount', type: 'double', required: true },
    { key: 'status', type: 'string', size: 50, required: true }, // pending, deducted, skipped, cancelled
    { key: 'payroll_record_id', type: 'string', size: 255, required: false },
    { key: 'deducted_at', type: 'datetime', required: false },
    { key: 'created_at', type: 'datetime', required: true },
  ];

  for (const attr of installmentAttrs) {
    try {
      if (attr.type === 'string') {
        await databases.createStringAttribute(dbId, installmentsTable, attr.key, attr.size, attr.required);
      } else if (attr.type === 'integer') {
        await databases.createIntegerAttribute(dbId, installmentsTable, attr.key, attr.required);
      } else if (attr.type === 'double') {
        await databases.createFloatAttribute(dbId, installmentsTable, attr.key, attr.required);
      } else if (attr.type === 'datetime') {
        await databases.createDatetimeAttribute(dbId, installmentsTable, attr.key, attr.required);
      }
      console.log(`Created attribute ${attr.key} on ${installmentsTable}`);
      await sleep(1000);
    } catch (e) {
      if (e.code === 409) {
        console.log(`Attribute ${attr.key} already exists on ${installmentsTable}`);
      } else {
        console.error(`Error creating attribute ${attr.key}:`, e.message);
      }
    }
  }

  // 3. Add Indexes to advance_installments
  const instIndexes = [
    { key: 'idx_company_emp_month', type: 'key', attrs: ['company_id', 'employee_id', 'due_month'] },
    { key: 'idx_adv_installment_num', type: 'unique', attrs: ['advance_id', 'installment_number'] },
    { key: 'idx_payroll_record', type: 'key', attrs: ['payroll_record_id'] },
  ];
  for (const idx of instIndexes) {
    try {
      await databases.createIndex(dbId, installmentsTable, idx.key, idx.type, idx.attrs);
      console.log(`Created index ${idx.key} on ${installmentsTable}`);
      await sleep(1000);
    } catch (e) {
      if (e.code === 409) {
        console.log(`Index ${idx.key} already exists on ${installmentsTable}`);
      } else {
        console.error(`Error creating index ${idx.key}:`, e.message);
      }
    }
  }

  // 4. Update existing advances table schema
  console.log(`Updating ${advancesTable} table schema...`);
  const advanceAttrs = [
    // company_id, employee_id, request_date, reason, status are likely already there.
    { key: 'approved_amount', type: 'double', required: false },
    { key: 'approved_by', type: 'string', size: 255, required: false },
    { key: 'approved_at', type: 'datetime', required: false },
    { key: 'approval_note', type: 'string', size: 1000, required: false },
    { key: 'rejection_reason', type: 'string', size: 1000, required: false },
    { key: 'installment_count', type: 'integer', required: false },
    { key: 'first_installment_month', type: 'string', size: 7, required: false },
    { key: 'repayment_status', type: 'string', size: 50, required: false }, // active, fully_paid
  ];

  for (const attr of advanceAttrs) {
    try {
      if (attr.type === 'string') {
        await databases.createStringAttribute(dbId, advancesTable, attr.key, attr.size, attr.required);
      } else if (attr.type === 'integer') {
        await databases.createIntegerAttribute(dbId, advancesTable, attr.key, attr.required);
      } else if (attr.type === 'double') {
        await databases.createFloatAttribute(dbId, advancesTable, attr.key, attr.required);
      } else if (attr.type === 'datetime') {
        await databases.createDatetimeAttribute(dbId, advancesTable, attr.key, attr.required);
      }
      console.log(`Created attribute ${attr.key} on ${advancesTable}`);
      await sleep(1000);
    } catch (e) {
      if (e.code === 409) {
        console.log(`Attribute ${attr.key} already exists on ${advancesTable}`);
      } else {
        console.error(`Error creating attribute ${attr.key}:`, e.message);
      }
    }
  }

  // 5. Add Indexes to advances
  const advIndexes = [
    { key: 'idx_company_emp_status', type: 'key', attrs: ['company_id', 'employee_id', 'status'] },
  ];
  for (const idx of advIndexes) {
    try {
      await databases.createIndex(dbId, advancesTable, idx.key, idx.type, idx.attrs);
      console.log(`Created index ${idx.key} on ${advancesTable}`);
      await sleep(1000);
    } catch (e) {
      if (e.code === 409) {
        console.log(`Index ${idx.key} already exists on ${advancesTable}`);
      } else {
        console.error(`Error creating index ${idx.key}:`, e.message);
      }
    }
  }

  // Backfill logic for old advances (if status = approved, but repayment_status is null)
  let cursor = null;
  let hasMore = true;
  let totalAdvances = 0;
  let backfilled = 0;

  console.log('Checking old advances for backfill...');
  while (hasMore) {
    const queries = [];
    if (cursor) queries.push(require('node-appwrite').Query.cursorAfter(cursor));
    
    const response = await databases.listDocuments(dbId, advancesTable, queries);
    for (const doc of response.documents) {
      totalAdvances++;
      // Basic backfill: If it's approved and repayment_status is missing
      if (doc.status === 'approved' && !doc.repayment_status) {
        // Assume fully paid if remaining_amount <= 0, else active
        const remaining = doc.remaining_amount ?? doc.principal_amount ?? 0;
        const repayment_status = remaining <= 0 ? 'fully_paid' : 'active';
        await databases.updateDocument(dbId, advancesTable, doc.$id, {
          repayment_status: repayment_status,
        });
        backfilled++;
      }
    }
    
    if (response.documents.length > 0) {
      cursor = response.documents[response.documents.length - 1].$id;
    } else {
      hasMore = false;
    }
  }
  
  console.log(`Migration completed. Total advances: ${totalAdvances}, Backfilled: ${backfilled}`);
}

runMigration().catch(console.error);
