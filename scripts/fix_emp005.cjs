const { Client, Users, TablesDB, Query, Teams, Account, ID, Permission, Role } = require('node-appwrite');

async function fixEMP005() {
  const serverClient = new Client()
    .setEndpoint(process.env.APPWRITE_ENDPOINT)
    .setProject(process.env.APPWRITE_PROJECT_ID)
    .setKey(process.env.APPWRITE_API_KEY);

  const users = new Users(serverClient);
  const tablesDB = new TablesDB(serverClient);
  const teams = new Teams(serverClient);

  const email = 'emp005@hr.local';
  const password = '12345678';
  let userId;

  console.log('--- Checking User in Auth ---');
  try {
    const userList = await users.list([Query.equal('email', email)]);
    if (userList.users.length > 0) {
      const user = userList.users[0];
      userId = user.$id;
      console.log('User found in Auth. ID:', userId);
      
      await users.updatePassword(userId, password);
      console.log('Password reset to 12345678');
    } else {
      console.log('User NOT found. Creating new user...');
      const user = await users.create(ID.unique(), email, null, password, 'موظف اختبار EMP005');
      userId = user.$id;
      console.log('User created. ID:', userId);
    }
  } catch (e) {
    console.error('Error with Auth User:', e.message);
    return;
  }

  console.log('\n--- Testing Login Session ---');
  const client2 = new Client()
    .setEndpoint(process.env.APPWRITE_ENDPOINT)
    .setProject(process.env.APPWRITE_PROJECT_ID);
  const account = new Account(client2);
  
  try {
    const session = await account.createEmailPasswordSession(email, password);
    console.log('Login successful! Session ID:', session.$id);
  } catch (e) {
    console.error('Login failed:', e.message);
    return; // Stop if login fails
  }

  console.log('\n--- Checking Profile Row ---');
  try {
    const rows = await tablesDB.listRows({
      databaseId: process.env.APPWRITE_DATABASE_ID,
      tableId: 'profiles',
      queries: [Query.equal('employee_number', 'EMP005')]
    });
    
    let rowId = userId;
    const profileData = {
      company_id: 'company_main',
      employee_number: 'EMP005',
      full_name: 'موظف اختبار EMP005',
      role: 'employee',
      phone: '',
      department_id: '',
      department_name: 'الحسابات',
      job_title_id: '',
      job_title_name: 'محاسب',
      base_salary: 60000,
      monthly_bonus: 15000,
      active: true,
      must_change_password: true,
    };

    const permissions = [
      Permission.read(Role.user(userId)),
      Permission.update(Role.user(userId)),
      Permission.read(Role.team('company_main', 'hr_admin')),
      Permission.update(Role.team('company_main', 'hr_admin')),
      Permission.delete(Role.team('company_main', 'hr_admin')),
    ];

    if (rows.total > 0) {
      console.log('Profile row found. Updating...');
      await tablesDB.updateRow({
        databaseId: process.env.APPWRITE_DATABASE_ID,
        tableId: 'profiles',
        rowId: rows.rows[0].$id,
        data: profileData,
        permissions: permissions
      });
      console.log('Profile row updated successfully.');
    } else {
      console.log('Profile row NOT found. Creating...');
      try {
        await tablesDB.createRow({
          databaseId: process.env.APPWRITE_DATABASE_ID,
          tableId: 'profiles',
          rowId: rowId,
          data: profileData,
          permissions: permissions
        });
        console.log('Profile row created successfully.');
      } catch (e) {
        if (e.code === 409) {
           console.log('Row ID conflict. Searching by document ID directly instead of employee_number.');
           await tablesDB.updateRow({
             databaseId: process.env.APPWRITE_DATABASE_ID,
             tableId: 'profiles',
             rowId: rowId,
             data: profileData,
             permissions: permissions
           });
           console.log('Profile row updated by document ID successfully.');
        } else {
           throw e;
        }
      }
    }
    
    console.log('\n--- Testing getRow with User ID ---');
    const verifyRow = await tablesDB.getRow({
      databaseId: process.env.APPWRITE_DATABASE_ID,
      tableId: 'profiles',
      rowId: rowId,
    });
    console.log('getRow successful. Employee Number:', verifyRow.employee_number);

  } catch (e) {
    console.error('Error with Profile Row:', e.message);
  }

  console.log('\n--- Checking Team Membership ---');
  try {
    let isMember = false;
    try {
      const memberships = await teams.listMemberships('company_main');
      isMember = memberships.memberships.some(m => m.userId === userId);
    } catch(e) {
      console.log('Listing memberships failed, trying to add directly...');
    }

    if (!isMember) {
      console.log('Adding user to team company_main...');
      await teams.createMembership(
        'company_main',
        ['employee'], // roles
        email,
        undefined, // userId (Appwrite typically uses email/phone or explicit userId. In older SDK, it might take email. Let's see)
        undefined,
        '', 
        userId // Actually, createMembership has many params depending on version. Let's look up proper signature if it fails
      );
      console.log('User added to team.');
    } else {
      console.log('User is already a member of company_main.');
    }
  } catch (e) {
    console.error('Error adding to team:', e.message);
    // If it fails due to parameter mismatch, we'll fix it in the next step
    if (e.message.includes('Missing required parameter') || e.message.includes('Invalid')) {
       try {
         // Appwrite 1.4+: teams.createMembership(teamId, roles, email, userId, phone, url, name)
         // Wait, the user might need an invitation URL.
         // Let's just create an empty URL.
         await teams.createMembership('company_main', ['employee'], email, userId, undefined, 'https://localhost');
         console.log('User added to team via fallback.');
       } catch (e2) {
         console.error('Fallback failed:', e2.message);
       }
    }
  }
}

fixEMP005().catch(console.error);
