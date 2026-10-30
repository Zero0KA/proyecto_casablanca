'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {Pool}=require('../backend/node_modules/pg');
// Crea su propia BD y su propio rol temporal; nunca usa casablanca como destino.
async function withDatabase(task){
 if(process.env.CASABLANCA_PRUEBAS!=='SI')throw new Error('Prueba aislada desactivada. Define CASABLANCA_PRUEBAS=SI y una conexión PostgreSQL administrativa mediante PGHOST/PGPORT/PGUSER/PGPASSWORD.');
 const host=process.env.PGHOST||'127.0.0.1',port=Number(process.env.PGPORT||5432),admin=process.env.PGUSER||'postgres';
 const control=new Pool({host,port,user:admin,password:process.env.PGPASSWORD,database:'postgres',max:2,connectionTimeoutMillis:5000});
 const stamp=Date.now().toString()+'_'+crypto.randomBytes(3).toString('hex');
 const name='casablanca_pruebas_'+stamp,user='cb_prueba_'+stamp,password=crypto.randomBytes(32).toString('hex');
 let pool,created=false,roleCreated=false;
 try{
  await control.query(`CREATE DATABASE ${name}`);created=true;
  pool=new Pool({host,port,user:admin,password:process.env.PGPASSWORD,database:name,max:8,connectionTimeoutMillis:5000});
  await pool.query(fs.readFileSync(path.join(__dirname,'../bd/casablanca_instalador_actualizado.sql'),'utf8'));
  await control.query(`CREATE ROLE ${user} LOGIN PASSWORD '${password}' INHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS`);roleCreated=true;
  await control.query(`GRANT casablanca_api TO ${user}`);
  await task({pool,name,port,host,user,password});
 }finally{
  await pool?.end();
  try{if(created)await control.query(`DROP DATABASE ${name} WITH (FORCE)`);if(roleCreated)await control.query(`DROP ROLE ${user}`)}finally{await control.end()}
 }
}
module.exports={withDatabase};
