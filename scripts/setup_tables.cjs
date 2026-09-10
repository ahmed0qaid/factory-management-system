const { Client, Databases, Permission, Role } = require('node-appwrite');

async function setupTables() {
  const client = new Client()
    .setEndpoint(process.env.APPWRITE_ENDPOINT)
    .setProject(process.env.APPWRITE_PROJECT_ID)
    .setKey(process.env.APPWRITE_API_KEY);

  const db = new Databases(client);
  const databaseId = process.env.APPWRITE_DATABASE_ID;

  async function createCollectionSafe(collectionId, name, permissions) {
    try {
      await db.getCollection(databaseId, collectionId);
      console.log(`Collection ${collectionId} already exists.`);
    } catch (e) {
      if (e.code === 404) {
        await db.createCollection({ databaseId, collectionId, name, permissions, documentSecurity: true });
        console.log(`Collection ${collectionId} created.`);
      } else {
        throw e;
      }
    }
  }

  async function createAttributeSafe(collectionId, type, key, size, required, defaultValue) {
    try {
      switch (type) {
        case 'string':
          await db.createStringAttribute({ databaseId, collectionId, key, size, required, xdefault: defaultValue });
          break;
        case 'integer':
          await db.createIntegerAttribute({ databaseId, collectionId, key, required, xdefault: defaultValue });
          break;
        case 'double':
          await db.createFloatAttribute({ databaseId, collectionId, key, required, xdefault: defaultValue });
          break;
        case 'boolean':
          await db.createBooleanAttribute({ databaseId, collectionId, key, required, xdefault: defaultValue });
          break;
        case 'datetime':
          await db.createDatetimeAttribute({ databaseId, collectionId, key, required, xdefault: defaultValue });
          break;
      }
      console.log(`Attribute ${key} created on ${collectionId}. (Might need to wait for availability)`);
    } catch (e) {
      if (e.code === 409) {
        // Already exists
      } else {
        console.error(`Error creating attribute ${key}:`, e.message);
      }
    }
  }

  async function createIndexSafe(collectionId, key, type, attributes) {
    try {
      await db.createIndex({ databaseId, collectionId, key, type, attributes });
      console.log(`Index ${key} created on ${collectionId}.`);
    } catch (e) {
      if (e.code === 409) {
        // Already exists
      } else {
        console.error(`Error creating index ${key}:`, e.message);
      }
    }
  }

  // 1. notifications
  await createCollectionSafe('notifications', 'Notifications', [
    Permission.read(Role.users()),
    Permission.create(Role.users()),
    Permission.update(Role.team('company_main', 'hr_admin')),
    Permission.delete(Role.team('company_main', 'hr_admin')),
  ]);
  
  await createAttributeSafe('notifications', 'string', 'company_id', 36, true);
  await createAttributeSafe('notifications', 'string', 'employee_id', 36, true);
  await createAttributeSafe('notifications', 'string', 'title', 160, true);
  await createAttributeSafe('notifications', 'string', 'body', 2000, true);
  await createAttributeSafe('notifications', 'string', 'type', 50, true);
  await createAttributeSafe('notifications', 'string', 'reference_table', 80, false);
  await createAttributeSafe('notifications', 'string', 'reference_id', 80, false);
  await createAttributeSafe('notifications', 'boolean', 'is_read', 0, false, false);
  await createAttributeSafe('notifications', 'datetime', 'created_at', 0, true);
  
  // 2. leave_requests
  await createCollectionSafe('leave_requests', 'Leave Requests', [
    Permission.read(Role.users()),
    Permission.create(Role.users()),
  ]);

  await createAttributeSafe('leave_requests', 'string', 'company_id', 36, true);
  await createAttributeSafe('leave_requests', 'string', 'employee_id', 36, true);
  await createAttributeSafe('leave_requests', 'string', 'leave_type', 80, true);
  await createAttributeSafe('leave_requests', 'datetime', 'start_date', 0, true);
  await createAttributeSafe('leave_requests', 'datetime', 'end_date', 0, true);
  await createAttributeSafe('leave_requests', 'string', 'reason', 2000, false);
  await createAttributeSafe('leave_requests', 'string', 'status', 32, true);
  await createAttributeSafe('leave_requests', 'string', 'reviewed_by', 80, false);
  await createAttributeSafe('leave_requests', 'datetime', 'reviewed_at', 0, false);
  await createAttributeSafe('leave_requests', 'datetime', 'created_at', 0, true);

  // 3. advances
  await createCollectionSafe('advances', 'Advances', [
    Permission.read(Role.users()),
    Permission.create(Role.users()),
  ]);
  
  await createAttributeSafe('advances', 'string', 'company_id', 36, true);
  await createAttributeSafe('advances', 'string', 'employee_id', 36, true);
  await createAttributeSafe('advances', 'double', 'principal_amount', 0, true);
  await createAttributeSafe('advances', 'double', 'installment_amount', 0, true);
  await createAttributeSafe('advances', 'double', 'remaining_amount', 0, true);
  await createAttributeSafe('advances', 'string', 'reason', 2000, false);
  await createAttributeSafe('advances', 'string', 'status', 32, true);
  await createAttributeSafe('advances', 'datetime', 'created_at', 0, true);

  console.log('Sleeping 5 seconds to wait for attributes to become available before creating indexes...');
  await new Promise(r => setTimeout(r, 5000));

  await createIndexSafe('notifications', 'notifications_employee_idx', 'key', ['employee_id', 'created_at']);
  await createIndexSafe('leave_requests', 'leave_employee_idx', 'key', ['employee_id', 'created_at']);
  await createIndexSafe('advances', 'advances_employee_idx', 'key', ['employee_id', 'created_at']);

  console.log('Setup finished.');
}

setupTables().catch(console.error);
