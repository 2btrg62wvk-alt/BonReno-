// Operates only the isolated demo backend, through the unchanged app controls.
(()=>{
const wait=ms=>new Promise(r=>setTimeout(r,ms));
const visible=e=>e&&e.getClientRects().length;
const find=s=>document.querySelector(s);
async function click(s){const e=find(s);if(!e)throw Error(s);e.scrollIntoView({block:'nearest',behavior:'smooth'});await wait(130);e.click();await wait(430);}
async function type(s,txt,delay=24){const e=find(s);e.focus();e.value='';for(const c of txt){e.value+=c;e.dispatchEvent(new Event('input',{bubbles:true}));await wait(delay);}e.blur();}
async function film(){
 await wait(1600);await click('#clientDashboard a[href="#newProject"]');await wait(1000);
 await click('#newProject [data-service="bathroom"]');await wait(650);
 await type('#rd80ProjectName','Rénovation de la salle de bain',35);
 await type('#rd62Description','Remplacer le bain par une douche, refaire la céramique et installer une nouvelle vanité.',14);await wait(850);
 await click('#projectDetails .rd52-next');await wait(700);
 await click('#rd62BudgetOptions a:nth-child(3)');await wait(700);
 await click('#rd62TimingOptions a:nth-child(2)');await wait(550);
 await type('#rd62City','Laval',70);await type('#rd62Postal','H7X 0A0',45);
 await click('#projectLocation .rd52-next');await wait(1900);
 await click('#rd72Publish');await wait(1700);
 window.filming.addOffers();await wait(650);
 await wait(1800);
 const screen=find('#clientProjectDetail');screen.scrollTo({top:260,behavior:'smooth'});window.scrollTo({top:260,behavior:'smooth'});await wait(1800);
 screen.scrollTo({top:570,behavior:'smooth'});window.scrollTo({top:570,behavior:'smooth'});await wait(1300);
 await click('#clientProjectDetail [data-quote="offer-0"]');window.scrollTo(0,0);await wait(2500);
 await click('#quoteDetail [data-accept]');window.scrollTo(0,0);await wait(2800);
 parent.postMessage('filming-done','*');
}
window.addEventListener('message',e=>{if(e.data==='filming-start')film().catch(e=>parent.postMessage({error:e.message},'*'));});
window.confirm=()=>true;
const ready=setInterval(()=>{if(find('#clientDashboard .pk-menu')){clearInterval(ready);const button=document.createElement('button');button.id='filming-start';button.textContent='Lancer le parcours';button.style='position:fixed;left:12px;top:12px;z-index:9999;padding:12px';button.onclick=()=>{button.remove();film().catch(e=>console.error('FILMING',e.message));};document.body.append(button);parent.postMessage('filming-ready','*');}},100);
})();
