
const DAYS=['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
const storeKey='worktrack.desktop.v1';
const state=JSON.parse(localStorage.getItem(storeKey)||'{}');
state.entries=state.entries||{}; state.weekdayRate=state.weekdayRate ?? 27.1; state.saturdayRate=state.saturdayRate ?? 27.1; state.sundayRate=state.sundayRate ?? 27.1; state.use24Hour=state.use24Hour!==false;
let viewMonday=monday(new Date());
function save(){localStorage.setItem(storeKey,JSON.stringify(state));}
function monday(d){let x=new Date(d); x.setHours(0,0,0,0); let day=x.getDay(); let diff=(day===0?-6:1-day); x.setDate(x.getDate()+diff); return x}
function iso(d){return d.toISOString().slice(0,10)}
function dateFor(i){let d=new Date(viewMonday);d.setDate(d.getDate()+i);return d}
function fmtDate(d,year=true){return d.toLocaleDateString('en-AU',{day:'numeric',month:'short',...(year?{year:'numeric'}:{})})}
function parseTime(s){if(!s)return -1;let t=s.trim().toUpperCase().replace(/\./g,':').replace(/\s+/g,'');let pm=t.endsWith('PM'),am=t.endsWith('AM');t=t.replace(/AM|PM/g,'');let a=t.split(':');if(a.length!==2)return -1;let h=Number(a[0]),m=Number(a[1]);if(!Number.isInteger(h)||!Number.isInteger(m)||m<0||m>59)return -1;if(pm&&h<12)h+=12;if(am&&h===12)h=0;if(h<0||h>23)return -1;return h*60+m}
function displayTime(s){let m=parseTime(s);if(m<0)return s||'—';let h=Math.floor(m/60),mi=m%60;if(state.use24Hour)return String(h).padStart(2,'0')+':'+String(mi).padStart(2,'0');let ap=h>=12?'PM':'AM',hh=h%12||12;return hh+':'+String(mi).padStart(2,'0')+' '+ap}
function paidHours(i){let e=state.entries[iso(dateFor(i))]||{};let s=parseTime(e.start),f=parseTime(e.finish);if(s<0||f<0)return 0;if(f<=s)f+=1440;let raw=(f-s)/60;let autoBr=raw>=6?30:10;let br=e.breakMin==null?autoBr:Number(e.breakMin)||0;return Math.max(0,raw-br/60)}
function rate(i){return i===5?Number(state.saturdayRate||0):i===6?Number(state.sundayRate||0):Number(state.weekdayRate||0)}
function money(n){return '$'+Number(n).toFixed(2)}
function render(){
 document.getElementById('weekLabel').textContent=fmtDate(viewMonday,false)+' – '+fmtDate(dateFor(6),true);
 const box=document.getElementById('days');box.innerHTML='';let sum=0,pay=0;
 DAYS.forEach((name,i)=>{let d=dateFor(i),key=iso(d),e=state.entries[key]||{},hrs=paidHours(i);sum+=hrs;pay+=hrs*rate(i);
  const card=document.createElement('article');card.className='day'+(iso(new Date())===key?' active':'');
  card.innerHTML=`<div class="dayhead"><div class="dow">${name}</div><div class="date">${fmtDate(d,false)}</div></div>
  <div class="field"><div class="label">Start</div><input class="time" data-day="${i}" data-field="start" type="time" value="${toInput(e.start)}"></div>
  <div class="field"><div class="label">Finish</div><input class="time" data-day="${i}" data-field="finish" type="time" value="${toInput(e.finish)}"></div>
  <div class="field break"><div class="label">Unpaid break (min)</div><input class="time" data-day="${i}" data-field="break" type="number" min="0" step="1" value="${e.breakMin ?? (hrs?Math.round((hrs>=5.5?.5:10/60)*60):30)}"></div>
  <div class="totalrow"><b>Total</b><span class="hours ${hrs?'':'empty'}">${hrs?hrs.toFixed(2)+' h':'0.00 h'}</span></div>`;
  card.querySelectorAll('input').forEach(inp=>inp.addEventListener('change',()=>updateEntry(i,inp.dataset.field,inp.value)));
  box.appendChild(card);
 });
 document.getElementById('weeklyHours').textContent=sum.toFixed(2)+' h';document.getElementById('estimatedPay').textContent=money(pay);
}
function toInput(s){let m=parseTime(s);return m<0?'':String(Math.floor(m/60)).padStart(2,'0')+':'+String(m%60).padStart(2,'0')}
function updateEntry(i,field,value){let key=iso(dateFor(i));let e=state.entries[key]||{};if(field==='break')e.breakMin=Math.max(0,Number(value)||0);else e[field]=value;if(!e.start&&!e.finish&&!e.breakMin)delete state.entries[key];else state.entries[key]=e;save();render()}
function showModal(html){document.getElementById('modal').innerHTML=html;document.getElementById('modalBack').classList.add('show')}
function closeModal(){document.getElementById('modalBack').classList.remove('show');document.getElementById('modal').classList.remove('calendar-modal')}
document.getElementById('modalBack').addEventListener('click',e=>{if(e.target.id==='modalBack')closeModal()});
function toast(msg){let t=document.getElementById('toast');t.textContent=msg;t.classList.add('show');clearTimeout(toast.timer);toast.timer=setTimeout(()=>t.classList.remove('show'),2200)}

document.getElementById('prevWeek').onclick=()=>{viewMonday.setDate(viewMonday.getDate()-7);render()};
document.getElementById('nextWeek').onclick=()=>{viewMonday.setDate(viewMonday.getDate()+7);render()};
document.getElementById('todayBtn').onclick=()=>{viewMonday=monday(new Date());render()};
document.getElementById('clearWeek').onclick=()=>{if(confirm('Clear all shifts for this week?')){for(let i=0;i<7;i++)delete state.entries[iso(dateFor(i))];save();render();toast('Week cleared')}};
document.getElementById('ratesBtn').onclick=()=>showModal(`<h2>Hourly rates</h2><p>Rates are selected automatically by the day. Weekday covers Monday–Friday.</p><div class="modalgrid"><div><label>Weekday</label><input id="mWeek" type="number" step="0.01" value="${state.weekdayRate}"></div><div><label>Saturday</label><input id="mSat" type="number" step="0.01" value="${state.saturdayRate}"></div><div><label>Sunday</label><input id="mSun" type="number" step="0.01" value="${state.sundayRate}"></div></div><div class="modalactions"><button onclick="closeModal()">Cancel</button><button class="primary" onclick="saveRates()">Save</button></div>`);
window.saveRates=()=>{state.weekdayRate=Number(document.getElementById('mWeek').value)||0;state.saturdayRate=Number(document.getElementById('mSat').value)||0;state.sundayRate=Number(document.getElementById('mSun').value)||0;save();closeModal();render();toast('Rates saved')};
document.getElementById('formatBtn').onclick=()=>showModal(`<h2>Time format</h2><p>Choose how saved times are displayed.</p><div class="modalgrid"><label><input id="f24" type="radio" name="fmt" ${state.use24Hour?'checked':''}> 24-hour (14:30)</label><label><input id="f12" type="radio" name="fmt" ${!state.use24Hour?'checked':''}> 12-hour AM/PM (2:30 PM)</label></div><div class="modalactions"><button onclick="closeModal()">Cancel</button><button class="primary" onclick="saveFormat()">Save</button></div>`);
window.saveFormat=()=>{state.use24Hour=document.getElementById('f24').checked;save();closeModal();render()};
document.getElementById('printBtn').onclick=()=>window.print();
document.getElementById('exportCsv').onclick=()=>{let rows=[['Date','Day','Start','Finish','Break (min)','Paid hours','Rate','Estimated pay']];for(let i=0;i<7;i++){let d=dateFor(i),e=state.entries[iso(d)]||{},raw=paidHours(i),s=parseTime(e.start),f=parseTime(e.finish),autoBr=(s>=0&&f>=0)?(((f<=s?f+1440:f)-s)>=360?30:10):30,br=e.breakMin??autoBr;rows.push([iso(d),DAYS[i],displayTime(e.start),displayTime(e.finish),br,raw.toFixed(2),rate(i).toFixed(2),(raw*rate(i)).toFixed(2)])}let csv=rows.map(r=>r.map(x=>'"'+String(x).replaceAll('"','""')+'"').join(',')).join('\n');let a=document.createElement('a');a.href=URL.createObjectURL(new Blob([csv],{type:'text/csv'}));a.download='worktrack-'+iso(viewMonday)+'.csv';a.click();URL.revokeObjectURL(a.href);toast('CSV exported')};


let calendarMonth=new Date(); calendarMonth.setDate(1);
function monthName(d){return d.toLocaleDateString('en-AU',{month:'long',year:'numeric'})}
function monthKey(y,m,day){return iso(new Date(y,m,day))}
function monthCalendarHTML(){
 const y=calendarMonth.getFullYear(),m=calendarMonth.getMonth();
 const first=new Date(y,m,1),daysInMonth=new Date(y,m+1,0).getDate();
 const startCol=(first.getDay()+6)%7;
 let cells=[];
 const weeks=Math.ceil((startCol+daysInMonth)/7);
 let workedDays=0,totalHours=0,biggest=0;
 for(let w=0;w<weeks;w++){
   cells.push(`<div class="week-label">${w+1}</div>`);
   for(let col=0;col<7;col++){
     const n=w*7+col-startCol;
     if(n<1||n>daysInMonth){cells.push('<div class="heatcell empty"></div>');continue}
     const d=new Date(y,m,n),key=iso(d),e=state.entries[key]||{};
     const s=parseTime(e.start),f=parseTime(e.finish);
     let hrs=0;
     if(s>=0&&f>=0){let end=f;if(end<=s)end+=1440;let raw=(end-s)/60;let br=e.breakMin==null?(raw>=6?30:10):Number(e.breakMin)||0;hrs=Math.max(0,raw-br/60)}
     if(hrs>0){workedDays++;totalHours+=hrs;biggest=Math.max(biggest,hrs)}
     let level=hrs<=0?'':hrs<4?'level1':hrs<7?'level2':hrs<9?'level3':'level4';
     const today=key===iso(new Date())?' today':'';
     const title=hrs?`${d.toLocaleDateString('en-AU',{day:'numeric',month:'short'})}: ${hrs.toFixed(2)} h`:`${d.toLocaleDateString('en-AU',{day:'numeric',month:'short'})}: No hours logged`;
     cells.push(`<button type="button" class="heatcell ${level}${hrs?' worked':''}${today}" data-date="${key}" title="${title} — click to open this week" aria-label="${title}. Click to open this week."><span class="num">${n}</span></button>`);
   }
 }
 return `<div class="calendar-top"><div class="calendar-title">${monthName(calendarMonth)}</div><div class="calendar-nav"><button id="calPrev">←</button><button id="calToday">Today</button><button id="calNext">→</button></div></div>
 <div class="heatmap-wrap"><div class="heatmap-head"><span></span><span>Mon</span><span>Tue</span><span>Wed</span><span>Thu</span><span>Fri</span><span>Sat</span><span>Sun</span></div><div class="heatmap-grid">${cells.join('')}</div><div class="heat-legend"><span>Less</span><span class="legend-box"></span><span class="legend-box l1"></span><span class="legend-box l2"></span><span class="legend-box l3"></span><span class="legend-box l4"></span><span>More</span></div></div>
 <div class="calendar-stats"><span><b>${workedDays}</b> days worked</span><span><b>${totalHours.toFixed(2)} h</b> total</span><span><b>${biggest.toFixed(2)} h</b> longest day</span></div>`;
}
function renderCalendar(){
 const modal=document.getElementById('modal'); modal.classList.add('calendar-modal'); modal.innerHTML=`<h2>Work calendar</h2><p>Each square is one day. Darker purple means more hours worked.</p>${monthCalendarHTML()}<div class="modalactions"><button onclick="closeCalendar()">Close</button></div>`;
 document.getElementById('modalBack').classList.add('show');
 document.getElementById('calPrev').onclick=()=>{calendarMonth.setMonth(calendarMonth.getMonth()-1);renderCalendar()};
 document.getElementById('calNext').onclick=()=>{calendarMonth.setMonth(calendarMonth.getMonth()+1);renderCalendar()};
 document.getElementById('calToday').onclick=()=>{calendarMonth=new Date();calendarMonth.setDate(1);renderCalendar()};
 document.querySelectorAll('.heatcell[data-date]').forEach(cell=>{
   cell.onclick=()=>{
     const selected=new Date(cell.dataset.date+'T00:00:00');
     viewMonday=monday(selected);
     closeCalendar();
     render();
     toast('Week of '+fmtDate(viewMonday,true));
   };
 });
}
window.closeCalendar=()=>{document.getElementById('modal').classList.remove('calendar-modal');closeModal()};
document.getElementById('calendarBtn').onclick=()=>{calendarMonth=new Date(viewMonday);calendarMonth.setDate(1);renderCalendar()};
document.getElementById('photoBtn').onclick=()=>document.getElementById('photoInput').click();
render();
