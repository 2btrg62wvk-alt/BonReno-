'use strict';
// Server-only Square API client. Never import this file in browser code.
const BASES={sandbox:'https://connect.squareupsandbox.com',production:'https://connect.squareup.com'};
function config(env=process.env){
  const mode=env.SQUARE_ENVIRONMENT||'sandbox';
  if(!BASES[mode])throw new Error('Invalid SQUARE_ENVIRONMENT');
  if(!env.SQUARE_ACCESS_TOKEN)throw new Error('Missing SQUARE_ACCESS_TOKEN');
  return {mode,base:BASES[mode],token:env.SQUARE_ACCESS_TOKEN,version:env.SQUARE_API_VERSION||'2026-09-16'};
}
async function request(path,{method='GET',body,env=process.env,fetchImpl=fetch}={}){
  const c=config(env);
  if(!path.startsWith('/')||path.startsWith('//'))throw new Error('Invalid Square API path');
  const response=await fetchImpl(c.base+path,{method,headers:{
    'Square-Version':c.version,'Authorization':'Bearer '+c.token,
    'Content-Type':'application/json','Accept':'application/json'
  },...(body===undefined?{}:{body:JSON.stringify(body)})});
  const data=await response.json().catch(()=>({}));
  if(!response.ok){const err=new Error('Square API request failed ('+response.status+')');err.status=response.status;err.details=data.errors||[];throw err;}
  return data;
}
module.exports={config,request};
