import { Client, Functions } from 'node-appwrite';


async function test() {
  const client = new Client()
    .setEndpoint(process.env.APPWRITE_ENDPOINT)
    .setProject(process.env.APPWRITE_PROJECT_ID)
    .setKey(process.env.APPWRITE_API_KEY);

  const functions = new Functions(client);

  try {
    const deployment = await functions.listDeployments('create_employee');
    console.log('Deployments:', deployment.deployments.map(d => `${d.$id}: ${d.status}`));

    const execution1 = await functions.createExecution('create_employee', JSON.stringify({
      employeeNumber: 'TEST901',
      fullName: 'Test 901',
      temporaryPassword: 'password123',
      role: 'employee',
      biometricEmployeeId: 'BIO901'
    }), false);
    console.log('Test 901 Execution:', execution1.status, execution1.responseBody, execution1.errors);

    const execution2 = await functions.createExecution('create_employee', JSON.stringify({
      employeeNumber: 'TEST902',
      fullName: 'Test 902',
      temporaryPassword: 'password123',
      role: 'employee'
    }), false);
    console.log('Test 902 Execution:', execution2.status, execution2.responseBody, execution2.errors);

  } catch (e) {
    console.error('Error:', e);
  }
}

test();
