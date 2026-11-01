// D-70: the vehicle logic, taken from the real pages (index.html and b/index.html) and run in Node.
//   node supabase/tests/armored/logic.js
const fs=require('fs'), R=__dirname+'/../../../';
const cut=(f,a,b)=>{ const s=fs.readFileSync(R+f,'utf8'), i=s.indexOf(a), j=s.indexOf(b,i); if(i<0||j<0) throw Error('marker missing in '+f+': '+a); return s.slice(i,j); };
const veh=cut('index.html','const VEHICLES = [','const GUIDE_ATTRS');
const guess=cut('index.html','function seatsOf(','  if(/transfer|airport/');
let res=[]; const check=(n,c,d)=>{ res.push(c); console.log((c?'PASS ':'FAIL ')+n+(c?'':' :: '+JSON.stringify(d))); };
for(const f of ['index.html','b/index.html']){
  const bk=cut(f,'const BK_VEH=','const BK_SIGN')+cut(f,'function bkVehicle(','// Rows are');
  const t=new Function(bk+'return [bkVehicle({service:"arm_bus",seats:"50"},true),bkVehicle({service:"arm_bus",seats:"50"},false),bkVehicle({service:"arm_midibus",seats:"30"},false),bkVehicle({service:"arm_van"},true),bkVehicle({service:"arm_car"},false),bkVehicle({service:"midibus",seats:"30"},false),bkVehicle({service:"van16",seats:"14"},true)];')();
  check(f+': booking sheet vehicle line', JSON.stringify(t)===JSON.stringify(['אוטובוס 50 מקומות ממוגן ירי','50-seat armored bus','30-seat armored midibus','מיניבוס ממוגן ירי','Armored car','30-seat midibus','מיניבוס 14 מקומות']), t);
}
const r=new Function(veh+guess+`}
  return {tags:[...fleetOf({tags:'Bus, Armored bus, Armored van'})],
    loose:[...fleetOf({tags:'Bulletproof 50-seat bus, armored midibus, ממוגן ירי מיניבוס, armoured SUV'})].sort(),
    plain:[...fleetOf({tags:'Bus, 19 seat van, Minibus'})].sort(),
    stone:[...fleetOf({tags:'Stone-proof bus'})],
    names:['Armored 50-seat bus','30-seat armored midibus','Bulletproof van','Armored 12 seat','50-seat bus','Stone-proof bus'].map(n=>guessService(n)),
    seats:[3,8,20,30,50].map(vehicleBySeats)};`)();
check('supplier tags', JSON.stringify(r.tags)==='["bus","arm_bus","arm_van"]', r.tags);
check('loose wording (bulletproof, armoured, Hebrew, SUV)', JSON.stringify(r.loose)==='["arm_bus","arm_car","arm_midibus","arm_van"]', r.loose);
check('ordinary tags unchanged', JSON.stringify(r.plain)==='["bus","van16","van20"]', r.plain);
check('stone-proof is not armored', JSON.stringify(r.stone)==='[]', r.stone);
check('option names', JSON.stringify(r.names)==='["arm_bus","arm_midibus","arm_van","arm_van","bus",""]'||JSON.stringify(r.names)==='["arm_bus","arm_midibus","arm_van","arm_van","bus","bus"]', r.names);
check('a seat count alone never means armored', JSON.stringify(r.seats)==='["car","van8","van20","midibus","bus"]', r.seats);
console.log(res.length+' checks, '+res.filter(x=>!x).length+' failed');
