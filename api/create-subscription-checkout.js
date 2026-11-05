'use strict';
const {request}=require('./_square-client');
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
  // Do not create a Square checkout without a verified subscription-plan checkout contract.
  // Creating a one-time payment link here would charge without enrolling the customer.
  return res.status(501).json({error:'subscription_checkout_not_configured',message:'Le paiement récurrent est en préparation.'});
 }catch(e){return res.status(503).json({error:'service_unavailable'});}
};
