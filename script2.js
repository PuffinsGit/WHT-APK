
function escapeHTML(v){return String(v).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]))}
function preprocessPhoto(file,mode=0){return new Promise((resolve,reject)=>{const img=new Image();img.onload=()=>{const max=2400,scale=Math.min(2.5,max/Math.max(img.naturalWidth,img.naturalHeight));const c=document.createElement('canvas');c.width=Math.round(img.naturalWidth*scale);c.height=Math.round(img.naturalHeight*scale);const x=c.getContext('2d');x.drawImage(img,0,0,c.width,c.height);let d=x.getImageData(0,0,c.width,c.height),a=d.data;if(mode===1||mode===2){for(let i=0;i<a.length;i+=4){const g=0.299*a[i]+0.587*a[i+1]+0.114*a[i+2];let v=g;if(mode===2)v=g>150?255:0;a[i]=a[i+1]=a[i+2]=v}}x.putImageData(d,0,0);if(mode===2){x.filter='contrast(1.35)';x.drawImage(c,0,0)}resolve(c.toDataURL('image/png'));};img.onerror=reject;img.src=URL.createObjectURL(file)})}
function normalizeOCRTime(h,m,ap){h=+h;m=+m;if(!Number.isFinite(h)||!Number.isFinite(m)||m>59)return null;ap=(ap||'').toUpperCase();if(ap==='PM'&&h<12)h+=12;if(ap==='AM'&&h===12)h=0;return h<=23?String(h).padStart(2,'0')+':'+String(m).padStart(2,'0'):null}
function extractTimes(line){const out=[];const re=/\b(\d{1,2})\s*[:.]\s*(\d{1,2})\s*(AM|PM)?\b/gi;for(const m of line.matchAll(re)){const t=normalizeOCRTime(m[1],m[2],m[3]);if(t)out.push(t)}
 if(out.length<2){for(const m of line.matchAll(/\b(\d{1,2})(\d{2})\s*(AM|PM)?\b/gi)){const t=normalizeOCRTime(m[1],m[2],m[3]);if(t)out.push(t)}}return out}
function extractDate(line){let m=line.match(/\b(\d{1,2})\s*[\/\.\-]\s*(\d{1,2})(?:\s*[\/\.\-]\s*(\d{2,4}))?\b/);if(!m)return null;let day=+m[1],month=+m[2],year=m[3]?(+m[3]<100?2000+ +m[3]:+m[3]):viewMonday.getFullYear();let dt=new Date(year,month-1,day);return dt.getFullYear()===year&&dt.getMonth()===month-1&&dt.getDate()===day?dt:null}
function dayIndex(line){const l=line.toLowerCase();for(let i=0;i<DAYS.length;i++)if(l.includes(DAYS[i].slice(0,3).toLowerCase()))return i;return -1}

async function ensureTesseract(){
 if(window.Tesseract)return window.Tesseract;
 return new Promise((resolve,reject)=>{
  const existing=document.querySelector('script[data-tesseract-loader]');
  if(existing){existing.addEventListener('load',()=>window.Tesseract?resolve(window.Tesseract):reject(new Error('OCR library loaded but was not available.')),{once:true});existing.addEventListener('error',()=>reject(new Error('Could not load the OCR library.')),{once:true});return}
  const script=document.createElement('script');script.src='https://cdn.jsdelivr.net/npm/tesseract.js@5/dist/tesseract.min.js';script.crossOrigin='anonymous';script.dataset.tesseractLoader='1';
  script.onload=()=>window.Tesseract?resolve(window.Tesseract):reject(new Error('OCR library loaded but was not available.'));
  script.onerror=()=>reject(new Error('Could not load the OCR library. Check that the phone has internet access, then try again.'));
  document.head.appendChild(script);
 });
}
function escapeHTML(v){return String(v).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]))}
function preprocessPhoto(file,mode=0){return new Promise((resolve,reject)=>{const img=new Image();img.onload=()=>{const max=2400,scale=Math.min(2.5,max/Math.max(img.naturalWidth,img.naturalHeight));const c=document.createElement('canvas');c.width=Math.round(img.naturalWidth*scale);c.height=Math.round(img.naturalHeight*scale);const x=c.getContext('2d',{willReadFrequently:true});x.drawImage(img,0,0,c.width,c.height);let d=x.getImageData(0,0,c.width,c.height),a=d.data;if(mode===1||mode===2){for(let i=0;i<a.length;i+=4){const g=0.299*a[i]+0.587*a[i+1]+0.114*a[i+2];let v=g;if(mode===2)v=g>150?255:0;a[i]=a[i+1]=a[i+2]=v}}x.putImageData(d,0,0);if(mode===2){x.filter='contrast(1.35)';x.drawImage(c,0,0)}URL.revokeObjectURL(img.src);resolve(c.toDataURL('image/png'))};img.onerror=()=>reject(new Error('The selected image could not be read.'));img.src=URL.createObjectURL(file)})}
function normalizeOCRTime(h,m,ap){h=+h;m=+m;if(!Number.isFinite(h)||!Number.isFinite(m)||m>59)return null;ap=(ap||'').toUpperCase();if(ap==='PM'&&h<12)h+=12;if(ap==='AM'&&h===12)h=0;return h<=23?String(h).padStart(2,'0')+':'+String(m).padStart(2,'0'):null}
function extractTimes(line){const out=[];const re=/\b(\d{1,2})\s*[:.]\s*(\d{1,2})\s*(AM|PM)?\b/gi;for(const m of line.matchAll(re)){const t=normalizeOCRTime(m[1],m[2],m[3]);if(t)out.push(t)}if(out.length<2){for(const m of line.matchAll(/\b(\d{1,2})(\d{2})\s*(AM|PM)?\b/gi)){const t=normalizeOCRTime(m[1],m[2],m[3]);if(t)out.push(t)}}return out}
function extractDate(line){let m=line.match(/\b(\d{1,2})\s*[\/\.\-]\s*(\d{1,2})(?:\s*[\/\.\-]\s*(\d{2,4}))?\b/);if(!m)return null;let day=+m[1],month=+m[2],year=m[3]?(+m[3]<100?2000+ +m[3]:+m[3]):viewMonday.getFullYear();let dt=new Date(year,month-1,day);return dt.getFullYear()===year&&dt.getMonth()===month-1&&dt.getDate()===day?dt:null}
function dayIndex(line){const l=line.toLowerCase();for(let i=0;i<DAYS.length;i++)if(l.includes(DAYS[i].slice(0,3).toLowerCase()))return i;return -1}

// One photo handler only. The previous build had an earlier onchange handler that could
// leave the app showing a preview and never reach the OCR code.
document.getElementById('photoInput').onchange=async e=>{
 const file=e.target.files[0]; if(!file)return;
 e.target.value='';
 const url=URL.createObjectURL(file);
 showModal(`<h2>Import hours from photo</h2><p id="ocrStatus">Preparing OCR…</p><img src="${url}" style="width:100%;max-height:280px;object-fit:contain;background:#080c12;border-radius:8px;border:1px solid #293341"><div id="ocrResults"></div><div class="modalactions"><button onclick="closeModal()">Cancel</button></div>`);
 const status=document.getElementById('ocrStatus'),out=document.getElementById('ocrResults');
 try{
   const T=await ensureTesseract();
   status.textContent='Starting OCR…';
   const worker=await T.createWorker('eng',1,{logger:m=>{if(m.status){const pct=m.progress!=null?' '+Math.round(m.progress*100)+'%':'';status.textContent=m.status.replace(/^./,c=>c.toUpperCase())+pct;}}});
   await worker.setParameters({tessedit_pageseg_mode:'11',preserve_interword_spaces:'1'});
   const passes=[];
   for(let mode=0;mode<3;mode++){
     status.textContent=mode===0?'Reading the photo…':mode===1?'Enhancing the photo…':'Trying a high-contrast pass…';
     const img=await preprocessPhoto(file,mode);const r=await worker.recognize(img);passes.push(r.data.text||'');
   }
   await worker.terminate();
   const allText=passes.join('\n');
   const lines=allText.split(/\r?\n/).map(x=>x.trim()).filter(Boolean);
   const found=[];let currentDay=-1;
   for(const line of lines){const di=dayIndex(line);if(di>=0)currentDay=di;const dt=extractDate(line)||((currentDay>=0)?dateFor(currentDay):null);const ts=extractTimes(line);if(dt&&ts.length>=2)found.push({date:new Date(dt),start:ts[0],finish:ts[1]})}
   if(!found.length){const dateMatches=[];for(const line of lines){const d=extractDate(line);if(d)dateMatches.push(d)}const uniqueDates=[...new Map(dateMatches.map(d=>[iso(d),d])).values()];const times=[];for(const line of lines){const ts=extractTimes(line);for(const t of ts)times.push(t)}for(let i=0;i+1<times.length&&i/2<uniqueDates.length;i+=2)found.push({date:new Date(uniqueDates[i/2]),start:times[i],finish:times[i+1]})}
   const unique=[...new Map(found.map(x=>[iso(x.date)+'|'+x.start+'|'+x.finish,x])).values()];
   if(!unique.length){status.textContent='OCR finished, but I could not confidently detect a date with two times.';out.innerHTML=`<p style="font-size:11px;color:#aab4c3">Try a straight-on photo with good lighting and clear times such as <b>7:30</b> and <b>4:00</b>. You can still enter the detected text manually below.</p><div class="ocr-preview">${escapeHTML(allText.slice(0,2200))||'(No OCR text returned.)'}</div><div class="modalactions"><button onclick="closeModal()">Close</button></div>`;return}
   status.textContent='Review the detected entries. Correct anything needed, then import.';
   out.innerHTML=unique.map((x,i)=>`<div class="modalrow" style="margin-top:10px"><div><label>Date</label><input id="ocrD${i}" type="date" value="${iso(x.date)}"></div><div><label>Start</label><input id="ocrS${i}" type="time" value="${x.start}"></div><div><label>Finish</label><input id="ocrE${i}" type="time" value="${x.finish}"></div></div>`).join('')+`<p style="font-size:10px;color:#8f9bad;margin-top:10px">Handwriting recognition is best-effort. Always check the detected times before importing.</p><div class="modalactions"><button onclick="closeModal()">Cancel</button><button class="primary" onclick="importOCR()">Import ${unique.length} shift${unique.length===1?'':'s'}</button></div>`;
   window.importOCR=()=>{let count=0;for(let i=0;i<unique.length;i++){const ds=document.getElementById('ocrD'+i).value;if(!ds)continue;const d=new Date(ds+'T00:00:00');const key=iso(d),st=document.getElementById('ocrS'+i).value,fn=document.getElementById('ocrE'+i).value;if(!st||!fn)continue;state.entries[key]={start:st,finish:fn};count++}save();closeModal();render();toast(count+' shift'+(count===1?'':'s')+' imported');};
 }catch(err){
   console.error('Photo OCR failed:',err);
   status.textContent='Photo OCR could not run.';
   out.innerHTML=`<div class="ocr-preview">${escapeHTML(err.message||err)}</div><p style="font-size:11px;color:#aab4c3">If you are using the Android APK, make sure the phone is online the first time OCR is used so the OCR engine can download its language data.</p><div class="modalactions"><button onclick="closeModal()">Close</button></div>`;
 }
};
