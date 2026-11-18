const {chromium}=require('playwright');
const fs=require('node:fs');
const path=require('node:path');
const {pathToFileURL}=require('node:url');
(async()=>{
 const root=path.resolve(__dirname,'../..');
 const browser=await chromium.launch({headless:true,channel:'msedge'});
 const page=await browser.newPage({viewport:{width:390,height:844}});
 const errors=[];page.on('pageerror',e=>errors.push(e.message));
 await page.goto(pathToFileURL(path.join(root,'index.html')).href);
 const result=await page.evaluate(async()=>{
  await loadDraws(true);await loadDraws(false);
  const checks=[];
  function check(name,pass,detail){checks.push({name,pass,detail});if(!pass)throw Error(name+': '+JSON.stringify(detail));}
  check('No stage input',!document.getElementById('stage'));
  useReference();
  check('Reference profile accepted',profileReady());
  const shift=coefficientShiftDraws(2000,1234);
  check('Reference profile has exactly zero shift',Array.from(shift).every(x=>x===0));
  for(const curve of APP_DATA.curves){
   const got=curveScenario(curve,[12,24,36,60]);
   const si=APP_DATA.drawMeta.series_ids.indexOf(curve.technique_arm_id),n=APP_DATA.drawMeta.n_draws;
   for(const [mi,m] of [12,24,36,60].entries()){
    const raw=Array.from(state.draws.slice(si*n*4+mi*n,si*n*4+(mi+1)*n)).sort((a,b)=>a-b);
    const q=p=>{let h=(raw.length-1)*p,l=Math.floor(h),u=Math.ceil(h);return raw[l]+(raw[u]-raw[l])*(h-l)};
    check('Reference curve equals underlying source draws: '+curve.technique_arm_id+' '+m,
      Math.abs(got[m].median-q(.5))<1e-12 && Math.abs(got[m].lower-q(.025))<1e-12 && Math.abs(got[m].upper-q(.975))<1e-12);
   }
  }
  // Fix coefficient uncertainty to zero for exact, independent odds-ratio checks.
  const original=JSON.parse(JSON.stringify(APP_DATA.coefficients));
  for(const c of Object.values(APP_DATA.coefficients)){c.lower95=c.OR;c.upper95=c.OR;}
  for(const [id,value,key,delta] of [['bmi','27','BMI',1],['ba','1','Ba',1],['age','60','age_ge60',1],['smoking','1','smoking',1],['levator','1','levator_avulsion',1]]){
   useReference();document.getElementById(id).value=value;
   const expected=Math.log(original[key].OR)*delta;
   const shifts=coefficientShiftDraws(2000,9876);
   check('One predictor exact log odds shift: '+key,Array.from(shifts).every(x=>Math.abs(x-expected)<1e-12));
   const p0=.25,p1=1/(1+Math.exp(-(Math.log(p0/(1-p0))+shifts[0])));
   check('One predictor exact odds multiplier: '+key,Math.abs((p1/(1-p1))/(p0/(1-p0))-original[key].OR)<1e-12);
  }
  Object.assign(APP_DATA.coefficients,original);useReference();
  const coefficientChecks=[];
  for(const [id,value,key,delta] of [['bmi','27','BMI',1],['ba','1','Ba',1],['age','60','age_ge60',1],['smoking','1','smoking',1],['levator','1','levator_avulsion',1]]){
   useReference();document.getElementById(id).value=value;
   const shifts=coefficientShiftDraws(100000,9876),c=original[key];
   const mean=Array.from(shifts).reduce((s,x)=>s+x,0)/shifts.length;
   const variance=Array.from(shifts).reduce((s,x)=>s+(x-mean)**2,0)/shifts.length;
   const mu=Math.log(c.OR)*delta,sd=(Math.log(c.upper95)-Math.log(c.lower95))/(2*1.96)*Math.abs(delta);
   check('Coefficient uncertainty mean and SD: '+key,Math.abs(mean-mu)<.015*sd && Math.abs(Math.sqrt(variance)-sd)<.015*sd,{mean,expectedMean:mu,sd:Math.sqrt(variance),expectedSd:sd});
   coefficientChecks.push({key,mean,expectedMean:mu,sd:Math.sqrt(variance),expectedSd:sd});
  }
  useReference();let before=curveScenario(APP_DATA.curves[0],[12,24,36,60]);
  for(const id of ['aa','c','gh','pb','tvl','ap','bp','d'])document.getElementById(id).value='3';
  let after=curveScenario(APP_DATA.curves[0],[12,24,36,60]);
  check('Context POP-Q points do not alter scenarios',JSON.stringify(before)===JSON.stringify(after));
  clearProfile();check('Clear resets required inputs',!profileReady());
  return {checks,coefficientChecks,drawMeta:APP_DATA.drawMeta,eligiblePointEstimates:APP_DATA.points.filter(p=>p.profileEligible).length};
 });
 await page.locator('#referenceButton').click();await page.locator('#calculateButton').click();
 await page.waitForFunction(()=>document.querySelector('#drawStatus')?.textContent==='Updated.',{timeout:60000});
 await page.locator('#tabOverlay').click();
 await page.waitForFunction(()=>document.querySelector('#allCurvesStatus')?.textContent?.startsWith('Seven profile trajectories'),{timeout:60000});
 result.mobile={width:390,documentWidth:await page.evaluate(()=>document.documentElement.scrollWidth),overlayLines:await page.locator('#allCurvesChart .overlay-series').count()};
 result.browserErrors=errors;result.browser=browser.version();result.timestamp=new Date().toISOString();
 if(result.mobile.documentWidth!==390 || result.mobile.overlayLines!==7 || errors.length)throw Error('Mobile interface check failed');
 await page.screenshot({path:path.join(__dirname,'mobile_overlay.png'),fullPage:true});
 fs.writeFileSync(path.join(__dirname,'calculator_verification.json'),JSON.stringify(result,null,2));
 await browser.close();console.log(JSON.stringify({passed:result.checks.length,mobile:result.mobile,errors}));
})().catch(e=>{console.error(e);process.exit(1)});
