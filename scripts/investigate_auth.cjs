const { Client, Users, TablesDB, Query } = require('node-appwrite');

async function run() {
  const client = new Client()
    .setEndpoint(process.env.APPWRITE_ENDPOINT)
    .setProject(process.env.APPWRITE_PROJECT_ID)
    .setKey(process.env.APPWRITE_API_KEY);

  const users = new Users(client);
  const tablesDB = new TablesDB(client);
  const databaseId = 'hr';
  
  console.log('--- Step 2: Check Auth for emp004@hr.local ---');
  let user;
  try {
    const list = await users.list([Query.equal('email', 'emp004@hr.local')]);
    if (list.users.length > 0) {
      user = list.users[0];
      console.log('User found in Auth. ID:', user.$id);
      
      // Update password
      await users.updatePassword(user.$id, '12345678');
      console.log('Password for EMP004 reset to 12345678');
    } else {
      console.log('User NOT found in Auth');
    }
  } catch (e) {
    console.error('Error fetching user:', e.message);
  }

  console.log('\n--- Step 3: Check profiles for EMP004 ---');
  try {
    const rows = await tablesDB.listRows({
      databaseId,
      tableId: 'profiles',
      queries: [Query.equal('employee_number', 'EMP004')]
    });
    
    if (rows.total > 0) {
      console.log('Row found in profiles. ID:', rows.rows[0].$id);
      console.log('must_change_password:', rows.rows[0].must_change_password);
    } else {
      console.log('Row NOT found in profiles');
    }
  } catch(e) {
    console.error('Error fetching row:', e.message);
  }
}

run();
