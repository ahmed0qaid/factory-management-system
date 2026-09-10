import { Client, Account, Functions } from 'node-appwrite';

async function runTest() {
  const client = new Client()
    .setEndpoint(process.env.APPWRITE_ENDPOINT)
    .setProject(process.env.APPWRITE_PROJECT_ID);

  const account = new Account(client);
  const functions = new Functions(client);

  try {
    const session = await account.createEmailPasswordSession('hr001@hr.local', '12345678');
    console.log('Logged in successfully', session.$id);
    
    // Now trigger the function as this user
    const execution = await functions.createExecution(
      'update_employee_credentials',
      JSON.stringify({
        profileId: '6a71b9690026efc8c835', // emp009
        newEmployeeNumber: 'EMP009A', // Change number
        newPassword: 'newpassword123', // Change password
        mustChangePassword: true
      }),
      false // async
    );
    console.log('Execution Status:', execution.status);
    console.log('Execution Response:', execution.responseBody);
    console.log('Execution Error:', execution.responseHeaders);

  } catch (e) {
    console.error('Failed:', e);
  }
}
runTest();
