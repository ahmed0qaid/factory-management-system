const fs = require('fs');

function loadEnv() {
  const env = {};
  if (!fs.existsSync('.env')) return env;
  for (const line of fs.readFileSync('.env', 'utf8').split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const index = trimmed.indexOf('=');
    if (index <= 0) continue;
    const key = trimmed.slice(0, index).trim();
    let value = trimmed.slice(index + 1).trim();
    if (
      (value.startsWith("'") && value.endsWith("'")) ||
      (value.startsWith('"') && value.endsWith('"'))
    ) {
      value = value.slice(1, -1);
    }
    env[key] = value;
  }
  return env;
}

function query(method, attribute, values) {
  return encodeURIComponent(JSON.stringify({ method, attribute, values }));
}

function limit(value) {
  return encodeURIComponent(JSON.stringify({ method: 'limit', values: [value] }));
}

async function request(url, { method = 'GET', projectId, apiKey, cookies, body } = {}) {
  const headers = {
    'x-appwrite-project': projectId,
    'content-type': 'application/json',
  };
  if (apiKey) headers['x-appwrite-key'] = apiKey;
  if (cookies && cookies.length) headers.cookie = cookies.join('; ');

  const res = await fetch(url, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });

  if (cookies) {
    const setCookie = res.headers.getSetCookie ? res.headers.getSetCookie() : [];
    for (const cookie of setCookie) cookies.push(cookie.split(';')[0]);
  }

  const text = await res.text();
  return { status: res.status, body: text ? JSON.parse(text) : {} };
}

async function findProfile(ctx, employeeNumber) {
  const url = `${ctx.endpoint}/databases/${ctx.databaseId}/collections/profiles/documents?queries[]=${query('equal', 'employee_number', [employeeNumber])}&queries[]=${limit(1)}`;
  const res = await request(url, ctx);
  if (res.status >= 400) throw new Error(`profile read failed (${res.status})`);
  return (res.body.documents || [])[0] || null;
}

async function createEmployee(ctx, data) {
  const existing = await findProfile(ctx, data.employeeNumber);
  if (existing) return { created: false, profile: existing };

  const execution = await request(`${ctx.endpoint}/functions/${ctx.functionId}/executions`, {
    method: 'POST',
    projectId: ctx.projectId,
    cookies: ctx.sessionCookies,
    body: {
      body: JSON.stringify(data),
      async: false,
      path: '/',
      method: 'POST',
    },
  });

  if (execution.status >= 400) {
    throw new Error(`function http ${execution.status}: ${execution.body.message || 'unknown'}`);
  }
  if (String(execution.body.status || '').toLowerCase() !== 'completed') {
    throw new Error(`function ${execution.body.status}: ${execution.body.responseBody || execution.body.errors || ''}`);
  }
  const response = execution.body.responseBody ? JSON.parse(execution.body.responseBody) : {};
  if (response.success !== true) throw new Error(`function response: ${response.error || 'unknown'}`);

  return { created: true, profile: await findProfile(ctx, data.employeeNumber) };
}

async function firstPendingTemporary(ctx) {
  const url = `${ctx.endpoint}/databases/${ctx.databaseId}/collections/temporary_biometric_employees/documents?queries[]=${query('equal', 'status', ['pending'])}&queries[]=${limit(1)}`;
  const res = await request(url, ctx);
  if (res.status >= 400) throw new Error(`temporary read failed (${res.status})`);
  return (res.body.documents || [])[0] || null;
}

async function approveTemporary(ctx, temp, profile) {
  const url = `${ctx.endpoint}/databases/${ctx.databaseId}/collections/temporary_biometric_employees/documents/${temp.$id}`;
  const res = await request(url, {
    method: 'PATCH',
    projectId: ctx.projectId,
    apiKey: ctx.apiKey,
    cookies: [],
    body: {
      data: {
        status: 'approved',
        linked_profile_id: profile.$id,
        approved_at: new Date().toISOString(),
      },
    },
  });
  if (res.status >= 400) throw new Error(`temporary approve failed (${res.status}): ${res.body.message || 'unknown'}`);
}

function printProfile(prefix, result) {
  const p = result.profile;
  console.log(`${prefix}_created: ${result.created}`);
  console.log(`${prefix}_employee_number: ${p.employee_number}`);
  console.log(`${prefix}_phone: ${p.phone || ''}`);
  console.log(`${prefix}_phone_present: ${Boolean(p.phone)}`);
  console.log(`${prefix}_biometric_employee_id: ${p.biometric_employee_id || ''}`);
}

async function main() {
  const env = loadEnv();
  const ctx = {
    endpoint: env.APPWRITE_ENDPOINT || 'https://cloud.appwrite.io/v1',
    projectId: env.APPWRITE_PROJECT_ID,
    databaseId: env.APPWRITE_DATABASE_ID || 'hr',
    apiKey: env.APPWRITE_API_KEY,
    functionId: env.APPWRITE_CREATE_EMPLOYEE_FUNCTION_ID || 'create_employee',
    sessionCookies: [],
  };
  if (!ctx.projectId || !ctx.apiKey) throw new Error('missing Appwrite configuration');

  const login = await request(`${ctx.endpoint}/account/sessions/email`, {
    method: 'POST',
    projectId: ctx.projectId,
    cookies: ctx.sessionCookies,
    body: { email: 'hr001@hr.local', password: env.HR001_PASSWORD || '12345678' },
  });
  if (login.status >= 400) throw new Error(`HR001 login failed (${login.status})`);

  const noPhone = await createEmployee(ctx, {
    employeeNumber: 'TEST_PHONE_OPTIONAL_NONE_001',
    fullName: 'Test Phone Optional None',
    temporaryPassword: '12345678',
    role: 'employee',
    baseSalary: 1000,
    monthlyBonus: 100,
    biometricEmployeeId: 'TEST_PHONE_OPTIONAL_NONE_BIO_001',
  });
  printProfile('no_phone', noPhone);

  const validPhone = await createEmployee(ctx, {
    employeeNumber: 'TEST_PHONE_OPTIONAL_VALID_001',
    fullName: 'Test Phone Optional Valid',
    temporaryPassword: '12345678',
    role: 'employee',
    phone: '+967770000000',
    baseSalary: 1000,
    monthlyBonus: 100,
    biometricEmployeeId: 'TEST_PHONE_OPTIONAL_VALID_BIO_001',
  });
  printProfile('valid_phone', validPhone);

  const temp = await firstPendingTemporary(ctx);
  if (!temp) {
    console.log('temporary_without_phone: skipped_no_pending');
    return;
  }

  const tempEmployeeNumber = `TEST_TEMP_NO_PHONE_${temp.biometric_employee_id}`;
  const tempResult = await createEmployee(ctx, {
    employeeNumber: tempEmployeeNumber,
    fullName: 'Test Temporary No Phone',
    temporaryPassword: '12345678',
    role: 'employee',
    baseSalary: 1000,
    monthlyBonus: 100,
    biometricEmployeeId: String(temp.biometric_employee_id),
  });
  await approveTemporary(ctx, temp, tempResult.profile);
  console.log('temporary_without_phone: success');
  console.log(`temporary_id: ${temp.$id}`);
  console.log(`temporary_profile_employee_number: ${tempResult.profile.employee_number}`);
  console.log(`temporary_profile_phone_present: ${Boolean(tempResult.profile.phone)}`);
}

main().catch((error) => {
  console.log(`error: ${error.message}`);
  process.exitCode = 1;
});
