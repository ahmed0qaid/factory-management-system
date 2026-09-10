import { Client, Users, Databases, Query } from 'node-appwrite';

const technicalEmailDomain = 'hr.local';
const profilesTable = 'profiles';
const managementRoles = ['hr_admin'];

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

    // Verify actor
    const actorId = req.headers['x-appwrite-user-id'] || process.env.APPWRITE_FUNCTION_USER_ID;
    if (!actorId) return res.json({ success: false, error: 'Unauthorized' }, 401);

    const actorProfile = await databases.getDocument(databaseId, profilesTable, actorId);
    if (!managementRoles.includes(actorProfile.role)) {
      return res.json({ success: false, error: 'Forbidden. HR Admin access required.' }, 403);
    }

    const body = typeof req.body === 'string' ? JSON.parse(req.body || '{}') : (req.body || {});
    const { profileId, newEmployeeNumber, mustChangePassword } = body;
    const newPassword =
      body.newPassword && String(body.newPassword).trim()
        ? String(body.newPassword).trim()
        : null;

    if (!profileId) {
      return res.json({ success: false, error: 'Missing profileId' }, 400);
    }

    // Since profile ID is exactly the Auth user ID:
    const userId = profileId;

    // Fetch current profile to check existing data
    let targetProfile;
    try {
      targetProfile = await databases.getDocument(databaseId, profilesTable, profileId);
    } catch (e) {
      return res.json({ success: false, error: 'Employee profile not found' }, 404);
    }

    const currentEmployeeNumber = targetProfile.employee_number;
    let oldEmail = `${String(currentEmployeeNumber).trim().toLowerCase()}@${technicalEmailDomain}`;

    const updateProfileData = {};
    let emailUpdated = false;

    // Handle Employee Number Change
    if (newEmployeeNumber && newEmployeeNumber !== currentEmployeeNumber) {
      const trimmedNewNumber = String(newEmployeeNumber).trim();
      
      // Check if new number already used
      const existing = await databases.listDocuments(databaseId, profilesTable, [
        Query.equal('employee_number', trimmedNewNumber),
        Query.limit(1)
      ]);

      if (existing.total > 0 && existing.documents[0].$id !== profileId) {
        return res.json({ success: false, error: 'رقم الموظف مستخدم بالفعل' }, 400);
      }

      updateProfileData.employee_number = trimmedNewNumber;
      const newEmail = `${trimmedNewNumber.toLowerCase()}@${technicalEmailDomain}`;

      // Transaction-like approach for email change
      try {
        await users.updateEmail(userId, newEmail);
        emailUpdated = true;
      } catch (e) {
        error(`Failed to update Auth email: ${e.message}`);
        return res.json({ success: false, error: 'فشل تحديث البريد الإلكتروني للمستخدم' }, 500);
      }
    }

    if (typeof mustChangePassword === 'boolean') {
      updateProfileData.must_change_password = mustChangePassword;
    }

    // Apply Profile Database Updates if needed
    if (Object.keys(updateProfileData).length > 0) {
      try {
        await databases.updateDocument(databaseId, profilesTable, profileId, updateProfileData);
      } catch (e) {
        error(`Failed to update profile database: ${e.message}`);
        // Rollback Auth email if we updated it and profile update failed
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

    // Handle Password Change (independent from profile fields, done at the end)
    if (newPassword) {
      if (newPassword.length < 8) {
        return res.json({ success: false, error: 'كلمة المرور يجب ألا تقل عن 8 أحرف' }, 400);
      }
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
