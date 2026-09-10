import { Client, Functions, ID } from 'node-appwrite';
import { InputFile } from 'node-appwrite/file';
import * as tar from 'tar';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function deploy() {
  const client = new Client()
    .setEndpoint(process.env.APPWRITE_ENDPOINT)
    .setProject(process.env.APPWRITE_PROJECT_ID)
    .setKey(process.env.APPWRITE_API_KEY);

  const functions = new Functions(client);

  const functionId = 'create_employee';
  
  // 1. Check if function exists, create if not
  try {
    await functions.get(functionId);
    console.log(`Function ${functionId} already exists.`);
  } catch (e) {
    if (e.code === 404) {
      console.log(`Creating function ${functionId}...`);
      await functions.create({
        functionId,
        name: 'Create Employee',
        runtime: 'node-18.0',
        execute: ['any'],
        events: [],
        schedule: '',
        timeout: 15,
        enabled: true,
        logging: true
      });
      console.log(`Function ${functionId} created.`);
    } else {
      throw e;
    }
  }

  // Set variables
  try {
    const variables = await functions.listVariables(functionId);
    const existingKeys = variables.variables.map(v => v.key);
    
    const requiredVars = {
      APPWRITE_ENDPOINT: process.env.APPWRITE_ENDPOINT,
      APPWRITE_PROJECT_ID: process.env.APPWRITE_PROJECT_ID,
      APPWRITE_DATABASE_ID: process.env.APPWRITE_DATABASE_ID || 'hr',
      APPWRITE_API_KEY: process.env.APPWRITE_API_KEY,
    };

    for (const [key, value] of Object.entries(requiredVars)) {
      if (!existingKeys.includes(key)) {
        await functions.createVariable({ functionId, key, value });
        console.log(`Variable ${key} created.`);
      } else {
        const variable = variables.variables.find(v => v.key === key);
        await functions.updateVariable({ functionId, variableId: variable.$id, key, value });
        console.log(`Variable ${key} updated.`);
      }
    }
  } catch (e) {
    console.error('Error setting variables:', e.message);
  }

  // 2. Pack the folder
  const functionFolder = path.join(__dirname, 'appwrite', 'functions', 'create-employee');
  const tarPath = path.join(__dirname, 'code.tar.gz');
  
  console.log('Packing folder...', functionFolder);
  await tar.c(
    {
      gzip: true,
      file: tarPath,
      cwd: functionFolder,
    },
    ['.']
  );
  console.log('Folder packed to', tarPath);

  // 3. Create Deployment
  console.log('Creating deployment...');
  const deployment = await functions.createDeployment(
    functionId,
    InputFile.fromPath(tarPath, 'code.tar.gz'),
    true, // activate
    'index.js',
    'npm install'
  );
  
  console.log('Deployment created:', deployment.$id);
}

deploy().catch(console.error);
