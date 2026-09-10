import { Client, Users, Databases, ID, Permission, Role } from 'node-appwrite';

const technicalEmailDomain = 'hr.local';
const profilesTable = 'profiles';
const managementRoles = ['hr_admin'];

export default async ({ req, res, log, error }) => {
  try {
    const client = new Client()
      .setEndpoint(process.env.APPWRITE_ENDPOINT)
      .setProject(process.env.APPWRITE_PROJECT_ID)
      .setKey(process.env.APPWRITE_API_KEY);

    const users = new Users(client);
    const databases = new Databases(client);
    const databaseId = process.env.APPWRITE_DATABASE_ID || 'hr';

    const actorId = req.headers['x-appwrite-user-id'] || process.env.APPWRITE_FUNCTION_USER_ID;
    if (!actorId) return res.json({ success: false, error: 'Unauthorized' }, 401);

    const actorProfile = await databases.getDocument(databaseId, profilesTable, actorId);

    if (!managementRoles.includes(actorProfile.role)) {
      return res.json({ success: false, error: 'Forbidden' }, 403);
    }

    const body = typeof req.body === 'string' ? JSON.parse(req.body || '{}') : (req.body || {});
    const {
      employeeNumber,
      fullName,
      temporaryPassword,
      role = 'employee',
      baseSalary = 0,
      monthlyBonus = 0,
      departmentId,
      departmentName,
      jobTitleId,
      jobTitleName,
      hireDate,
      biometricEmployeeId
    } = body;
    const phone = body.phone && String(body.phone).trim()
      ? String(body.phone).trim()
      : null;

    if (!employeeNumber || !fullName || !temporaryPassword) {
      return res.json({ success: false, error: 'Missing required fields' }, 400);
    }

    if (temporaryPassword.length < 8) {
      return res.json({
        success: false,
        error: 'كلمة المرور يجب أن تكون 8 أحرف على الأقل'
      }, 400);
    }

    if (phone && !/^\+[0-9]{8,15}$/.test(phone)) {
      return res.json({
        success: false,
        error: 'أدخل رقم الهاتف بصيغة دولية مثل +967770000000'
      }, 400);
    }

    const email = `${String(employeeNumber).trim().toLowerCase()}@${technicalEmailDomain}`;

    const user = await users.create(
      ID.unique(),
      email,
      phone || undefined,
      temporaryPassword,
      fullName
    );

    const monthlyEntitlement = Number(baseSalary) + Number(monthlyBonus);
    const profileData = {
      company_id: actorProfile.company_id,
      employee_number: employeeNumber,
      full_name: fullName,
      role,
      department_id: departmentId || null,
      department_name: departmentName || null,
      job_title_id: jobTitleId || null,
      job_title_name: jobTitleName || null,
      hire_date: hireDate || null,
      base_salary: Number(baseSalary),
      monthly_bonus: Number(monthlyBonus),
      biometric_employee_id: biometricEmployeeId || null,
      active: true,
      must_change_password: true,
    };
    if (phone) {
      profileData.phone = phone;
    }

    try {
      await databases.createDocument(
        databaseId,
        profilesTable,
        user.$id,
        profileData,
        [
          Permission.read(Role.user(user.$id)),
          Permission.update(Role.user(user.$id)),
          Permission.read(Role.team(actorProfile.company_id, 'hr_admin')),
          Permission.update(Role.team(actorProfile.company_id, 'hr_admin')),
          Permission.delete(Role.team(actorProfile.company_id, 'hr_admin')),
        ]
      );
    } catch (rowError) {
      // If row creation fails, delete the user in Auth to prevent orphaned users
      try {
        await users.delete(user.$id);
      } catch (deleteError) {
        error(`Failed to delete orphaned user: ${deleteError.message}`);
      }
      throw rowError; // Re-throw to be handled by the main catch block
    }

    return res.json({
      success: true,
      userId: user.$id,
      login: employeeNumber,
      monthlyEntitlement,
    });
  } catch (e) {
    error(String(e?.message || e));
    
    // Check if user already exists
    if (e.code === 409 || String(e?.message).includes('already exists')) {
      return res.json({ success: false, error: 'يوجد موظف بنفس رقم الموظف' }, 400);
    }
    
    return res.json({ success: false, error: String(e?.message || e) }, 500);
  }
};
