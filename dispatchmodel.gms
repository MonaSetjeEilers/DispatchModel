

$setglobal hours 100
$setglobal with_dsr "*"

Set
tech           /solar,onshore,offshore, nuclear, ccgt, coal,battery, hydro/
res(tech)      /solar,onshore,offshore/
conv(tech)     /nuclear, ccgt, coal/
sto(tech)      /battery, hydro/
time           /t1*t8783/
t(time)        /t1*t%hours%/
;


Parameter
infeed(time,res)       renewable feed-in
load(time)             load or demand
g_up_lim(conv)             ramping constraints for conventional generation
/        nuclear 0.1
         coal 1
         ccgt 10  /
g_down_lim(conv)           ramping constraints for conventional generation
/        nuclear 0.1
         coal 2
         ccgt 20 /
C(tech)                Maximium generation of all technologies
/        nuclear 30
         coal 15
         ccgt 30
         solar 15
         onshore 20
         offshore 10
         battery 1
         hydro 4 /
cost_CU(res)
/        solar 1
         onshore 2
         offshore 2 /
cost_gen(conv)
/        nuclear 30
         coal 20
         ccgt  40 /
cost_up(conv)
/        nuclear 60
         coal 20
         ccgt 1/
cost_down(conv)
/        nuclear 50
         coal 5
         ccgt 0.1/
cost_dsr /30/
efficiency(sto)
/        battery 0.92
         hydro 0.95 /
;

Variable
Z        objective
;

Positive variables
CU(res,t)           curtailment of renewables
Sto_in(sto,t)       Storage inflow
Sto_out(sto,t)      Storage outflow
Sto_lev(sto,t)      Storage level
G(conv,t)           Generation conventional technology
G_up(conv,t)        Ramping up of conventional generation
G_down(conv,t)      Ramping down of conventional generation
DSR(t)              Demand Side Response
;

Equations
cost                   objective function: minimize cost
energy_balance(t)      Energy balance
conv_eq(conv,t)        Conventional generation
storage(sto,t)         storage constraint
;

cost.. Z=e= sum((conv,t), cost_gen(conv)*G(conv,t)+cost_up(conv)*G_up(conv,t)+
                 cost_down(conv)*G_down(conv,t))+sum((res,t), cost_CU(res)*CU(res,t))+sum(t,cost_dsr*DSR(t))
;

energy_balance(t)$(ord(t)>1).. sum(res,CU(res,t))+load(t)-DSR(t)+sum(sto,Sto_in(sto,t))=e=
                         sum(res, infeed(t, res)*C(res))+ sum(conv, G(conv,t))+sum(sto,Sto_out(sto,t))
;
conv_eq(conv,t)$(ord(t)>1).. G(conv,t)=e=G(conv,t-1)+G_up(conv,t)-G_down(conv,t)
;

storage(sto,t)$(ord(t)>1).. Sto_lev(sto,t)=e=Sto_lev(sto,t-1)+efficiency(sto)*Sto_in(sto,t)-Sto_out(sto,t)
;



G_up.up(conv,t)=g_up_lim(conv);
G_down.up(conv,t)=g_down_lim(conv);
G.up(conv,t)=C(conv);
Sto_lev.up(sto,t)=C(sto);
G.l(conv,'t1')=15;
Sto_lev.l(sto,'t1')=1;
DSR.up(t)=5;




$onecho > temp.tmp
par=infeed               rng=Sheet1!A1:D8784          rdim=1  cdim=1
par=load               rng=Sheet1!F1                  rdim=1  cdim=0
$offecho
$call "gdxxrw Germany_time-series.xlsx @temp.tmp o=Data_input"
$GDXin Data_input.gdx
$load infeed load
;
option lp=mosek;

$if defined res $log set res is defined
$if varType G $log generation G is a variable
$if "%with_dsr%" $set cost_dsr 10 $log cost of dsr is 10

model dispatch /all/;
solve dispatch using LP minimizing Z;

Parameters
report_CU(res)
report_G(conv)
report_sto(sto)
report_RES(res)
;
report_CU(res)=sum(t,CU.l(res,t));
report_G(conv)=sum(t,G.l(conv,t));
report_sto(sto)=sum(t,Sto_out.l(sto,t));
report_RES(res)=sum(t, infeed(t,res)*C(res));


execute_unload "results.gdx" report_CU report_G report_sto report_RES
*execute 'gdxxrw.exe results.gdx var=report_CU,report_G,report_sto,report_RES'
execute 'gdx2xls results.gdx'
