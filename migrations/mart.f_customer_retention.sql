with temp1 as (select fsl.*,  dc.week_of_year,  
case when fsl.payment_amount<0 then 'refunded' 
	else 'shipped' end as status from mart.f_sales fsl
join mart.d_calendar dc on dc.date_id=fsl.date_id
order by fsl.customer_id), 

new_customer_count as (
select customer_id, week_of_year, item_id, count(distinct date_id) as c11 from temp1 
group by customer_id, week_of_year, item_id 
having count(distinct date_id)=1), 

new_customer_count2 as (
select week_of_year, item_id, count(distinct customer_id) as new_customers_count from new_customer_count 
group by  week_of_year, item_id), 

returning_customer_count as ( 
select customer_id, week_of_year, item_id, count(distinct date_id) as returning_customers_count from temp1 
group by customer_id, week_of_year, item_id 
having count(distinct date_id)>1),

returning_customer_count2 as ( 
select week_of_year, item_id, count(distinct customer_id) as returning_customers_count from returning_customer_count
group by  week_of_year, item_id 
),

refunded_customer as 
(select  week_of_year, item_id, count(distinct customer_id) as refunded_customer_count from temp1
where status='refunded' 
group by  week_of_year, item_id 
), 




new_customers_revenue as
(select nc.week_of_year, nc.item_id, sum(temp1.payment_amount) as new_customers_revenue 
from new_customer_count nc

left join temp1  on nc.customer_id=temp1.customer_id and nc.week_of_year=temp1.week_of_year and nc.item_id=temp1.item_id
group by  nc.week_of_year, nc.item_id),

returning_customers_revenue as
(select rtc.week_of_year, rtc.item_id, sum(temp1.payment_amount) as returning_customers_revenue
from returning_customer_count rtc

left join temp1  on rtc.customer_id=temp1.customer_id and rtc.week_of_year=temp1.week_of_year 
and rtc.item_id=temp1.item_id
group by  rtc.week_of_year, rtc.item_id),



customer_refunded1  as 
(select  customer_id, week_of_year, item_id, count(*) as c from temp1
where temp1.status='refunded' 
group by customer_id, week_of_year, item_id
),

customers_refunded2 as (
select  week_of_year, item_id, sum(c) as customers_refunded from customer_refunded1
 
group by   week_of_year, item_id 

)


INSERT INTO mart.f_customer_retention
select  distinct  
ncc.new_customers_count, 
rcc.returning_customers_count, 
rc.refunded_customer_count, 
'weekly' as period_name, 
dcl.week_of_year as period_id,
di.item_id, 
ncr.new_customers_revenue,
rcr.returning_customers_revenue, 
crf.customers_refunded


from mart.d_item di
left join temp1 dcl  on 1=1
left join new_customer_count2 ncc on dcl.week_of_year=ncc.week_of_year and 
di.item_id=ncc.item_id 
left join returning_customer_count2  rcc on dcl.week_of_year=rcc.week_of_year and 
di.item_id=rcc.item_id 
left join refunded_customer rc on dcl.week_of_year=rc.week_of_year and 
di.item_id=rc.item_id 
left join new_customers_revenue ncr on dcl.week_of_year=ncr.week_of_year and 
di.item_id=ncr.item_id 
left join returning_customers_revenue rcr on dcl.week_of_year=rcr.week_of_year and 
di.item_id=rcr.item_id 
left join customers_refunded2 crf on dcl.week_of_year=crf.week_of_year and 
di.item_id=crf.item_id
where  dcl.week_of_year= DATE_PART('week','{{ds}}'::timestamp); 