'use strict';
// Read-only authenticated subscription status endpoint. No payment or privileged write.
const SUPABASE_URL='https://qefpomgdknlcsavkritc.supabase.co';
const PUBLISHABLE_KEY='sb_publishable_qpOjNgQIyWPAwrvh73VSWA_vXIXvqQf';
async function handler(req,res){
 res.setHeader('Cache-Control','no-store');
 if(req.method!=='GET'){res.setHeader('Allow','GET');return res.status(405).json({error:'method_not_allowed'});}
 const auth=req.headers.authorization||'';
 if(!/^Bearer [A-Za-z0-9._~-]+$/.test(auth))return res.status(401).json({error:'authentication_required'});
 const token=auth.slice(7);
 try{
  const headers={apikey:PUBLISHABLE_KEY,Authorization:'Bearer '+token};
  const userResponse=await fetch(SUPABASE_URL+'/auth/v1/user',{headers});
  if(!userResponse.ok)return res.status(401).json({error:'invalid_session'});
  const user=await userResponse.json();
  if(!user?.id)return res.status(401).json({error:'invalid_session'});
  const profileResponse=await fetch(SUPABASE_URL+'/rest/v1/rd_profiles?id=eq.'+encodeURIComponent(user.id)+'&select=role',{headers});
  if(!profileResponse.ok)return res.status(503).json({error:'profile_unavailable'});
  const profiles=await profileResponse.json();
  if(profiles?.[0]?.role!=='contractor')return res.status(403).json({error:'contractor_only'});
  const subscriptionResponse=await fetch(SUPABASE_URL+'/rest/v1/projeko_subscriptions?user_id=eq.'+encodeURIComponent(user.id)+'&select=status,trial_ends_at,current_period_ends_at,updated_at',{headers});
  if(!subscriptionResponse.ok)return res.status(503).json({error:'subscription_unavailable'});
  const rows=await subscriptionResponse.json();
  return res.status(200).json({billing_enabled:false,plan:{currency:'CAD',monthly_amount_cents:2000,trial_days:30},subscription:rows?.[0]||{status:'not_started'}});
 }catch(e){return res.status(503).json({error:'service_unavailable'});}
}
module.exports=handler;
