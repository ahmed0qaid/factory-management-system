const endpoint = process.env.APPWRITE_ENDPOINT || 'https://fra.cloud.appwrite.io/v1';
const projectId = process.env.APPWRITE_PROJECT_ID;

async function test() {
  console.log('Logging in as hr001@hr.local...');
  
  // 1. Create session
  const sessionRes = await fetch(`${endpoint}/account/sessions/email`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Appwrite-Project': projectId
    },
    body: JSON.stringify({
      email: 'hr001@hr.local',
      password: '12345678'
    })
  });
  
  if (!sessionRes.ok) {
    const error = await sessionRes.text();
    console.error('Login failed:', error);
    return;
  }
  
  const cookies = sessionRes.headers.get('set-cookie');
  console.log('Logged in successfully!');

  // 2. Execute Function (With Biometric)
  console.log('\n--- Test 1: With Biometric ID (BIO903) ---');
  const body1 = JSON.stringify({
    employeeNumber: 'BIO903',
    fullName: 'Test Bio 903',
    temporaryPassword: 'password123',
    phone: '+12345678901',
    role: 'employee',
    biometricEmployeeId: 'BIO903'
  });

  const execRes1 = await fetch(`${endpoint}/functions/create_employee/executions`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Appwrite-Project': projectId,
      'Cookie': cookies
    },
    body: JSON.stringify({
      body: body1,
      async: false
    })
  });

  const execData1 = await execRes1.json();
  console.log('Execution Status:', execData1.status);
  console.log('Execution Response:', execData1.responseBody);

  // 3. Execute Function (Without Biometric)
  console.log('\n--- Test 2: Without Biometric ID (NOBIO904) ---');
  const body2 = JSON.stringify({
    employeeNumber: 'NOBIO904',
    fullName: 'Test NoBio 904',
    temporaryPassword: 'password123',
    phone: '+29876543210',
    role: 'employee'
  });

  const execRes2 = await fetch(`${endpoint}/functions/create_employee/executions`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Appwrite-Project': projectId,
      'Cookie': cookies
    },
    body: JSON.stringify({
      body: body2,
      async: false
    })
  });

  const execData2 = await execRes2.json();
  console.log('Execution Status:', execData2.status);
  console.log('Execution Response:', execData2.responseBody);

  // 4. Verify DB via REST Server SDK
  console.log('\n--- Checking Database ---');
  const dbRes = await fetch(`${endpoint}/databases/${process.env.APPWRITE_DATABASE_ID}/collections/profiles/documents`, {
    method: 'GET',
    headers: {
      'X-Appwrite-Project': projectId,
      'X-Appwrite-Key': process.env.APPWRITE_API_KEY
    }
  });

  const dbData = await dbRes.json();
  const bio903 = dbData.documents.find(d => d.employee_number === 'BIO903');
  const nobio904 = dbData.documents.find(d => d.employee_number === 'NOBIO904');

  if (bio903) {
    console.log(`FOUND BIO903: name=${bio903.full_name}, biometric_employee_id=${bio903.biometric_employee_id}`);
  } else {
    console.log('BIO903 NOT FOUND in DB');
  }

  if (nobio904) {
    console.log(`FOUND NOBIO904: name=${nobio904.full_name}, biometric_employee_id=${nobio904.biometric_employee_id}`);
  } else {
    console.log('NOBIO904 NOT FOUND in DB');
  }
}

test().catch(console.error);
