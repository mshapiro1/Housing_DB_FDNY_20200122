/*******************************************
AUTHOR: MARK SHAPIRO
SCRIPT: JOINING FIRE BATTALIONS TO HOUSING DB 19V2
DATE: 01/22/2020
METHODOLOGY: 
1. JOIN FIRE BATTALION TO EACH DEVELOPMENT
2. IF A DEVELOPMENT IS INAPPROPRIATELY GEOCODED TO THE WATER, MATCH IT WITH THE CLOSEST FIRE BATTALION within .5 kilometers
*********************************************/

drop table if exists housing_db_19v2_fdny;
select
	*
into 
	housing_db_19v2_fdny
from
(

with _1 as
	/*Spatial intersect*/
	(
	select
		a.*,
		b.fire_bn
	from
		housing_db_19v2 a
	left join
		fire_battalions b
	on
		st_intersects(a.the_geom,b.the_geom)
	),

	--Identify list of unmatched jobs
	_2 as
	(
		select
			a.the_geom,
			a.the_geom_webmercator,
			a.job_number
		from
			_1 a
		where
			a.fire_bn is null
	),
	--Find all fire battalions within 500 meters of each unmatched job
	_3 as
	(
		select
			a.*,
			b.fire_bn,
			st_distance(a.the_geom::geography,b.the_geom::geography) as distance
		from
			_2 a
		left join
			fire_battalions b
		on
			st_dwithin(a.the_geom::geography,b.the_geom::geography,500)
	),

	--Find the least distance between each job and a fire battalion
	_4 as
	(
		select
			a.job_number,
			min(a.distance) as min_distance
		from
			_3 a
		group by
			a.job_number
	),

	--Use this min_distance to select the closest fire battalion to each unmatched job
	_5 as
	(
		select
			a.*
		from
			_3 a
		inner JOIN
			_4 b
		on
			a.job_number 	= b.job_number 	and
			a.distance 		= b.min_distance
	),

	--Join on these proximate fire batttalions to the original Housing DB
	_6 as
	(
	select
		a.*,
		coalesce(b.fire_bn,c.fire_bn) as fire_bn,
		case when b.fire_bn is null and c.fire_bn is not null then 1 end as proximate_match
	from
		housing_db_19v2 a
	left join
		fire_battalions b
	on
		st_intersects(a.the_geom,b.the_geom)
	left join
		_5 c
	on
		a.job_number = c.job_number
	)

	select * from _6

) x;

select cdb_cartodbfytable('capitalplanning','housing_db_19v2_fdny');
