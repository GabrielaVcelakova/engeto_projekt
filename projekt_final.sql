drop table t_Gabriela_Vcelakova_projekt_SQL_final2;
CREATE TABLE  t_Gabriela_Vcelakova_projekt_SQL_final AS(
/*---------------------------------------------------------------------*/
/*-------------------Poèet nakazenych, testu, obyvatel-----------------*/
/*---------------------------------------------------------------------*/
With pocty as
(SELECT cbd.date, 
		cbd.country, 
		cbd.confirmed , 
		ct.cumulative as cumulative_test ,
		ct.tests_performed, 
		lt.population,
		round(100*cumulative/lt.population,2) as procento_nakazenych
from covid19_basic_differences cbd
left join covid19_tests ct on cbd.country = ct.country and cbd.date = ct.date
left join lookup_table lt on ct.country = lt.country
where YEAR (cbd.date) = 2020
),
/*---------------------------------------------------------------------*/
/*-------------------Casová promenna ----------------------------------*/
/*---------------------------------------------------------------------*/
polokoule as(
select c.country,
	case when c.north > 0 then 1 else 0 end as polokoule,
	cbd.date
from countries c
left join covid19_basic_differences cbd on c.country = cbd.country 
),
casova_promenna  as 
(SELECT DISTINCT 
	plk.country ,
	plk.date,
	case when WEEKDAY(plk.date) in (5, 6) then 1 else 0 end as weekend,
	case when MONTH(plk.date) in (12,1,2) and polokoule = 1 then 0
		 when MONTH(plk.date) in (12,1,2) and polokoule = 0 then 2
		 when MONTH(plk.date) in (3,4,5) and polokoule = 1 then 1
		 when MONTH(plk.date) in (3,4,5) and polokoule = 0 then 3
		 when MONTH(plk.date) in (6,7,8) and polokoule = 1 then 2
		 when MONTH(plk.date) in (6,7,8) and polokoule = 0 then 0
		 when MONTH(plk.date) in (9,10,11) and polokoule = 1 then 3
		 when MONTH(plk.date) in (9,10,11) and polokoule = 0 then 1
		end as season,
	YEAR (plk.date) as rok
FROM polokoule plk
where YEAR (plk.date) = 2020
),
/*---------------------------------------------------------------------*/
/*-------------------Ekonomické uzazatele--------------------------------*/
/*---------------------------------------------------------------------*/
hustota_zalidneni AS 
(SELECT DISTINCT 
	c.country,
	c.population_density,
	c.median_age_2018 
FROM countries c
),	
ekonomicke_ukazatele AS
/*priblizna data pro rok 2020, beru roky 2018 a 2019
 * zjistim jaký je trend a pøiètu ho k roku 2019*/	
(SELECT DISTINCT 
	e.country, 
    round(e.GDP + (( e.GDP - e2.GDP ) / e2.GDP)*e.GDP,2) as GDP_growth,
    round(e.population + (( e.population - e2.population ) / e2.population),0 ) as pop_growth,
   /* e.gini + (e.gini/100*round( ( e.gini - e2.gini ) / e2.gini * 100, 2)) as gini_growth_percent,*/
	round(e.mortaliy_under5 + (( e.mortaliy_under5 - e2.mortaliy_under5 ) / e2.mortaliy_under5),2) as mortaliy_under5_growth   
FROM economies e 
JOIN economies e2 
    ON e.country = e2.country 
    AND e.year = e2.year + 1
    and e.year in (2019)
 )  ,
Gini as /*vyhledat poslední známý údaj*/
(select country, gini 
from (select 
		ROW_NUMBER() OVER (PARTITION BY country ORDER BY e3.year DESC) AS rn,
		e3.year,
		country,
		gini 
	from economies e3 
	where gini is not null
	) a
WHERE a.rn = 1
),
nabozenstvi as 
(SELECT c.country ,
	sum(CASE WHEN r.religion ='Christianity' THEN  round(r.population/c.population*100,0) END) as Christianity,
	sum(CASE WHEN r.religion ='Islam' THEN  round(r.population/c.population*100,0) END) as Islam,
	sum(CASE WHEN r.religion ='Unaffiliated Religions' THEN  round(r.population/c.population*100,0) END) as Unaffiliated_Religions,
	sum(CASE WHEN r.religion ='Hinduism' THEN  round(r.population/c.population*100,0) END )as Hinduism,
	sum(CASE WHEN r.religion ='Buddhism' THEN  round(r.population/c.population*100,0) END) as Buddhism,
	sum(CASE WHEN r.religion ='Folk Religions' THEN  round(r.population/c.population*100,0) END )as Folk_Religions,
	sum(CASE WHEN r.religion ='Other Religions' THEN  round(r.population/c.population*100,0) END) as Other_Religions,
	sum(CASE WHEN r.religion ='Judaism' THEN  round(r.population/c.population*100,0) END )as Judaism
FROM countries c 
JOIN religions r
    ON c.country = r.country
    AND r.year = 2020
    and round(r.population/c.population*100,0) <> 0
 group by country
),
doba_doziti as 
(SELECT a.country,
    round( b.life_exp_2015 - a.life_exp_1965, 2 ) as life_2015exp_minus_1965exp
FROM (
    SELECT le.country , le.life_expectancy as life_exp_1965
    FROM life_expectancy le 
    WHERE year = 1965
    ) a JOIN (
    SELECT le.country , le.life_expectancy as life_exp_2015
    FROM life_expectancy le 
    WHERE year = 2015
    ) b
    ON a.country = b.country),
/*---------------------------------------------------------------------*/
/*--------------------------------Pocasi--------------------------------*/
/*---------------------------------------------------------------------*/
/*tabulka weather obsahuje pouze 35 mest, navíc se nemusí vždy jedna o hlavní mìsto, je zde napøíklad Brno
 * jména hlavních mest se neshodují s tabulkou countries napø. Praha a Prague
 * napojení na country je tedy možné jen pro 34 mest */
stat_hlavni_mesto_pomocna as 
(SELECT DISTINCT c.country,  c.capital_city, w.city FROM countries as c
LEFT JOIN weather w on c.capital_city = w.city 
UNION 
SELECT DISTINCT c.country,  c.capital_city, w.city FROM countries as c
RIGHT JOIN weather w on  c.capital_city = w.city 
ORDER BY country 
),
weather2 as 
(SELECT *,
	CASE WHEN city = 'Prague' then 'Praha' 
		WHEN city = 'Vienna' then 'Wien' 
		WHEN city = 'Warsaw' then 'Warszawa' 
		WHEN city = 'Rome' then 'Roma' 
		WHEN city = 'Brussels' then 'Bruxelles [Brussel]' 
		WHEN city = 'Luxembourg' then 'Luxembourg [Luxemburg/L' 
		WHEN city = 'Lisbon' then 'Lisboa' 
		WHEN city = 'Helsinki' then 'Helsinki [Helsingfors]' 
		WHEN city = 'Athens' then 'Athenai' 
		WHEN city = 'Bucharest' then 'Bucuresti' 
		WHEN city = 'Kiev' then 'Kyiv' 
	else  city end as city2
from weather
),
pocasi_prumerna_denni_teplota as 
(select 
	w.city2, 
	w.date, 
	avg(temp) as prumerna_denni_teplota
from weather2 w
where hour BETWEEN 6 and 18
	and year(w.date) = 2020
group by city2,w.date
),
pocasi_nenulove_srazky as 
(select 
	city2, 
	w.date, 
	count(w.hour) * 3 as pocet_hodin_deste
from weather2 w
where rain > 0
	and year(w.date) = 2020
group by city2, w.date
order by city2
),
pocasi_max_vitr as 
(SELECT 	city2,
	w.date,
	max(gust) as max_sila_vetru
from weather2 w
where year(w.date) = 2020
group by city2, w.date
order by city2
),
pocasi_vse as 
(select pmv.*,ppdt.prumerna_denni_teplota, pns.pocet_hodin_deste, c2.country 
from pocasi_max_vitr pmv
left join pocasi_prumerna_denni_teplota ppdt on pmv.city2 = ppdt.city2 and pmv.date = ppdt.date
left join pocasi_nenulove_srazky pns on pmv.city2 = pns.city2 and pmv.date = pns.date
left join countries c2 on pmv.city2 = c2.capital_city
where pmv.city2<>'Brno'
)
/*-------------------------------------------------------------*/
/*----------------Zaverecny select-----------------------------*/
/*-------------------------------------------------------------*/
select 
	cp.country,
	cp.date,
	cp.weekend,
	cp.season,
	p.population,
	p.confirmed,
	p.procento_nakazenych,
	p.cumulative_test,
	hz.population_density,
	hz.median_age_2018, 
	eu.GDP_growth, 
	eu.pop_growth,
	eu.mortaliy_under5_growth,
	g.gini,
	dd.life_2015exp_minus_1965exp,
	n.Christianity,
	n.Islam,
	n.Unaffiliated_Religions,
	n.Hinduism,
	n.Buddhism,
	n.Folk_Religions,
	n.Other_Religions,
	n.Judaism,
	pv.max_sila_vetru,
	pv.prumerna_denni_teplota,
	pv.pocet_hodin_deste
FROM casova_promenna cp
left join pocty p on cp.country = p.country and cp.date = p.date
left join hustota_zalidneni hz on cp.country = hz.country
left join ekonomicke_ukazatele eu on hz.country = eu.country
left JOIN gini g on hz.country = g.country
left join doba_doziti dd on hz.country = dd.country
left join nabozenstvi n on hz.country = n.country
left join pocasi_vse pv on cp.country = pv.country and cp.date = pv.date
order by country
);