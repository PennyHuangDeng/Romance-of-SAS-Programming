proc import out=estate datafile="D:\DATA ANALYSIS\sas documents\udemy02\datasets\datasets\realestate.xlsx" dbms=xlsx replace;
getnames=yes;
run;
 
* correlation matrix;
proc corr data=estate;run;
 
* regression;
proc reg data=estate;
model price = sqft;
run; 
 
* find average latitude;
proc sql;
create table lat as
select *, AVG(latitude) as avglat
from estate
;quit;
 
* create latitude dummy;
data latitude;
set lat;
if latitude >avglat then high=1;
    else high=0;
run;
 
* regression;
proc reg data=latitude;
model price = sqft high;
run; 
 
* classify calendar;
data cal;
set latitude;
weekday=substr(sale_date,1,3);
run;
 
* regression on weekdays;
proc glm data=cal;
class weekday;
model price = sqft high weekday / solution noint;
run;

