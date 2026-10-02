import { Client, Users, Databases, Query } from 'node-appwrite';

const technicalEmailDomain = 'hr.local';
const profilesTable = 'profiles';
const managementRoles = ['hr_admin'];
const allowedProfileFields = new Set([
  'fullName',
  'departmentName',
  'jobTitleId',
  'jobTitleName',
  'biometricEmployeeId',
  'phone',
  'baseSalary',
  'monthlyBonus',
  'dailyWorkHours',
  'active',
]);

const normalizeNullableText = (value) => {
  if (value === null || value === undefined) return '';
  return String(value).trim();
};

export default async ({ req, res, log, error }) => {
  try {
    const endpoint = process.env.APPWRITE_FUNCTION_ENDPOINT || process.env.APPWRITE_ENDPOINT || 'https://fra.cloud.appwrite.io/v1';
    const projectId = process.env.APPWRITE_FUNCTION_PROJECT_ID || process.env.APPWRITE_PROJECT_ID;

    const client = new Client()
      .setEndpoint(endpoint)
      .setProject(projectId)
      .setKey(process.env.APPWRITE_API_KEY);

    const users = new Users(client);
    const databases = new Databases(client);
    const databaseId = process.env.APPWRITE_DATABASE_ID || 'hr';

    const actorId = req.headers['x-appwrite-user-id'] || process.env.APPWRITE_FUNCTION_USER_ID;
    if (!actorId) return res.json({ success: false, error: 'Unauthorized' }, 401);

    const body = typeof req.body === 'string' ? JSON.parse(req.body || '{}') : (req.body || {});
    const {
      profileId,
      newEmployeeNumber,
      mustChangePassword,
      profileUpdates = {},
      action,
    } = body;
    const newPassword =
      body.newPassword && String(body.newPassword).trim()
        ? String(body.newPassword).trim()
        : null;

    if (!profileId) {
      return res.json({ success: false, error: 'Missing profileId' }, 400);
    }

    const actorProfile = await databases.getDocument(databaseId, profilesTable, actorId);
    if (actorProfile.active === false) {
      return res.json({ success: false, error: 'Disabled account' }, 403);
    }

    // The only self-service profile mutation allowed to a normal employee is
    // clearing the first-login password flag after Account.updatePassword succeeds.
    if (action === 'completeOwnPasswordChange') {
      if (profileId !== actorId) {
        return res.json({ success: false, error: 'Forbidden' }, 403);
      }
      if (
        newEmployeeNumber !== undefined ||
        newPassword !== null ||
        mustChangePassword !== undefined ||
        Object.keys(profileUpdates).length > 0
      ) {
        return res.json({ success: false, error: 'Invalid self-service payload' }, 400);
      }

      await databases.updateDocument(databaseId, profilesTable, actorId, {
        must_change_password: false,
      });
      return res.json({ success: true, message: 'Password change completed' });
    }

    if (!managementRoles.includes(actorProfile.role)) {
      return res.json({ success: false, error: 'Forbidden. HR Admin access required.' }, 403);
    }
    if (!actorProfile.company_id) {
      return res.json({ success: false, error: 'Actor company is missing' }, 400);
    }

    const userId = profileId;

    let targetProfile;
    try {
      targetProfile = await databases.getDocument(databaseId, profilesTable, profileId);
    } catch (e) {
      return res.json({ success: false, error: 'Employee profile not found' }, 404);
    }

    if (!targetProfile.company_id || targetProfile.company_id !== actorProfile.company_id) {
      return res.json({ success: false, error: 'Forbidden. Employee belongs to another company.' }, 403);
    }

    if (
      profileUpdates === null ||
      typeof profileUpdates !== 'object' ||
      Array.isArray(profileUpdates)
    ) {
      return res.json({ success: false, error: 'Invalid profileUpdates payload' }, 400);
    }

    const unknownFields = Object.keys(profileUpdates).filter(
      (key) => !allowedProfileFields.has(key),
    );
    if (unknownFields.length > 0) {
      return res.json(
        {
          success: false,
          error: `Unsupported profile fields: ${unknownFields.join(', ')}`,
        },
        400,
      );
    }

    if (newPassword && newPassword.length < 8) {
      return res.json({ success: false, error: 'كلمة المرور يجب ألا تقل عن 8 أحرف' }, 400);
    }

    const currentEmployeeNumber = targetProfile.employee_number;
    const oldEmail = `${String(currentEmployeeNumber).trim().toLowerCase()}@${technicalEmailDomain}`;
    const updateProfileData = {};
    let pendingNewEmail = null;

    if (newEmployeeNumber && newEmployeeNumber !== currentEmployeeNumber) {
      const trimmedNewNumber = String(newEmployeeNumber).trim();
      if (!trimmedNewNumber) {
        return res.json({ success: false, error: 'رقم الموظف لا يمكن أن يكون فارغاً' }, 400);
      }

      const existing = await databases.listDocuments(databaseId, profilesTable, [
        Query.equal('employee_number', trimmedNewNumber),
        Query.limit(1),
      ]);

      if (existing.total > 0 && existing.documents[0].$id !== profileId) {
        return res.json({ success: false, error: 'رقم الموظف مستخدم بالفعل' }, 400);
      }

      updateProfileData.employee_number = trimmedNewNumber;
      pendingNewEmail = `${trimmedNewNumber.toLowerCase()}@${technicalEmailDomain}`;
    }

    if (typeof mustChangePassword === 'boolean') {
      updateProfileData.must_change_password = mustChangePassword;
    }

    if (Object.prototype.hasOwnProperty.call(profileUpdates, 'fullName')) {
      const fullName = normalizeNullableText(profileUpdates.fullName);
      if (!fullName) {
        return res.json({ success: false, error: 'اسم الموظف لا يمكن أن يكون فارغاً' }, 400);
      }
      updateProfileData.full_name = fullName;
    }

    if (Object.prototype.hasOwnProperty.call(profileUpdates, 'departmentName')) {
      updateProfileData.department_name = normalizeNullableText(profileUpdates.departmentName);
    }
    if (Object.prototype.hasOwnProperty.call(profileUpdates, 'jobTitleId')) {
      updateProfileData.job_title_id = normalizeNullableText(profileUpdates.jobTitleId);
    }
    if (Object.prototype.hasOwnProperty.call(profileUpdates, 'jobTitleName')) {
      updateProfileData.job_title_name = normalizeNullableText(profileUpdates.jobTitleName);
    }

    if (Object.prototype.hasOwnProperty.call(profileUpdates, 'biometricEmployeeId')) {
      const biometricId = normalizeNullableText(profileUpdates.biometricEmployeeId);
      if (biometricId) {
        const existingBiometric = await databases.listDocuments(databaseId, profilesTable, [
          Query.equal('company_id', actorProfile.company_id),
          Query.equal('biometric_employee_id', biometricId),
          Query.limit(5),
        ]);
        if (existingBiometric.documents.some((doc) => doc.$id !== profileId)) {
          return res.json({ success: false, error: 'رقم البصمة مستخدم بالفعل لموظف آخر.' }, 400);
        }
      }
      updateProfileData.biometric_employee_id = biometricId;
    }

    if (Object.prototype.hasOwnProperty.call(profileUpdates, 'phone')) {
      const phone = normalizeNullableText(profileUpdates.phone);
      if (phone && !/^\+[0-9]{8,15}$/.test(phone)) {
        return res.json(
          { success: false, error: 'أدخل رقم الهاتف بصيغة دولية مثل +967770000000' },
          400,
        );
      }
      updateProfileData.phone = phone;
    }

    if (Object.prototype.hasOwnProperty.call(profileUpdates, 'baseSalary')) {
      const baseSalary = Number(profileUpdates.baseSalary);
      if (!Number.isFinite(baseSalary) || baseSalary < 0) {
        return res.json({ success: false, error: 'الراتب الأساسي غير صالح' }, 400);
      }
      updateProfileData.base_salary = baseSalary;
    }

    if (Object.prototype.hasOwnProperty.call(profileUpdates, 'monthlyBonus')) {
      const monthlyBonus = Number(profileUpdates.monthlyBonus);
      if (!Number.isFinite(monthlyBonus) || monthlyBonus < 0) {
        return res.json({ success: false, error: 'المكافأة الشهرية غير صالحة' }, 400);
      }
      updateProfileData.monthly_bonus = monthlyBonus;
    }

    if (Object.prototype.hasOwnProperty.call(profileUpdates, 'dailyWorkHours')) {
      const dailyWorkHours = Number(profileUpdates.dailyWorkHours);
      if (!Number.isFinite(dailyWorkHours) || dailyWorkHours <= 0 || dailyWorkHours > 24) {
        return res.json({ success: false, error: 'ساعات العمل اليومية يجب أن تكون أكبر من 0 ولا تتجاوز 24' }, 400);
      }
      updateProfileData.daily_work_hours = dailyWorkHours;
    }

    if (Object.prototype.hasOwnProperty.call(profileUpdates, 'active')) {
      if (typeof profileUpdates.active !== 'boolean') {
        return res.json({ success: false, error: 'Invalid active value' }, 400);
      }
      if (profileUpdates.active === false && targetProfile.role === 'hr_admin') {
        return res.json({ success: false, error: 'لا يمكن تعطيل حساب الموارد البشرية' }, 400);
      }
      updateProfileData.active = profileUpdates.active;
    }

    // All request validation is complete before any Auth or database mutation.
    let emailUpdated = false;
    if (pendingNewEmail) {
      try {
        await users.updateEmail(userId, pendingNewEmail);
        emailUpdated = true;
      } catch (e) {
        error(`Failed to update Auth email: ${e.message}`);
        return res.json({ success: false, error: 'فشل تحديث البريد الإلكتروني للمستخدم' }, 500);
      }
    }

    if (Object.keys(updateProfileData).length > 0) {
      try {
        await databases.updateDocument(databaseId, profilesTable, profileId, updateProfileData);
      } catch (e) {
        error(`Failed to update profile database: ${e.message}`);
        if (emailUpdated) {
          try {
            await users.updateEmail(userId, oldEmail);
            log('Rolled back Auth email to ' + oldEmail);
          } catch (rbError) {
            error(`CRITICAL: Failed to rollback email for user ${userId}. Data is out of sync.`);
          }
        }
        return res.json({ success: false, error: 'فشل تحديث بيانات الموظف' }, 500);
      }
    }

    if (newPassword) {
      try {
        await users.updatePassword(userId, newPassword);
      } catch (e) {
        error(`Failed to update Auth password: ${e.message}`);
        return res.json({ success: false, error: 'فشل تحديث كلمة المرور' }, 500);
      }
    }

    return res.json({ success: true, message: 'تم التحديث بنجاح' });
  } catch (e) {
    error(String(e?.message || e));
    return res.json({ success: false, error: String(e?.message || e) }, 500);
  }
};
