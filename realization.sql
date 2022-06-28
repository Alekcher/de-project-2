---------------------------------------------------------Шаг 1----------------------------------------------------------
/* Описание
Создайте справочник стоимости доставки в страны shipping_country_rates из данных, 
указанных в shipping_country и shipping_country_base_rate, сделайте первичный ключ таблицы — серийный id, 
то есть серийный идентификатор каждой строчки. Важно дать серийному ключу имя «id». 
Справочник должен состоять из уникальных пар полей из таблицы shipping.
*/

/*
Из DDL создания таблицы shipping узнаем типы полей:
shipping_country - text
shipping_country_base_rate - NUMERIC(14,3)
*/

--создаем таблицу shipping_country_rates
drop table if exists public.shipping_country_rates;
CREATE TABLE public.shipping_country_rates (
		shipping_country_id serial primary key,
		shipping_country text,
		shipping_country_base_rate NUMERIC(14,3)
		);

	
--заполняем уникальными парами значений
insert into public.shipping_country_rates
			(shipping_country,
			 shipping_country_base_rate)
			 
select distinct shipping_country, 
				shipping_country_base_rate
from public.shipping s;



---------------------------------------------------------Шаг 2----------------------------------------------------------
/* Описание
Создайте справочник тарифов доставки вендора по договору shipping_agreement из данных строки 
vendor_agreement_description через разделитель :.
Названия полей:

    agreementid,
    agreement_number,
    agreement_rate,
    agreement_commission.

Agreementid сделайте первичным ключом.
Подсказка:
Учтите, что при функции regexp возвращаются строковые значения, поэтому полезно воспользоваться функцией cast() , 
чтобы привести полученные значения в нужный для таблицы формат.
*/

--Перед созданием таблицы необходимо понять, какие типы данных нужно использовать. Для этого смотрим на запрос
SELECT distinct agreement[1] as agreementid,
       			agreement[2] as agreement_number,
       			agreement[3] as agreement_rate,
				agreement[4] as agreement_commission
FROM
  (SELECT regexp_split_to_array(vendor_agreement_description, ':+') AS agreement
   FROM shipping) AS t1
order by 1; 

--Из результата запроса видно, что для agreement_number подойдет тип smallint, а для agreement_commission - float. agreement_rate - text;
--Создаем таблицу и заполняем ее данными
drop table if exists shipping_agreement;
create table shipping_agreement (
								agreementid serial primary key,
								agreement_number text,
								agreement_rate numeric(14,2),
								agreement_commission numeric(14,2));

insert into shipping_agreement (agreementid,					
								agreement_number, 
								agreement_rate, 
								agreement_commission)
								
SELECT distinct agreement[1]::int as agreementid,
       			agreement[2]::text as agreement_number,
       			agreement[3]::numeric(14,2) as agreement_rate,
       			agreement[4]::numeric(14,2) as agreement_commission
FROM
  (SELECT regexp_split_to_array(vendor_agreement_description, ':+') AS agreement
   FROM shipping) AS t1
order by 1; 



---------------------------------------------------------Шаг 3----------------------------------------------------------
/*
Создайте справочник о типах доставки shipping_transfer из строки shipping_transfer_description через разделитель :.
Названия полей:

    transfer_type,
    transfer_model,
    shipping_transfer_rate .

Сделайте первичный ключ таблицы — серийный id. 
Подсказка: Важно помнить про размерность знаков после запятой при выделении фиксированной длины в типе numeric().
 Например, если shipping_transfer_rate равен 2.5%, то при миграции в тип numeric(14,2) у вас отбросится 0,5%. 
 */
 
 --Из DDL создания таблицы shipping узнаем, что shipping_transfer_rate имеет тип данных NUMERIC(14,3)
 --Для transfer_type и transfer_model подойдет text
 
 --Создаем и заполняем данными таблицу
drop table if exists shipping_transfer;
create table shipping_transfer (
								transfer_type_id serial primary key,
								transfer_type text,
								transfer_model text,
								shipping_transfer_rate NUMERIC(14,3)
							);

insert into shipping_transfer (transfer_type, 
							   transfer_model, 
							   shipping_transfer_rate)
								
SELECT distinct transfer[1] as transfer_type,
       			transfer[2] as transfer_model,
       			shipping_transfer_rate
FROM
  (SELECT regexp_split_to_array(shipping_transfer_description, ':+') AS transfer,
  		  shipping_transfer_rate
   FROM shipping) AS t1
order by 1;


---------------------------------------------------------Шаг 4----------------------------------------------------------
/*
Создайте таблицу shipping_info с уникальными доставками shippingid и свяжите её с созданными справочниками 
shipping_country_rates, shipping_agreement, shipping_transfer и константной информацией о доставке 
shipping_plan_datetime, payment_amount , vendorid .
Подсказки:
    Cвязи с тремя таблицами-справочниками лучше делать внешними ключами — это обеспечит целостность 
	модели данных и защитит её, если нарушится логика записи в таблицы.
	
    Вы уже сделали идентификаторы, когда создавали справочники shipping_transfer и shipping_country_rates. 
	Теперь достаточно взять нужную информацию из shipping, сделать JOIN к этим двум таблицам и получить идентификаторы для миграции.
*/
/*
Необходимые поля и типы в таблице:
shippingid - int8 --из таблицы shipping
vendorid - int8 --из таблицы shipping
payment_amount - numeric(14,2) --из таблицы shipping
shipping_plan_datetime - timestamp --из таблицы shipping
transfer_type_id - int8 --из таблицы shipping_transfer
shipping_country_id - int8 --из таблицы shipping_country_rates
agreementid - int8 --из таблицы shipping_agreement
*/

drop table if exists shipping_info;
create table shipping_info (
							shippingid int8,
							vendorid int8,
							payment_amount numeric(14,2),
							shipping_plan_datetime timestamp,
							transfer_type_id int8,
							shipping_country_id int8,
							agreementid int8,
							FOREIGN KEY (transfer_type_id) REFERENCES shipping_transfer (transfer_type_id) 
							ON UPDATE cascade,
							FOREIGN KEY (shipping_country_id) REFERENCES shipping_country_rates (shipping_country_id) 
							ON UPDATE cascade,
							FOREIGN KEY (agreementid) REFERENCES shipping_agreement (agreementid) 
                            ON UPDATE CASCADE
						   );


--Заполняем таблицу данными
insert into shipping_info
select distinct s.shippingid,
	   s.vendorid,
	   s.payment_amount,
	   s.shipping_plan_datetime,
	   st.transfer_type_id,
	   scr.shipping_country_id,
	   sa.agreementid
from shipping s 
join shipping_transfer st on concat(st.transfer_type, ':', st.transfer_model) = s.shipping_transfer_description
join shipping_country_rates scr on scr.shipping_country = s.shipping_country
join shipping_agreement sa on concat(sa.agreementid, ':', sa.agreement_number, ':', sa.agreement_rate, ':', regexp_replace(sa.agreement_commission::text, ',', '.') ) = s.vendor_agreement_description;



---------------------------------------------------------Шаг 5----------------------------------------------------------
/*
Создайте таблицу статусов о доставке shipping_status и включите туда информацию из лога shipping (status , state). 
Добавьте туда вычислимую информацию по фактическому времени доставки shipping_start_fact_datetime, shipping_end_fact_datetime . 
Отразите для каждого уникального shippingid его итоговое состояние доставки.
Подсказки:
        Данные в таблице должны отражать максимальный status и state по максимальному времени лога state_datetime в таблице shipping.
		
        shipping_start_fact_datetime — это время state_datetime, когда state заказа перешёл в состояние booked.
		
        shipping_end_fact_datetime — это время state_datetime , когда state заказа перешёл в состояние received.
		
        Удобно использовать оператор with для объявления временной таблицы, потому что можно сохранить информацию по shippingid и 
		максимальному значению state_datetime. Далее при записи информации в shipping_status можно сделать JOIN и дополнить таблицу нужными данными.
*/

/*
Необходимые поля и типы в таблице:
shippingid - int8
status - text
state - text
shipping_start_fact_datetime - timestamp
shipping_end_fact_datetime - timestamp
*/
drop table if exists shipping_status;
create table shipping_status
			 (shippingid int8,
			 status text,
			 state text,
			 shipping_start_fact_datetime timestamp,
			 shipping_end_fact_datetime timestamp);

			
--Заполняем данными таблицу	
insert into shipping_status

with last_state as (
select shippingid,
	   status,
	   state,
	   s.state_datetime,
	   row_number() over (partition by shippingid order by state_datetime desc) as rn_desc,
	   row_number() over (partition by shippingid order by state_datetime) as rn_asc
from shipping s
where state in ('recieved', 'booked')
)

select ls1.shippingid,
	   ls1.status,
	   ls1.state,
	   case when ls2.state_datetime is null then ls1.state_datetime else ls2.state_datetime end as shipping_start_fact_datetime,
	   case when ls2.state_datetime is null then null else ls1.state_datetime end as shipping_end_fact_datetime
from last_state ls1 
left join last_state ls2 on ls1.shippingid = ls2.shippingid 
							and ls1.state <> ls2.state --таким образом убираем джойн с той же самой строкой
							and ls2.rn_asc = 1 --самый первый статус
							
where ls1.rn_desc = 1 --нас интересуют только самый последний статус по заказу
;


---------------------------------------------------------Шаг 6----------------------------------------------------------


/*
Создайте представление shipping_datamart на основании готовых таблиц для аналитики
*/
drop view if exists shipping_datamart;
create view shipping_datamart as
select si.shippingid,
	   si.vendorid ,
	   st.transfer_type,
	   extract(days from shipping_end_fact_datetime-shipping_start_fact_datetime) 
	         as full_day_at_shipping,
	   case when shipping_end_fact_datetime > shipping_plan_datetime then 1 else 0 
	        end as is_delay,
	   case when state = 'recieved' then 1 else 0 
	        end as is_shipping_finish,
	   case when shipping_end_fact_datetime > shipping_plan_datetime then extract(days from shipping_end_fact_datetime - shipping_plan_datetime)
	        else 0
	        end as delay_day_at_shipping,
	   payment_amount,
	   payment_amount*(scr.shipping_country_base_rate  + sa.agreement_rate  + st.shipping_transfer_rate)  as vat,
	   payment_amount*agreement_commission as profit 
from shipping_info si
join shipping_transfer st on st.transfer_type_id  = si.transfer_type_id
join shipping_status ss on ss.shippingid = si.shippingid
join shipping_country_rates scr on scr.shipping_country_id = si.shipping_country_id
join shipping_agreement sa on sa.agreementid  = si.agreementid;


--проверяем есть ли данные в новой вьюхе
select * 
from shipping_datamart
limit 10;
