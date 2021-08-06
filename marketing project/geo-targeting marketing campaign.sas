/*bacground:a comutpter chain store has 15 stores across London,UK
target:how far customers travel to buy computers
target:which computer in high demand*/
%let path = F:\sas\sas project\geo-targeting;
%macro import ();
OPTIONS VALIDVARNAME=V7;*VALIDVARNAME= System Option. Controls the type of SAS variable names that can be used or created during a SAS session;
proc import datafile = "&path/Test File.csv"
out = test
dbms = CSV
replace
;
run; 

proc import datafile = "&path/sales_q1.csv"
 out = Sales_Q1
 dbms = CSV
 replace
 ;
run;

proc import datafile = "&path/Locations.csv"
 out = locations
 dbms = CSV
 replace
 ;
run;

proc import datafile = "&path/postcode.csv"
 out = postcode
 dbms = CSV
 replace
 ;
run;

filename postcode "&path/open_postcode_geo.csv";/*we want to reference the external file open_postcode_geo.csv*/

data all_postcode (keep=postcode os_x os_y);
infile postcode dsd firstobs=2;
input postcode : $8.
      col1 : $10.
      col2 : $5.
      os_x os_y
      col3 
      area : $8.;
if area = "England" and os_x^=.;
run;
/*The way to reference it is to give it a file reference (i.e. a name). 
With the filename statement, 
we can reference the file as postcode. */

proc import datafile = "&path/computers.csv"
 out = computers
 dbms = CSV
 replace
 ;
run;

%mend;
%import();

/*put all the data set into permanent library*/
libname geo 'F:\sas\sas project\geo-targeting';
data geo.test geo.sales_q1 geo.locations geo.postcode geo.all_postcode geo.computers;
set test sales_q1 locations postcode all_postcode computers;
run;


/*look at the data set of sales_q1 */
proc means data=sales_q1;
var price;
run;

proc sql;
select 
  distinct 
    qtr(datepart(tran_date)) /*DATEPART ( )  functions are used to extract the date and time values from the SAS date-time value respectively. */
      as quarter, 
    year(datepart(tran_date)) 
      as year
from sales_q1;
quit;

/*join the tables: sales_q1 and locations*/
proc sql;
create table sales_q1_loc as
select a.*, b.os_x as store_x, b.os_y as store_y
from sales_q1 a, locations b
where a.store_postcode = b.postcode;
quit;

/*join the tables: sales_q1_loc and postcode*/
proc sql;
create table sales_q1_loc_pos as
select a.*, b.os_x as cust_x, b.os_y as cust_y
from sales_q1_loc a left join postcode b
on a.customer_postcode = b.postcode;
quit;

/*check the table whether have missing value in sales_q1_loc_pos or not*/
data sales_check;
set sales_q1_loc_pos;
where store_x = . or
      store_y = . or
      cust_x = . or
      cust_y = .;

keep customer_postcode store_postcode store_x store_y cust_x cust_y;
run;
/*the reasons why have missing value is London is huge and there are much more than just 834 postcodes in the city.
In addition, certain customers might live outside London, and their address is not captured in the POSTCODE table.*/

/*use all_postcode to fill in os_x,os_y*/
proc sql;
create table sales_q1_loc_pos2 as
select a.*, b.os_x as cust_x1, b.os_y as cust_y1
from sales_q1_loc_pos a left join all_postcode b
on a.customer_postcode = b.postcode;
quit;

/*use all_postcode to fill in cust_x,cust_y*/
data sales_q1_loc_pos3;
set sales_q1_loc_pos2;
if cust_x = . then cust_x = cust_x1;
if cust_y = . then cust_y = cust_y1;
drop cust_x1 cust_y1;
run;

data sales_q1_loc_pos4;
set sales_q1_loc_pos3;
distance = round(((store_x-cust_x)**2 + (store_y-cust_y)**2) **0.5, 1);*1 means ratain int;
run;

proc univariate data=sales_q1_loc_pos4;
var distance;
histogram;
run;
/*The mean distance traveled to make purchases at our store is 3678 meters (3.6 km)*/
/*In the histogram, you will see that there is quite a significant drop off in distance at 4.5 km:*/
/*We will use this as a reference point. Our direct marketing campaign will focus on the areas that are within 4.5 km of our stores.*/
/*We found that, on average, customers travel about 3.7 km to buy computers.*/

/*what is the total sales of each store*/
proc sql;
create table stat as
select store_postcode, sum(price) as total_sales
from sales_q1_loc_pos4
group by store_postcode
order by total_sales ;
quit;
/*management selected the following three stores for our direct marketing campaign
:E7 8NW,N17 6QA,CR7 8LE*/
proc sql;
create table target as
select distinct store_postcode
from sales_q1_loc_pos4
where store_postcode in ('E7 8NW' 'N17 6QA' 'CR7 8LE');
quit;

/*we will generate the list of postcodes that are within 4.5km of the three stores*/
proc sql;
create table target_postcode as
select a.*,
       round(((b.os_x - a.os_x)**2 + (b.os_y - a.os_y)**2) **0.5, 1) as dist
from all_postcode a, locations b
where b.postcode in
  (select store_postcode
   from target) and 
calculated dist <= 4500;
quit;
/*there are 42408 postcodes that fall within the range of 4.5km from the selected stores*/

/*The list of postcodes must be exported to a CSV file for the marketing team.*/
proc export data=target_postcode
   outfile='F:\sas\sas project\geo-targeting\target_postcode.csv'
   dbms=csv
   replace;
run;

/*we will look at each configuration and to decide which configuration to promote*/
proc sql;
create table config as
select configuration, count(*) as num_sold, sum(price) as total_sales
from sales_q1_loc_pos4
group by configuration
order by total_sales desc;
quit;

/*we will promote the top five configurations*/
data config_promo;
set config;
if _n_ <= 5;
run;

/*we will generate a table which have five specifications that we are going to promote*/
proc sql;
create table product_promo as
select *
from computers
where configuration in (320, 337, 200, 207, 353);
quit;

/*exporte to a file*/
proc export data=product_promo
   outfile='F:\sas\sas project\geo-targeting\product_promo.csv'
   dbms=csv
   replace;
run;
