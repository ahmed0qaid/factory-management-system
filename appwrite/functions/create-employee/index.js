import { Client, Users, Databases, Teams, ID, Permission, Role } from 'node-appwrite';

const technicalEmailDomain = 'hr.local';
const profilesTable = 'profiles';
const managementRoles = ['hr_admin'];
const assignableRoles = ['employee', 'general_manager', 'financial_manager', 'hr_admin'];

export default async ({ req, res, log, error }) => {
  try {
    const client = new Client()
      .setEndpoint(process.env.APPWRITE_ENDPOINT)
      .setProject(process.env.APPWRITE_PROJECT_ID)
      .setKey(process.env.APPWRITE_API_KEY);

    const users = new Users(client);
    const databases = new Databases(client);
    const teams = new Teams(client);
    const databaseId = process.env.APPWRITE_DATABASE_ID || 'hr';

    const actorId =
      req.headers['x-appwrite-user-id'] || process.env.APPWRITE_FUNCTION_USER_ID;
    if (!actorId) {
      return res.json({ success: false, error: 'Unauthorized' }, 401);
    }

    const actorProfile = await databases.getDocument(
      databaseId,
      profilesTable,
      actorId,
    );

    if (!managementRoles.includes(actorProfile.role)) {
      return res.json({ success: false, error: 'Forbidden' }, 403);
    }

    if (actorProfile.active === false) {
      return res.json({ success: false, error: 'Disabled account' }, 403);
    }

    const body =
      typeof req.body === 'string' ? JSON.parse(req.body || '{}') : req.body || {};
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
      biometricEmployeeId,
    } = body;
    const phone =
      body.phone && String(body.phone).trim() ? String(body.phone).trim() : null;

    if (!employeeNumber || !fullName || !temporaryPassword) {
      return res.json({ success: false, error: 'Missing required fields' }, 400);
    }

    if (!assignableRoles.includes(role)) {
      return res.json({ success: false, error: 'Invalid employee role' }, 400);
    }

    if (temporaryPassword.length < 8) {
      return res.json(
        {
          success: false,
          error: 'كلمة المرور يجب أن تكون 8 أحرف على الأقل',
        },
        400,
      );
    }

    if (phone && !/^\+[0-9]{8,15}$/.test(phone)) {
      return res.json(
        {
          success: false,
          error: 'أدخل رقم الهاتف بصيغة دولية مثل +967770000000',
        },
        400,
      );
    }

    const companyId = actorProfile.company_id;
    if (!companyId) {
      return res.json({ success: false, error: 'Actor company is missing' }, 400);
    }

    const email = `${String(employeeNumber).trim().toLowerCase()}@${technicalEmailDomain}`;

    const user = await users.create(
      ID.unique(),
      email,
      phone || undefined,
      temporaryPassword,
      fullName,
    );

    const monthlyEntitlement = Number(baseSalary) + Number(monthlyBonus);
    const profileData = {
      company_id: companyId,
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
      // Server SDK memberships are accepted immediately. Keeping every employee
      // in the company team makes Role.team(companyId) permissions reliable for
      // announcements and other company-scoped resources.
      await teams.createMembership(
        companyId,
        [role],
        undefined,
        user.$id,
        undefined,
        undefined,
        fullName,
      );

      await databases.createDocument(
        databaseId,
        profilesTable,
        user.$id,
        profileData,
        [
          Permission.read(Role.user(user.$id)),
          Permission.read(Role.team(companyId, 'hr_admin')),
          Permission.update(Role.team(companyId, 'hr_admin')),
          Permission.delete(Role.team(companyId, 'hr_admin')),
        ],
      );
    } catch (setupError) {
      // Roll back Auth user to avoid an orphaned account if either company-team
      // membership or profile creation fails.
      try {
        await users.delete(user.$id);
      } catch (deleteError) {
        error(`Failed to delete orphaned user: ${deleteError.message}`);
      }
      throw setupError;
    }

    log(`Created employee ${employeeNumber} in company team ${companyId}`);
    return res.json({
      success: true,
      userId: user.$id,
      login: employeeNumber,
      monthlyEntitlement,
    });
  } catch (e) {
    error(String(e?.message || e));

    if (e.code === 409 || String(e?.message).includes('already exists')) {
      return res.json(
        { success: false, error: 'يوجد موظف بنفس رقم الموظف' },
        400,
      );
    }

    return res.json({ success: false, error: String(e?.message || e) }, 500);
  }
};
