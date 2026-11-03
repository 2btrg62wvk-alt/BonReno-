'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const {signatureValid,subscriptionStatus}=require('../api/_square-webhooks');
test('Square signature verified with exact URL and raw body',()=>{
 const notificationUrl='https://projeko.vercel.app/api/square-webhook',rawBody='{"type":"subscription.updated"}',key='test-key';
 const signature=crypto.createHmac('sha256',key).update(notificationUrl+rawBody).digest('base64');
 assert.equal(signatureValid({signature,notificationUrl,rawBody,key}),true);
 assert.equal(signatureValid({signature,notificationUrl,rawBody:rawBody+' ',key}),false);
 assert.equal(signatureValid({signature,notificationUrl:notificationUrl+'/',rawBody,key}),false);
 assert.equal(signatureValid({signature:'bad',notificationUrl,rawBody,key}),false);
});
test('Square statuses map conservatively',()=>{
 assert.equal(subscriptionStatus('ACTIVE'),'active');
 assert.equal(subscriptionStatus('CANCELED'),'canceled');
 assert.equal(subscriptionStatus('unknown'),'pending');
});
