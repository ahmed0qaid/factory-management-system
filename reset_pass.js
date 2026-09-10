import { Client, Users } from 'node-appwrite';

async function reset() {
  const client = new Client()
    .setEndpoint(process.env.APPWRITE_ENDPOINT)
    .setProject(process.env.APPWRITE_PROJECT_ID)
    .setKey(process.env.APPWRITE_API_KEY);

  const users = new Users(client);
  await users.updatePassword('6a71b9690026efc8c835', 'password123');
  console.log('Employee 9 password reset to password123');
}
reset().catch(console.error);
