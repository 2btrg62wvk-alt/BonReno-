'use strict';
const crypto=require('node:crypto');
function signatureValid({signature,notificationUrl,rawBody,key}){
 if(!signature||!notificationUrl||!key||typeof rawBody!=='string')return false;
 const expected=crypto.createHmac('sha256',key).update(notificationUrl+rawBody).digest('base64');
 const a=Buffer.from(signature,'utf8'),b=Buffer.from(expected,'utf8');
 return a.length===b.length&&crypto.timingSafeEqual(a,b);
}
function subscriptionStatus(squareStatus){
 const map={ACTIVE:'active',PENDING:'pending',CANCELED:'canceled',PAUSED:'paused',DEACTIVATED:'canceled'};
 return map[String(squareStatus||'').toUpperCase()]||'pending';
}
module.exports={signatureValid,subscriptionStatus};
