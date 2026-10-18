#pragma once
// Runs only in a certificate-valid, same-origin CDP isolated world.
static constexpr const char *credential_observer=R"JS((()=>{
 if(globalThis.origin!==location.origin||location.protocol!=='https:')return false;if(globalThis.majorisCredentialObserver)return false;globalThis.majorisCredentialObserver=true;
 const visible=e=>e&&!e.disabled&&!e.readOnly&&e.getClientRects().length&&getComputedStyle(e).visibility!=='hidden';
 const passwords=root=>[...root.querySelectorAll('input[type=password]')].filter(e=>visible(e)&&!e.autocomplete.split(/\s+/).includes('one-time-code'));
 const username=(root,p)=>root.querySelector('input[autocomplete~=username],input[type=email],input[name=username],input[name=login]')||[...root.querySelectorAll('input[type=text],input:not([type])')].filter(e=>visible(e)&&(p.compareDocumentPosition(e)&Node.DOCUMENT_POSITION_PRECEDING)).pop();
 const known=new WeakSet();let candidate=null,lastActivation=0,addressAt=0;
 const send=value=>majorisCredentialSubmit(JSON.stringify(value));
 const active=()=>navigator.userActivation.isActive||(lastActivation>0&&performance.now()-lastActivation<5000);
 const capture=(root,form)=>{
  if(!active())return;if(form){const action=new URL(form.action||location.href,location.href);if(action.origin!==location.origin||action.protocol!=='https:')return;}
  const all=passwords(root),fresh=all.filter(e=>e.autocomplete.split(/\s+/).includes('new-password')||/new.*pass|pass.*new/i.test(e.name+' '+e.id));
  const p=fresh[0]||all.find(e=>!/confirm|verify/i.test(e.name+' '+e.id));
  if(!p){
   // Only an explicit, trusted username-first submission. Never sample arbitrary
   // request bodies or persist this intermediate value in page storage.
   const u=root.querySelector('input[autocomplete~=username],input[type=email],input[name=username],input[name=login]');
   if(visible(u)&&u.value&&u.value.length<=1024)send({kind:'username-step',username:u.value});return;
  }
  if(!p.value||p.value.length>4096)return;
  if(fresh.some(e=>e.value!==p.value)||all.some(e=>/confirm|verify/i.test(e.name+' '+e.id)&&e.value&&e.value!==p.value))return;
  const u=username(root,p),name=u?u.value:'';if(name.length>1024)return;
  if(candidate&&candidate.username===name&&candidate.password===p.value&&performance.now()-candidate.at<1000)return;
  candidate={id:crypto.randomUUID(),username:name,password:p.value,field:p,at:performance.now()};
  send({kind:'submit',id:candidate.id,username:name,password:p.value,action:form?new URL(form.action||location.href,location.href).href:''});
  const id=candidate.id;setTimeout(()=>{if(candidate?.id===id)candidate=null;},60000);
 };
 const scan=()=>{
  for(const p of passwords(document))if(!known.has(p)){known.add(p);send({kind:'form'});}
  if(!passwords(document).length)for(const u of document.querySelectorAll('input[autocomplete~=username]'))if(visible(u)&&!known.has(u)){known.add(u);send({kind:'form'});}
  if(candidate&&!visible(candidate.field)){send({kind:'outcome',id:candidate.id});candidate=null;}
 };
 let scanTimer=0;new MutationObserver(()=>{clearTimeout(scanTimer);scanTimer=setTimeout(scan,50);}).observe(document,{childList:true,subtree:true,attributes:true,attributeFilter:['class','style','hidden','type','autocomplete','disabled']});
 document.addEventListener('pointerdown',e=>{if(e.isTrusted)lastActivation=performance.now();},true);
 document.addEventListener('keydown',e=>{if(e.isTrusted)lastActivation=performance.now();},true);
 document.addEventListener('submit',e=>{if(e.isTrusted&&e.target instanceof HTMLFormElement)capture(e.target,e.target);},true);
 document.addEventListener('click',e=>{
  if(!e.isTrusted)return;const button=e.target.closest('button,input[type=submit],[role=button]');if(!button)return;
  const form=button.closest('form');if(form){capture(form,form);return;}
  if(/sign\s*in|log\s*in|login|continue|submit|save|update|change.*password/i.test(button.textContent+' '+button.getAttribute('aria-label')+' '+button.value))capture(button.closest('[role=dialog],section,main')||document,null);
 },true);
 document.addEventListener('focusin',e=>{
  if(!e.isTrusted||!active()||performance.now()-addressAt<15000)return;const node=e.target;if(!node.matches?.('input,textarea,select')||!visible(node)||passwords(node.closest('form')||document).length)return;
  const key=node.autocomplete?.split(/\s+/).pop()||'',semantic=(node.name+' '+node.id).toLowerCase();
  if(/^(name|given-name|family-name|street-address|address-line[123]|address-level[12]|postal-code|country|country-name|tel|email)$/.test(key)||/address|postal|zip|city|locality|country|telephone|phone/.test(semantic)){addressAt=performance.now();send({kind:'address'});}
 },true);
 scan();return passwords(document).length>0||[...document.querySelectorAll('input[autocomplete~=username]')].some(visible);
})())JS";
static constexpr const char *credential_fill=R"JS((()=>{
 const visible=e=>e&&!e.disabled&&!e.readOnly&&e.getClientRects().length&&getComputedStyle(e).visibility!=='hidden';
 const p=[...document.querySelectorAll('input[type=password]')].find(e=>visible(e)&&!e.autocomplete.split(/\s+/).includes('new-password')&&!/new.*pass|confirm|verify/i.test(e.name+' '+e.id));
 const root=p?.closest('form')||document;const u=root.querySelector('input[autocomplete~=username],input[type=email],input[name=username],input[name=login]')||(p?[...root.querySelectorAll('input[type=text],input:not([type])')].filter(e=>visible(e)&&(p.compareDocumentPosition(e)&Node.DOCUMENT_POSITION_PRECEDING)).pop():null);
 const put=(e,value)=>{if(!visible(e))return false;Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,'value').set.call(e,value);e.dispatchEvent(new Event('input',{bubbles:true}));e.dispatchEvent(new Event('change',{bubbles:true}));return true;};const user=put(u,v.username),pass=put(p,v.password);return user||pass?1:0;
})())JS";
static constexpr const char *address_fill=R"JS((()=>{
 const aliases={fullname:'name',name:'name',firstname:'given-name',givenname:'given-name',lastname:'family-name',surname:'family-name',street:'address-line1',streetaddress:'street-address',address:'address-line1',address1:'address-line1',address2:'address-line2',address3:'address-line3',city:'address-level2',town:'address-level2',locality:'address-level2',state:'address-level1',province:'address-level1',region:'address-level1',zipcode:'postal-code',postalcode:'postal-code',zip:'postal-code',countrycode:'country',country:'country',countryname:'country-name',phone:'tel',telephone:'tel',tel:'tel',email:'email',emailaddress:'email',organization:'organization',company:'organization'};
 const key=e=>{const tokens=(e.autocomplete||'').trim().split(/\s+/),last=tokens.pop();if(last&&last!=='on'&&last!=='off')return last;return aliases[(e.name||e.id||'').toLowerCase().replace(/[^a-z0-9]/g,'')]||'';};
 const anchor=document.activeElement,root=anchor?.closest('form')||document;let count=0;
 for(const e of root.querySelectorAll('input,textarea,select')){
  if(['password','hidden','file','checkbox','radio','button','submit'].includes(e.type)||e.disabled||e.readOnly||!e.getClientRects().length||getComputedStyle(e).visibility==='hidden')continue;const k=key(e);let value=fields[k];if(value==null||value==='')continue;
  if(e instanceof HTMLSelectElement){const option=[...e.options].find(o=>!o.disabled&&(o.value.toLowerCase()===String(value).toLowerCase()||o.text.trim().toLowerCase()===String(value).toLowerCase()));if(!option)continue;value=option.value;}
  const proto=e instanceof HTMLSelectElement?HTMLSelectElement.prototype:e instanceof HTMLTextAreaElement?HTMLTextAreaElement.prototype:HTMLInputElement.prototype;Object.getOwnPropertyDescriptor(proto,'value').set.call(e,value);e.dispatchEvent(new Event('input',{bubbles:true}));e.dispatchEvent(new Event('change',{bubbles:true}));count++;
 }return count;
})())JS";
