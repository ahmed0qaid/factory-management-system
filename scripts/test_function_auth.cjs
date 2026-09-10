const { Client, Users, Functions, Databases, Query } = require('node-appwrite');

async function test() {
  const client = new Client()
    .setEndpoint(process.env.APPWRITE_ENDPOINT)
    .setProject(process.env.APPWRITE_PROJECT_ID)
    .setKey(process.env.APPWRITE_API_KEY);

  const users = new Users(client);
  const functions = new Functions(client);
  const databases = new Databases(client);

  try {
    // 1. Get HR Admin user ID
    console.log('Finding HR Admin (hr001@hr.local)...');
    const userList = await users.list([Query.equal('email', 'hr001@hr.local')]);
    if (userList.users.length === 0) {
      throw new Error('HR Admin not found!');
    }
    const adminId = userList.users[0].$id;
    console.log('Admin ID:', adminId);

    // 2. Execute Function (Employee with Biometric)
    console.log('\n--- Test 1: With Biometric ID ---');
    const execution1 = await functions.createExecution(
      'create_employee',
      JSON.stringify({
        employeeNumber: 'BIO101',
        fullName: 'Test Bio 101',
        temporaryPassword: 'password123',
        role: 'employee',
        biometricEmployeeId: '9999101'
      }),
      false, // async
      '/',
      'POST',
      { 'x-appwrite-user-id': adminId }
    );
    
    console.log('Execution 1 status:', execution1.status);
    console.log('Execution 1 response:', execution1.responseBody);
    console.log('Execution 1 errors:', execution1.errors);

    // 3. Check DB
    console.log('Checking database for BIO101...');
    const dbProfiles1 = await databases.listDocuments(process.env.APPWRITE_DATABASE_ID || 'hr', 'profiles', [
      Query.equal('employee_number', 'BIO101')
    ]);
    if (dbProfiles1.documents.length > 0) {
      const doc = dbProfiles1.documents[0];
      console.log(`FOUND: name=${doc.full_name}, employee_number=${doc.employee_number}, biometric_employee_id=${doc.biometric_employee_id}`);
    } else {
      console.log('NOT FOUND in DB');
    }

    // 4. Execute Function (Employee without Biometric)
    console.log('\n--- Test 2: Without Biometric ID ---');
    const execution2 = await functions.createExecution(
      'create_employee',
      JSON.stringify({
        employeeNumber: 'NOBIO102',
        fullName: 'Test NoBio 102',
        temporaryPassword: 'password123',
        role: 'employee'
      }),
      false, // async
      '/',
      'POST',
      { 'x-appwrite-user-id': adminId }
    );
    
    console.log('Execution 2 status:', execution2.status);
    console.log('Execution 2 response:', execution2.responseBody);
    console.log('Execution 2 errors:', execution2.errors);

    // 5. Check DB
    console.log('Checking database for NOBIO102...');
    const dbProfiles2 = await databases.listDocuments(process.env.APPWRITE_DATABASE_ID || 'hr', 'profiles', [
      Query.equal('employee_number', 'NOBIO102')
    ]);
    if (dbProfiles2.documents.length > 0) {
      const doc = dbProfiles2.documents[0];
      console.log(`FOUND: name=${doc.full_name}, employee_number=${doc.employee_number}, biometric_employee_id=${doc.biometric_employee_id}`);
    } else {
      console.log('NOT FOUND in DB');
    }

  } catch (e) {
    console.error('Error:', e);
  }
}

test();
