/* Shared pricing configuration for Projeko web and installed PWA. */
(function(root){
'use strict';
const plan=Object.freeze({
  id:'projeko-contractor-monthly',
  currency:'CAD',
  monthlyAmountCents:2000,
  trialDays:30,
  clientMonthlyAmountCents:0,
  provider:'square',
  enabled:false // Do not enable until Square + webhook + access control pass sandbox tests.
});
if(typeof module!=='undefined'&&module.exports)module.exports=plan;
else root.ProjekoBillingPlan=plan;
})(typeof window!=='undefined'?window:globalThis);
