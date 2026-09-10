import { Client, Functions, ID } from 'node-appwrite';

async function setVars() {
  const client = new Client()
    .setEndpoint(process.env.APPWRITE_ENDPOINT)
    .setProject(process.env.APPWRITE_PROJECT_ID)
    .setKey(process.env.APPWRITE_API_KEY);

  const functions = new Functions(client);
  const functionId = 'update_employee_credentials';
  const vars = {
    APPWRITE_ENDPOINT: process.env.APPWRITE_ENDPOINT,
    APPWRITE_PROJECT_ID: process.env.APPWRITE_PROJECT_ID,
    APPWRITE_DATABASE_ID: process.env.APPWRITE_DATABASE_ID || 'hr',
    APPWRITE_API_KEY: process.env.APPWRITE_API_KEY,
  };

  const existing = await functions.listVariables(functionId);
  // Delete all existing wrong variables
  for (const v of existing.variables) {
    try {
      await functions.deleteVariable(functionId, v.$id);
      console.log('Deleted old var:', v.$id);
    } catch (e) {
      console.log('Could not delete', v.$id);
    }
  }

  for (const [key, value] of Object.entries(vars)) {
    try {
      await functions.createVariable(functionId, ID.unique(), key, value);
      console.log(`Created ${key}`);
    } catch (e) {
      console.error(`Failed ${key}: ${e.message}`);
    }
  }
}
setVars().catch(console.error);
