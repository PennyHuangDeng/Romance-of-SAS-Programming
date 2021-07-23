proc import out=car datafile="D:\DATA ANALYSIS\sas documents\udemy02\datasets\datasets\cars.xlsx"
dbms=xlsx;
getnames=yes;
run;
proc corr data=car;run;
/*goals*/
/*1.what matters more to horse power?cylinders or engine size?
2.what is the relationaship between engine size,cylinder,weight,wheelbase,length,and mpg?
3.how would horse power and gasoline efficiency affect the price?
4.how much premium are we paying porsches?*/

*1.determinants of horse power;
proc reg data=car;
model horsepower=cylinders/vif;
run;

*2.determinants of MPG;
proc reg data=car;
model MPG_city=cylinders weight wheelbase length/vif;
run;

*3.determinats of price;
proc reg data=car;
model MSRP=horsepower MPG_city/vif;
run;

*4.brand premium;
proc glm data=car;
class make;
model msrp=horsepower mpg_city make/noint solution;*noint=no intercept;
run;
