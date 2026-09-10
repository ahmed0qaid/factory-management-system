const { Client, Users, TablesDB, ID, Permission, Role } = require('node-appwrite');

async function testFunction() {
  const client = new Client()
    .setEndpoint(process.env.APPWRITE_ENDPOINT)
    .setProject(process.env.APPWRITE_PROJECT_ID)
    .setKey(process.env.APPWRITE_API_KEY);

  const users = new Users(client);
  const tablesDB = new TablesDB(client);
  const databaseId = 'hr';
  
  const employeeNumber = 'EMP002';
  const fullName = 'أحمد علي';
  const temporaryPassword = 'password123';
  
  const email = `${employeeNumber.toLowerCase()}@hr.local`;

  try {
    const user = await users.create(
      ID.unique(),
      email,
      null, // phone
      temporaryPassword,
      fullName
    );

    console.log('Created user in Auth:', user.$id);

    await tablesDB.createRow({
      databaseId,
      tableId: 'profiles',
      rowId: user.$id,
      data: {
        company_id: 'default',
        employee_number: employeeNumber,
        full_name: fullName,
        phone: '784615630',
        role: 'employee',
        base_salary: 60000,
        monthly_bonus: 15000,
        active: true,
        must_change_password: true,
      },
      permissions: [
        Permission.read(Role.user(user.$id)),
        Permission.update(Role.user(user.$id))
      ],
    });

    console.log('Created row in profiles:', user.$id);
  } catch (e) {
    console.error('Error during test:', e);
  }
}

testFunction();
