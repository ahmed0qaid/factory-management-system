const https = require('https');

const endpoint = 'https://fra.cloud.appwrite.io/v1';
const projectId = '6a6a49d1000884049205';
const apiKey = process.env.APPWRITE_API_KEY;

const options = {
  hostname: 'fra.cloud.appwrite.io',
  path: '/v1/functions',
  method: 'GET',
  headers: {
    'X-Appwrite-Project': projectId,
    'X-Appwrite-Key': apiKey,
    'Content-Type': 'application/json'
  }
};

const req = https.request(options, (res) => {
  let data = '';
  res.on('data', (chunk) => {
    data += chunk;
  });
  res.on('end', () => {
    const json = JSON.parse(data);
    if (json.functions) {
      console.log('Functions:');
      json.functions.forEach(f => {
        console.log(`- Name: ${f.name}, ID: ${f.$id}, Runtime: ${f.runtime}`);
      });
    } else {
      console.log(json);
    }
  });
});

req.on('error', (e) => {
  console.error(e);
});

req.end();
