'use strict';
const assert=require('node:assert/strict');
const {test}=require('node:test');
const {config,request}=require('../api/_square-client');
test('sandbox is default and production must be explicit',()=>{
 assert.equal(config({SQUARE_ACCESS_TOKEN:'test'}).mode,'sandbox');
 assert.equal(config({SQUARE_ACCESS_TOKEN:'test',SQUARE_ENVIRONMENT:'production'}).base,'https://connect.squareup.com');
});
test('missing secret fails closed',()=>assert.throws(()=>config({}),/Missing/));
test('invalid environment fails closed',()=>assert.throws(()=>config({SQUARE_ENVIRONMENT:'bad',SQUARE_ACCESS_TOKEN:'test'}),/Invalid/));
test('auth stays in server request headers',async()=>{
 let called;
 await request('/v2/locations',{env:{SQUARE_ACCESS_TOKEN:'secret',SQUARE_ENVIRONMENT:'sandbox'},fetchImpl:async(url,opts)=>{called={url,opts};return {ok:true,json:async()=>({locations:[]})}}});
 assert.match(called.url,/squareupsandbox/);
 assert.equal(called.opts.headers.Authorization,'Bearer secret');
});
test('Square errors do not leak tokens',async()=>{
 await assert.rejects(request('/v2/locations',{env:{SQUARE_ACCESS_TOKEN:'secret'},fetchImpl:async()=>({ok:false,status:401,json:async()=>({errors:[{code:'UNAUTHORIZED'}]})})}),e=>!e.message.includes('secret')&&e.status===401);
});
