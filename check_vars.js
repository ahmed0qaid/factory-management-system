import { Client, Functions } from 'node-appwrite';

async function checkVars() {
  const client = new Client()
    .setEndpoint(process.env.APPWRITE_ENDPOINT)
    .setProject(process.env.APPWRITE_PROJECT_ID)
    .setKey(process.env.APPWRITE_API_KEY);

  const functions = new Functions(client);
  const vars = await functions.listVariables('update_employee_credentials');
  console.log(JSON.stringify(vars.variables, null, 2));
}

checkVars().catch(console.error);
