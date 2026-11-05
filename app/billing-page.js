'use strict';
(async()=>{
 const status=document.getElementById('status'),button=document.getElementById('pay');
 try{
  const client=window.supabase.createClient('https://qefpomgdknlcsavkritc.supabase.co','sb_publishable_qpOjNgQIyWPAwrvh73VSWA_vXIXvqQf');
  const {data:{session}}=await client.auth.getSession();
  if(!session){status.textContent='Connectez-vous à votre compte entrepreneur dans Projeko avant de continuer.';return;}
  const headers={Authorization:'Bearer '+session.access_token};
  const response=await fetch('/api/billing-status',{headers});
  const data=await response.json();
  if(!response.ok){status.textContent='Impossible de vérifier votre abonnement.';return;}
  const names={not_started:'Aucun abonnement',pending:'En attente',active:'Actif',trialing:'Essai gratuit',canceled:'Annulé',paused:'Suspendu',past_due:'Paiement en retard'};
  status.textContent='Statut : '+(names[data.subscription?.status]||'Inconnu');
  if(!data.billing_enabled){button.textContent='Paiement bientôt disponible';return;}
  if(['active','trialing'].includes(data.subscription?.status)){button.textContent='Abonnement actif';return;}
  button.disabled=false;button.textContent='Commencer mon essai gratuit';
  button.onclick=async()=>{
   button.disabled=true;button.textContent='Ouverture du paiement…';
   try{
    const result=await fetch('/api/create-subscription-checkout',{method:'POST',headers});
    const payload=await result.json();
    if(!result.ok||!payload.url)throw Error(payload.message||'Paiement indisponible');
    location.assign(payload.url);
   }catch(e){status.textContent=e.message;button.disabled=false;button.textContent='Réessayer';}
  };
 }catch(e){status.textContent='Le service est temporairement indisponible.';}
})();