'use strict';
const {signatureValid,subscriptionStatus}=require('./_square-webhooks');
const {request}=require('./_square-client');
const SUPABASE_URL='https://qefpomgdknlcsavkritc.supabase.co';
const API_KEY=process.env.SUPABASE_SERVICE_ROLE_KEY;
async function raw(req){
 const chunks=[];for await(const chunk of req){chunks.push(Buffer.isBuffer(chunk)?chunk:Buffer.from(chunk));if(chunks.reduce((n,b)=>n+b.length,0)>1024*1024)throw new Error('payload_too_large');}
 return Buffer.concat(chunks).toString('utf8');
}
async function db(path,{method='GET',body}={}){
 if(!API_KEY)throw new Error('Missing server-side Supabase credential');
 const response=await fetch(SUPABASE_URL+'/rest/v1/'+path,{method,headers:{apikey:API_KEY,Authorization:'Bearer '+API_KEY,'Content-Type':'application/json',Prefer:'return=representation'},...(body?{body:JSON.stringify(body)}:{})});
 if(!response.ok)throw new Error('Database operation failed ('+response.status+')');
 return response.json().catch(()=>[]);
}
async function handler(req,res){
 res.setHeader('Cache-Control','no-store');
 if(req.method!=='POST')return res.status(405).end();
 if(process.env.SQUARE_ENVIRONMENT!=='sandbox'&&process.env.SQUARE_ENVIRONMENT!=='production')return res.status(503).end();
 const key=process.env.SQUARE_WEBHOOK_SIGNATURE_KEY,url=process.env.SQUARE_WEBHOOK_NOTIFICATION_URL;
 if(!key||!url||!API_KEY)return res.status(503).end();
 let body;try{body=await raw(req);}catch(e){return res.status(413).end();}
 const signature=req.headers['x-square-hmacsha256-signature'];
 if(!signatureValid({signature,notificationUrl:url,rawBody:body,key}))return res.status(401).end();
 let event;try{event=JSON.parse(body);}catch(e){return res.status(400).end();}
 if(!event?.event_id||!event?.type)return res.status(400).end();
 if(!event.type.startsWith('subscription.'))return res.status(200).json({received:true});
 try{
  const existing=await db('projeko_square_webhook_events?event_id=eq.'+encodeURIComponent(event.event_id)+'&select=event_id');
  if(existing.length)return res.status(200).json({received:true,duplicate:true});
  const subscriptionId=event.data?.id||event.data?.object?.subscription?.id;
  if(!subscriptionId)return res.status(400).end();
  // Fetch authoritative subscription state; do not trust unverified client payload.
  const square=await request('/v2/subscriptions/'+encodeURIComponent(subscriptionId));
  const subscription=square.subscription;
  if(!subscription||subscription.id!==subscriptionId)throw new Error('Subscription lookup mismatch');
  const rows=await db('projeko_subscriptions?square_subscription_id=eq.'+encodeURIComponent(subscriptionId)+'&select=user_id');
  if(rows.length!==1){
   // A subscription must first be bound to a verified contractor by the authenticated checkout flow.
   return res.status(409).json({error:'unlinked_subscription'});
  }
  await db('projeko_subscriptions?user_id=eq.'+encodeURIComponent(rows[0].user_id),{method:'PATCH',body:{
   status:subscriptionStatus(subscription.status),
   current_period_ends_at:subscription.charged_through_date||null,
   updated_at:new Date().toISOString()
  }});
  await db('projeko_square_webhook_events',{method:'POST',body:{event_id:event.event_id,event_type:event.type}});
  return res.status(200).json({received:true});
 }catch(e){return res.status(503).json({error:'processing_failed'});}
}
module.exports=handler;
module.exports.config={api:{bodyParser:false}};
