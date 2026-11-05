'use strict';
const {request}=require('./_square-client');
const crypto=require('node:crypto');
const SUPABASE_URL='https://qefpomgdknlcsavkritc.supabase.co';
const KEY='sb_publishable_qpOjNgQIyWPAwrvh73VSWA_vXIXvqQf';
module.exports=async(req,res)=>{
 res.setHeader('Cache-Control','no-store');
 if(req.method!=='POST'){res.setHeader('Allow','POST');return res.status(405).json({error:'method_not_allowed'});}
 if(process.env.SQUARE_BILLING_ENABLED!=='true')return res.status(503).json({error:'billing_not_enabled',message:'Les paiements sont temporairement indisponibles.'});
 if(process.env.SQUARE_ENVIRONMENT!=='sandbox')return res.status(503).json({error:'sandbox_only'});
 const auth=req.headers.authorization||'';
 if(!/^Bearer [A-Za-z0-9._~-]+$/.test(auth))return res.status(401).json({error:'authentication_required'});
 const token=auth.slice(7),headers={apikey:KEY,Authorization:'Bearer '+token};
 try{
  const u=await fetch(SUPABASE_URL+'/auth/v1/user',{headers});
  if(!u.ok)return res.status(401).json({error:'invalid_session'});
  const user=await u.json();
  const p=await fetch(SUPABASE_URL+'/rest/v1/rd_profiles?id=eq.'+encodeURIComponent(user.id)+'&select=role',{headers});
  if(!p.ok)return res.status(503).json({error:'profile_unavailable'});
  const profiles=await p.json();
  if(profiles?.[0]?.role!=='contractor')return res.status(403).json({error:'contractor_only'});
  const plan=process.env.SQUARE_PLAN_VARIATION_ID,location=process.env.SQUARE_LOCATION_ID;
  if(!plan||!location)return res.status(503).json({error:'square_configuration_incomplete'});
  const variation=await request('/v2/catalog/object/'+encodeURIComponent(plan));
  const phases=variation.object?.subscription_plan_variation_data?.phases;
  const first=phases?.[0],last=phases?.[phases.length-1];
  if(variation.object?.type!=='SUBSCRIPTION_PLAN_VARIATION'||!Array.isArray(phases)||phases.length!==2||
   first.cadence!=='DAILY'||first.periods!==30||first.pricing?.price_money?.amount!==0||
   last.cadence!=='MONTHLY'||last.pricing?.price_money?.amount!==2000||
   last.pricing?.price_money?.currency!=='CAD')
   return res.status(503).json({error:'plan_validation_failed'});
  const checkout=await request('/v2/online-checkout/payment-links',{method:'POST',body:{
   idempotency_key:crypto.randomUUID(),
   quick_pay:{location_id:location,name:'Projeko Entrepreneur',price_money:{amount:0,currency:'CAD'}},
   checkout_options:{subscription_plan_id:plan,redirect_url:'https://projeko.vercel.app/#contractorFeed'},
   description:'Essai gratuit de 30 jours, puis 20 $ CA par mois.'
  }});
  const url=checkout.payment_link?.url;
  if(!url||!/^https:\/\/(?:square\.link|checkout\.square\.site)\//.test(url))return res.status(502).json({error:'invalid_checkout_url'});
  return res.status(200).json({url});
 }catch(e){return res.status(503).json({error:'service_unavailable'});}
};
