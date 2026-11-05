const assert=require('node:assert/strict');
const plan=require('../app/billing-plan.js');
assert.equal(plan.currency,'CAD');
assert.equal(plan.monthlyAmountCents,2000);
assert.equal(plan.trialDays,30);
assert.equal(plan.clientMonthlyAmountCents,0);
assert.equal(plan.enabled,false);
console.log('Billing plan configuration OK');
