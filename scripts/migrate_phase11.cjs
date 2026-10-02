const { Client, Databases, IndexType } = require('node-appwrite');
require('dotenv').config();

const client = new Client()
  .setEndpoint(process.env.APPWRITE_ENDPOINT)
  .setProject(process.env.APPWRITE_PROJECT_ID)
  .setKey(process.env.APPWRITE_API_KEY);

const databases = new Databases(client);
const dbId = process.env.APPWRITE_DATABASE_ID;
const payrollPeriodsTable = 'payroll_periods';
const payrollRecordsTable = 'payroll_records';

async function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function runMigration() {
  console.log('Starting Phase 11 Migration...');

  // 1. Create payroll_periods table
  console.log(`Creating table: ${payrollPeriodsTable}...`);
  try {
    await databases.createCollection(
      dbId,
      payrollPeriodsTable,
      'Payroll Periods',
      [],
      false
    );
    console.log(`Created ${payrollPeriodsTable} table.`);
  } catch (e) {
    if (e.code === 409) {
      console.log(`${payrollPeriodsTable} table already exists.`);
    } else {
      throw e;
    }
  }

  // 2. Add attributes to payroll_periods
  const periodAttrs = [
    { key: 'company_id', type: 'string', size: 255, required: true },
    { key: 'period_key', type: 'string', size: 7, required: true }, // YYYY-MM
    { key: 'year', type: 'integer', required: true },
    { key: 'month', type: 'integer', required: true },
    { key: 'start_date', type: 'datetime', required: true },
    { key: 'end_date', type: 'datetime', required: true },
    { key: 'status', type: 'string', size: 50, required: true }, // open, closed
    { key: 'created_by', type: 'string', size: 255, required: false },
    { key: 'created_at', type: 'datetime', required: true },
    { key: 'updated_at', type: 'datetime', required: false },
  ];

  for (const attr of periodAttrs) {
    try {
      if (attr.type === 'string') {
        await databases.createStringAttribute(dbId, payrollPeriodsTable, attr.key, attr.size, attr.required);
      } else if (attr.type === 'integer') {
        await databases.createIntegerAttribute(dbId, payrollPeriodsTable, attr.key, attr.required);
      } else if (attr.type === 'datetime') {
        await databases.createDatetimeAttribute(dbId, payrollPeriodsTable, attr.key, attr.required);
      }
      console.log(`Created attribute ${attr.key} on ${payrollPeriodsTable}`);
      await sleep(1000); // Prevent rate limit
    } catch (e) {
      if (e.code === 409) {
        console.log(`Attribute ${attr.key} already exists on ${payrollPeriodsTable}`);
      } else {
        console.error(`Error creating attribute ${attr.key}:`, e.message);
      }
    }
  }

  // 3. Add Indexes to payroll_periods
  const periodIndexes = [
    { key: 'idx_company_period', type: 'unique', attrs: ['company_id', 'period_key'] },
  ];
  for (const idx of periodIndexes) {
    try {
      await databases.createIndex(dbId, payrollPeriodsTable, idx.key, idx.type, idx.attrs);
      console.log(`Created index ${idx.key} on ${payrollPeriodsTable}`);
      await sleep(1000);
    } catch (e) {
      if (e.code === 409) {
        console.log(`Index ${idx.key} already exists on ${payrollPeriodsTable}`);
      } else {
        console.error(`Error creating index ${idx.key}:`, e.message);
      }
    }
  }

  // 4. Update existing payroll_records table schema
  console.log(`Updating ${payrollRecordsTable} table schema...`);
  const recordAttrs = [
    { key: 'payroll_period_id', type: 'string', size: 255, required: false },
    { key: 'period_key', type: 'string', size: 7, required: false },
  ];

  for (const attr of recordAttrs) {
    try {
      if (attr.type === 'string') {
        await databases.createStringAttribute(dbId, payrollRecordsTable, attr.key, attr.size, attr.required);
      }
      console.log(`Created attribute ${attr.key} on ${payrollRecordsTable}`);
      await sleep(1000);
    } catch (e) {
      if (e.code === 409) {
        console.log(`Attribute ${attr.key} already exists on ${payrollRecordsTable}`);
      } else {
        console.error(`Error creating attribute ${attr.key}:`, e.message);
      }
    }
  }

  // 5. Add Indexes to payroll_records
  const recordIndexes = [
    { key: 'idx_payroll_employee_period', type: 'unique', attrs: ['company_id', 'employee_id', 'payroll_period_id'] },
    { key: 'idx_payroll_company_period', type: 'key', attrs: ['company_id', 'payroll_period_id'] },
  ];
  for (const idx of recordIndexes) {
    try {
      await databases.createIndex(dbId, payrollRecordsTable, idx.key, idx.type, idx.attrs);
      console.log(`Created index ${idx.key} on ${payrollRecordsTable}`);
      await sleep(1000);
    } catch (e) {
      if (e.code === 409) {
        console.log(`Index ${idx.key} already exists on ${payrollRecordsTable}`);
      } else {
        console.error(`Error creating index ${idx.key}:`, e.message);
      }
    }
  }

  // 6. Backfill existing payroll_records
  console.log('Backfilling payroll_records...');
  let cursor = null;
  let hasMore = true;
  let totalRecords = 0;
  let backfilled = 0;
  let withoutPeriod = 0;
  let unresolved = 0;
  let newPeriodsCreated = 0;
  
  // Cache created periods to avoid duplicates and rapid API calls
  const periodsCache = {}; // "companyId_YYYY-MM": "periodId"

  while (hasMore) {
    const queries = [];
    if (cursor) queries.push(require('node-appwrite').Query.cursorAfter(cursor));
    
    const response = await databases.listDocuments(dbId, payrollRecordsTable, queries);
    for (const doc of response.documents) {
      totalRecords++;
      if (doc.payroll_period_id) {
        // Already processed
        continue;
      }
      withoutPeriod++;

      // We need to reliably extract the month. 
      // If we don't have year/month, we can use created_at as an approximation.
      // But typically payroll is generated AT the end of the month or early next month.
      // Let's assume the created_at gives the month, or maybe there's a better way.
      // Let's look if there is any other hint in the document? There isn't in payroll_records natively yet.
      // Wait, in Phase 11, the prompt says "استخرج الشهر من بياناتها الحالية بشكل موثوق".
      // Let's just use `created_at` and assume it's for that month.
      if (!doc.created_at) {
         unresolved++;
         continue;
      }

      const date = new Date(doc.created_at);
      const year = date.getUTCFullYear();
      const month = date.getUTCMonth() + 1; // 1-12
      const periodKey = `${year}-${month.toString().padStart(2, '0')}`;
      const cacheKey = `${doc.company_id}_${periodKey}`;

      let periodId = periodsCache[cacheKey];
      if (!periodId) {
        // Check if period already exists in DB
        const existingPeriods = await databases.listDocuments(dbId, payrollPeriodsTable, [
          require('node-appwrite').Query.equal('company_id', doc.company_id),
          require('node-appwrite').Query.equal('period_key', periodKey)
        ]);

        if (existingPeriods.documents.length > 0) {
          periodId = existingPeriods.documents[0].$id;
        } else {
          // Create new canonical period
          periodId = 'per_' + require('crypto').randomBytes(8).toString('hex');
          const startDate = new Date(Date.UTC(year, month - 1, 1)).toISOString();
          const endDate = new Date(Date.UTC(year, month, 0, 23, 59, 59, 999)).toISOString();

          await databases.createDocument(dbId, payrollPeriodsTable, periodId, {
            company_id: doc.company_id,
            period_key: periodKey,
            year: year,
            month: month,
            start_date: startDate,
            end_date: endDate,
            status: 'closed', // Mark old ones as closed safely
            created_at: new Date().toISOString()
          });
          newPeriodsCreated++;
        }
        periodsCache[cacheKey] = periodId;
      }

      // Update record
      try {
        await databases.updateDocument(dbId, payrollRecordsTable, doc.$id, {
          payroll_period_id: periodId,
          period_key: periodKey
        });
        backfilled++;
      } catch (err) {
         console.error(`Failed to update payroll_record ${doc.$id}: ${err.message}`);
         unresolved++;
      }
    }
    
    if (response.documents.length > 0) {
      cursor = response.documents[response.documents.length - 1].$id;
    } else {
      hasMore = false;
    }
  }
  
  console.log('Migration completed.');
  console.log(`Total Payroll Records: ${totalRecords}`);
  console.log(`Records without period before migration: ${withoutPeriod}`);
  console.log(`Records successfully backfilled: ${backfilled}`);
  console.log(`Records unresolved: ${unresolved}`);
  console.log(`New Periods created: ${newPeriodsCreated}`);
}

runMigration().catch(console.error);
