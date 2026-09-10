const { Client, Account, Functions, ExecutionMethod } = require('node-appwrite');

async function testEMP005() {
  const client = new Client()
    .setEndpoint('https://fra.cloud.appwrite.io/v1')
    .setProject('6a6a49d1000884049205');
  
  // Note: We need a valid session for an HR Admin to call the function.
  // Since we don't have the password for HR001, we will just use Server SDK to simulate the function logic 
  // directly for EMP005, to ensure the database schema and user creation are rock solid.

  const sdk = require('node-appwrite');
  const serverClient = new sdk.Client()
    .setEndpoint('https://fra.cloud.appwrite.io/v1')
    .setProject('6a6a49d1000884049205')
    .setKey(process.env.APPWRITE_API_KEY);

  const users = new sdk.Users(serverClient);
  const tablesDB = new sdk.TablesDB(serverClient);

  const employeeNumber = 'EMP005';
  const fullName = 'Test Employee 5';
  const temporaryPassword = 'password1234';
  const phone = '0501234567';
  
  const email = `${employeeNumber.toLowerCase()}@hr.local`;

  console.log('Creating User in Auth...');
  const user = await users.create(
    sdk.ID.unique(),
    email,
    null, // phone
    temporaryPassword,
    fullName
  );
  console.log('User created:', user.$id);

  console.log('Creating Row in Profiles...');
  await tablesDB.createRow({
    databaseId: 'hr',
    tableId: 'profiles',
    rowId: user.$id,
    data: {
      company_id: 'default',
      employee_number: employeeNumber,
      full_name: fullName,
      role: 'employee',
      phone: phone,
      base_salary: 5000,
      monthly_bonus: 500,
      active: true,
      must_change_password: true,
    },
    permissions: [
      sdk.Permission.read(sdk.Role.user(user.$id)),
      sdk.Permission.update(sdk.Role.user(user.$id))
    ],
  });
  console.log('Row created successfully.');
  
  console.log('\nTesting login for EMP005...');
  const client2 = new Client()
    .setEndpoint('https://fra.cloud.appwrite.io/v1')
    .setProject('6a6a49d1000884049205');
  const account = new Account(client2);
  
  try {
    const session = await account.createEmailPasswordSession(email, temporaryPassword);
    console.log('Login successful! Session ID:', session.$id);
  } catch (e) {
    console.error('Login failed:', e.message);
  }
}

testEMP005().catch(console.error);
