// Original synthetic media generated locally. No third-party media or codec
// implementation is distributed by this fixture.
let running=false;
begin.onclick=async()=>{
 if(running)return;running=true;document.title='media-started';
 try{window.mediaReport=await runMediaFixtures();}catch(e){window.mediaReport={error:String(e)};}
 document.title='media-complete';
};
async function runMediaFixtures(){
 const canvas=document.createElement('canvas');canvas.width=160;canvas.height=90;document.body.append(canvas);
 let tick=0;const draw=setInterval(()=>{const c=canvas.getContext('2d');c.fillStyle=tick++%2?'red':'blue';c.fillRect(0,0,160,90);},30);
 const context=new AudioContext();await context.resume();const oscillator=context.createOscillator(),gain=context.createGain(),destination=context.createMediaStreamDestination();gain.gain.value=.02;oscillator.connect(gain).connect(destination);oscillator.start();
 async function record(stream,mime){if(!MediaRecorder.isTypeSupported(mime))throw Error('Required fixture encoder unavailable: '+mime);return new Promise((resolve,reject)=>{const parts=[],recorder=new MediaRecorder(stream,{mimeType:mime});recorder.ondataavailable=e=>parts.push(e.data);recorder.onerror=reject;recorder.onstop=()=>resolve(new Blob(parts,{type:mime}));recorder.start(100);setTimeout(()=>recorder.stop(),700);});}
 async function play(blob,audio=false){
  const media=document.createElement(audio?'audio':'video');media.muted=!audio;media.playsInline=true;document.body.append(media);const url=URL.createObjectURL(blob);media.src=url;
  let analyser,rms=0;if(audio){analyser=context.createAnalyser();context.createMediaElementSource(media).connect(analyser).connect(context.destination);}
  try{return await new Promise((resolve,reject)=>{const timer=setTimeout(()=>reject(Error('Playback timeout')),5000);const sample=setInterval(()=>{if(analyser){const bytes=new Float32Array(analyser.fftSize);analyser.getFloatTimeDomainData(bytes);rms=Math.max(rms,Math.sqrt(bytes.reduce((s,v)=>s+v*v,0)/bytes.length));}},20);const finish=()=>{clearTimeout(timer);clearInterval(sample);};media.onerror=()=>{finish();reject(Error('Media pipeline error '+media.error?.code));};media.onended=()=>{finish();resolve(audio?media.currentTime>.3&&rms>.001:media.currentTime>.3&&media.videoWidth===160&&media.getVideoPlaybackQuality().totalVideoFrames>0);};media.play().catch(e=>{finish();reject(e);});});}
  finally{media.pause();media.remove();URL.revokeObjectURL(url);}
 }
 try{
  const stream=canvas.captureStream(15),vp8=await play(await record(stream,'video/webm;codecs=vp8')),vp9=await play(await record(stream,'video/webm;codecs=vp9')),opus=await play(await record(destination.stream,'audio/webm;codecs=opus'),true);stream.getTracks().forEach(t=>t.stop());
  const probe=document.createElement('video'),h264=probe.canPlayType('video/mp4;codecs="avc1.42E01E"'),aac=probe.canPlayType('audio/mp4;codecs="mp4a.40.2"');
  async function supplied(name,audio=false){const response=await fetch('/licensed-fixtures/'+name);if(!response.ok)throw Error('Qualified runtime requires local licensed playback asset '+name);return play(await response.blob(),audio);}
  const h264Playback=h264?await supplied('h264.mp4'):'blocked: decoder unavailable',aacPlayback=aac?await supplied('aac.m4a',true):'blocked: decoder unavailable',mp4Playback=h264&&aac?await supplied('h264-aac.mp4'):'blocked: decoder unavailable';
  return {vp8,vp9,opus,webm:vp8&&vp9,h264,aac,h264Playback,aacPlayback,mp4Playback,physicalOutput:'unverified',hardwareDecode:'unverified'};
 }finally{clearInterval(draw);oscillator.stop();await context.close();canvas.remove();}
}
