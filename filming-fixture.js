// Isolated filming fixture. The production app and its interface are unchanged.
(() => {
const user={id:'demo-client',email:'demo@example.invalid'};
const names=['Atelier Nord','Maison & Matière','Équipe Horizon','Rénovation Lignée'];
const tables={rd_profiles:[{id:user.id,role:'client',display_name:'Alex Martin',company_name:'',city:'Laval',latitude:45.57,longitude:-73.69,services:[],radius_km:50,rbq:''},...names.map((name,i)=>({id:'pro-'+i,role:'contractor',display_name:name,company_name:name,city:'Laval',latitude:45.57,longitude:-73.69,services:['bathroom'],radius_km:50,rbq:''}))],rd_projects:[],rd_quotes:[],rd_messages:[],rd_project_photos:[],rd_account_details:[],rd_business_pages:[],rd_portfolio:[]};
let authCallback;
class Query{
constructor(table){this.table=table;this.filters=[];this.mode='select';}
select(){return this;} eq(k,v){this.filters.push(r=>r[k]===v);return this;} in(k,v){this.filters.push(r=>v.includes(r[k]));return this;}
order(){return this;} limit(n){this.max=n;return this;} maybeSingle(){this.one=true;return this;} single(){this.one=true;return this;}
insert(rows){this.mode='insert';this.rows=Array.isArray(rows)?rows:[rows];return this;} upsert(row){this.mode='upsert';this.row=row;return this;} update(row){this.mode='update';this.row=row;return this;}
then(resolve,reject){return Promise.resolve().then(()=>{let rows=tables[this.table]||[];
if(this.mode==='insert'){rows=this.rows.map(r=>({...r,id:r.id||crypto.randomUUID(),created_at:new Date().toISOString(),...(!r.status&&['rd_projects','rd_quotes'].includes(this.table)?{status:this.table==='rd_projects'?'open':'pending'}:{})}));(tables[this.table]||=[]).push(...rows);}
else if(this.mode==='update'){rows=rows.filter(r=>this.filters.every(f=>f(r)));rows.forEach(r=>Object.assign(r,this.row));}
else if(this.mode==='upsert'){let row=rows.find(r=>r.id===this.row.id);if(row)Object.assign(row,this.row);else{row={...this.row};rows.push(row);}rows=[row];}
else rows=rows.filter(r=>this.filters.every(f=>f(r)));
if(this.max)rows=rows.slice(0,this.max);return {data:this.one?rows[0]||null:rows,error:null};}).then(resolve,reject);}
}
const db={from:t=>new Query(t),auth:{getSession:async()=>({data:{session:{user}},error:null}),onAuthStateChange:fn=>(authCallback=fn,{data:{subscription:{unsubscribe(){}}}})},storage:{from:()=>({createSignedUrls:async()=>({data:[]})})},rpc:async(name,args)=>{if(name==='rd_accept_quote'){let q=tables.rd_quotes.find(q=>q.id===args.quote);let p=tables.rd_projects.find(p=>p.id===q.project_id);tables.rd_quotes.filter(q=>q.project_id===p.id).forEach(row=>row.status=row.id===q.id?'accepted':'declined');p.status='accepted';p.accepted_quote_id=q.id;return {data:p.id,error:null};}return {data:null,error:null};}};
window.supabase={createClient:()=>db};
window.filming={tables,addOffers(){const p=tables.rd_projects[0];[18750,21400,19900,22800].forEach((amount,i)=>tables.rd_quotes.push({id:'offer-'+i,project_id:p.id,contractor_id:'pro-'+i,amount,status:'pending',duration:['3 semaines','4 semaines','3 semaines','4 semaines'][i],start_date:'2026-11-16',message:'Douche, nouvelle céramique et installation de la vanité. Main-d’œuvre et matériaux inclus. Taxes en sus.',created_at:new Date().toISOString()}));window.dispatchEvent(new Event('focus'));}};
})();
