// Local reproducible engine probes. No provider accounts or network services.
async function verifyCompatibility() {
 const wasm=await WebAssembly.instantiate(new Uint8Array([0,97,115,109,1,0,0,0,1,5,1,96,0,1,127,3,2,1,0,7,10,1,6,97,110,115,119,101,114,0,0,10,6,1,4,0,65,42,11]));
 const websocket=await new Promise((resolve,reject)=>{const ws=new WebSocket(location.origin.replace('https:','wss:')+'/fixture-socket');const timer=setTimeout(()=>{ws.close();reject(Error('WebSocket timeout'));},5000);ws.onopen=()=>ws.send('majoris-fixture');ws.onmessage=e=>{clearTimeout(timer);resolve(e.data==='majoris-fixture');ws.close();};ws.onerror=reject;});
 const rtc=await new Promise(async(resolve,reject)=>{
  const a=new RTCPeerConnection({iceServers:[]}),b=new RTCPeerConnection({iceServers:[]});
  const finish=result=>{clearTimeout(timer);a.close();b.close();resolve(result);};const timer=setTimeout(()=>finish(false),8000);
  const gathered=p=>p.iceGatheringState==='complete'?Promise.resolve():new Promise(r=>p.addEventListener('icegatheringstatechange',()=>{if(p.iceGatheringState==='complete')r();}));
  b.ondatachannel=e=>{e.channel.onmessage=m=>finish(m.data==='local-channel');};const channel=a.createDataChannel('fixture');channel.onopen=()=>channel.send('local-channel');
  try{await a.setLocalDescription(await a.createOffer());await gathered(a);await b.setRemoteDescription(a.localDescription);await b.setLocalDescription(await b.createAnswer());await gathered(b);await a.setRemoteDescription(b.localDescription);}catch(e){a.close();b.close();clearTimeout(timer);reject(e);}
 });
 let fileDenied=false;try{await fetch('file:///etc/passwd');}catch(e){fileDenied=true;}
 const frame=document.createElement('iframe');frame.src=location.href.replace('localhost','127.0.0.1');frame.hidden=true;
 const sop=await new Promise(resolve=>{frame.onload=()=>{let denied=false;try{denied=frame.contentWindow.document===null;}catch(e){denied=true;}frame.remove();resolve(denied);};document.body.append(frame);});
 const editable=document.createElement('div');editable.contentEditable='true';editable.textContent='日本語😀';document.body.append(editable);const edit=editable.isContentEditable&&editable.textContent==='日本語😀';editable.remove();
 const media=document.createElement('video');const codecs={};for(const [key,type] of Object.entries({vp8:'video/webm; codecs="vp8"',vp9:'video/webm; codecs="vp9"',h264:'video/mp4; codecs="avc1.42E01E"',opus:'audio/webm; codecs="opus"',aac:'audio/mp4; codecs="mp4a.40.2"'}))codecs[key]=media.canPlayType(type);
 let widevine=false;try{await navigator.requestMediaKeySystemAccess('com.widevine.alpha',[{initDataTypes:['cenc'],videoCapabilities:[{contentType:'video/mp4; codecs="avc1.42E01E"'}]}]);widevine=true;}catch(e){}
 return {wasm:wasm.instance.exports.answer()===42,websocket,rtc,fileDenied,sop,edit,nativeHidden:typeof window.majorisCredentialSubmit==='undefined',codecs,widevine};
}
