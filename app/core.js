(function(root){
'use strict';
const services={general:'Rénovation générale',plumbing:'Plomberie',electrical:'Électricité',roofing:'Toiture',kitchen:'Cuisine',bathroom:'Salle de bain',painting:'Peinture',flooring:'Plancher',hvac:'Chauffage & clim.',excavation:'Excavation',exterior:'Revêtement extérieur',landscaping:'Aménagement extérieur',other:'Autre projet'};
const inputServices={'svc-reno':'general','svc-plomb':'plumbing','svc-elec':'electrical','svc-roof':'roofing','svc-kitchen':'kitchen','svc-bath':'bathroom','svc-paint':'painting','svc-floor':'flooring','svc-hvac':'hvac','svc-exc':'excavation','svc-ext':'exterior','svc-land':'landscaping'};
const normalize=v=>String(v||'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().replace(/[^a-z0-9]/g,'');
function serviceKey(label){return Object.keys(services).find(k=>normalize(services[k])===normalize(label))||null;}
function distance(a,b){const rad=x=>x*Math.PI/180;return 6371*2*Math.asin(Math.sqrt(Math.min(1,Math.sin(rad(b.latitude-a.latitude)/2)**2+Math.cos(rad(a.latitude))*Math.cos(rad(b.latitude))*Math.sin(rad(b.longitude-a.longitude)/2)**2)));}
function matches(profile,project){return profile?.role==='contractor'&&project.status==='open'&&(profile.services.includes('general')||profile.services.includes(project.service))&&distance(profile,project)<=profile.radius_km;}
const api={services,inputServices,normalize,serviceKey,distance,matches};
if(typeof module!=='undefined')module.exports=api;else root.RDCore=api;
})(typeof window!=='undefined'?window:globalThis);
