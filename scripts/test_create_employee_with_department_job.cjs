const fs = require('fs');

const employeeNumber = 'TEST_DEPT_JOB_002';
const fullName = '\u0645\u0648\u0638\u0641 \u0627\u062e\u062a\u0628\u0627\u0631 \u0642\u0633\u0645 \u0648\u0645\u0633\u0645\u0649';
const temporaryPassword = '12345678';
const role = 'employee';
const departmentName = '\u0627\u0644\u0645\u0648\u0627\u0631\u062f \u0627\u0644\u0628\u0634\u0631\u064a\u0629';
const jobTitleName = '\u0645\u062d\u0627\u0633\u0628';
const biometricEmployeeId = 'TEST_DEPT_JOB_BIO_002';
const phone = '+964770000002';

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

function queryEqual(attribute, value) {
  return encodeURIComponent(JSON.stringify({
    method: 'equal',
    attribute,
    values: [value],
  }));
}

function queryLimit(value) {
  return encodeURIComponent(JSON.stringify({
    method: 'limit',
    values: [value],
  }));
}

async function request(url, { method = 'GET', projectId, apiKey, cookies, body } = {}) {
  const headers = {
    'x-appwrite-project': projectId,
    'content-type': 'application/json',
  };
  if (apiKey) headers['x-appwrite-key'] = apiKey;
  if (cookies.length) headers.cookie = cookies.join('; ');

  const res = await fetch(url, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });

  const setCookie = res.headers.getSetCookie ? res.headers.getSetCookie() : [];
  for (const cookie of setCookie) {
    cookies.push(cookie.split(';')[0]);
  }

  const text = await res.text();
  const parsed = text ? JSON.parse(text) : {};
  return { status: res.status, body: parsed };
}

async function findProfile(endpoint, databaseId, projectId, apiKey) {
  const cookies = [];
  const url = `${endpoint}/databases/${databaseId}/collections/profiles/documents?queries[]=${queryEqual('employee_number', employeeNumber)}&queries[]=${queryLimit(1)}`;
  const res = await request(url, { projectId, apiKey, cookies });
  if (res.status >= 400) throw new Error(`profile read failed (${res.status})`);
  const docs = res.body.documents || [];
  return docs[0] || null;
}

function printProfile(profile, created) {
  if (!profile) {
    console.log('created: false');
    console.log('found_in_profiles: false');
    return;
  }
  console.log(`created: ${created}`);
  console.log('found_in_profiles: true');
  console.log(`employee_number: ${profile.employee_number}`);
  console.log(`full_name: ${profile.full_name}`);
  console.log(`department_name: ${profile.department_name}`);
  console.log(`job_title_name: ${profile.job_title_name}`);
  console.log(`biometric_employee_id: ${profile.biometric_employee_id}`);
  console.log(`department_name_ok: ${profile.department_name === departmentName}`);
  console.log(`job_title_name_ok: ${profile.job_title_name === jobTitleName}`);
  console.log(`biometric_employee_id_ok: ${profile.biometric_employee_id === biometricEmployeeId}`);
  console.log(`official_list_title: ${profile.employee_number} - ${profile.job_title_name || '-'}`);
}

async function main() {
  const env = loadEnv();
  const endpoint = env.APPWRITE_ENDPOINT || 'https://cloud.appwrite.io/v1';
  const projectId = env.APPWRITE_PROJECT_ID;
  const databaseId = env.APPWRITE_DATABASE_ID || 'hr';
  const apiKey = env.APPWRITE_API_KEY;
  const functionId = env.APPWRITE_CREATE_EMPLOYEE_FUNCTION_ID || 'create_employee';
  const hrPassword = env.HR001_PASSWORD || '12345678';

  if (!projectId || !apiKey) throw new Error('missing Appwrite project/API configuration');

  const existing = await findProfile(endpoint, databaseId, projectId, apiKey);
  if (existing) {
    printProfile(existing, false);
    return;
  }

  const cookies = [];
  const login = await request(`${endpoint}/account/sessions/email`, {
    method: 'POST',
    projectId,
    cookies,
    body: { email: 'hr001@hr.local', password: hrPassword },
  });
  if (login.status >= 400) throw new Error(`HR001 login failed (${login.status})`);

  const execution = await request(`${endpoint}/functions/${functionId}/executions`, {
    method: 'POST',
    projectId,
    cookies,
    body: {
      body: JSON.stringify({
        employeeNumber,
        fullName,
        temporaryPassword,
        role,
        departmentName,
        jobTitleName,
        biometricEmployeeId,
        phone,
        baseSalary: 1000,
        monthlyBonus: 100,
      }),
      async: false,
      path: '/',
      method: 'POST',
    },
  });

  if (execution.status >= 400) {
    throw new Error(`function execution failed (${execution.status}): ${execution.body.message || 'unknown'}`);
  }
  if (String(execution.body.status || '').toLowerCase() !== 'completed') {
    const details = [
      `function status: ${execution.body.status || 'unknown'}`,
      execution.body.errors ? `errors: ${execution.body.errors}` : '',
      execution.body.responseBody ? `responseBody: ${execution.body.responseBody}` : '',
    ].filter(Boolean).join(' | ');
    throw new Error(details);
  }

  const response = execution.body.responseBody ? JSON.parse(execution.body.responseBody) : {};
  if (response.success !== true) {
    throw new Error(`function response: ${response.error || 'unknown'}`);
  }

  const profile = await findProfile(endpoint, databaseId, projectId, apiKey);
  printProfile(profile, true);
}

main().catch((error) => {
  console.log('created: false');
  console.log(`error: ${error.message}`);
  process.exitCode = 1;
});
