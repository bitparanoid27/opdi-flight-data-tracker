###### setup psql in duckdb

`INSTALL postgres;`
`LOAD postgres;`

`attach 'ATTACH 'host=localhost dbname=mydb user=myuser password=mypass port=5432' AS pg (TYPE postgres);' as pg;`

check if duckdb connection established --> `show all tables`;
###### create airports table

```
create table pg.raw_airports_data as 
	select * 
	from read_csv('airport-csv-file-location');
```

###### create runways table

```
create table pg.raw_runway_data as
	select *
	from read_csv('runway-csv-file-location');
```

###### create flights table

```
create table staging AS
    select * 
    from read_parquet('flight-list.parquet'); 
    

create table pg.raw_flights as
	select *
	from staging;
 
drop table staging;
```

###### create flight_events table

Since, flight events is present in 10 days interval. The data is joined to create one month's data before being inserted into the database. 

```
create table staging as
	select * 
	from read_parquet('flight-events-01-10-03-2026.parquet'); 

create table main as
	select *
	from staging;
	
drop table staging; 

create table staging as
	select * 
	from read_parquet('flight-events-11-21-03-2026.parquet'); 

merge into main as target
using staging as source
on source.id = target.id 

when not matched then
	insert(id, flight_id, type, event_time, altitude, source, version, info)
	values (source.id, source.flight_id, source.event_time, source.altitude,    source.source, source.version, source.info); 
	
drop table staging;

create table staging as
	select * 
	from read_parquet('flight-events-21-31-03-2026.parquet'); 

merge into main as target
using staging as source
on source.id = target.id 

when not matched then
	insert(id, flight_id, type, event_time, altitude, source, version, info)
	values (source.id, source.flight_id, source.event_time, source.altitude,    source.source, source.version, source.info);
	
create table pg.raw_flight_events_data as
	select *
	from main; 

drop table staging;
drop table main;
```

Post insertion into database cross-check if any duplicates got created during joining various parquet files. 
```
select count(*) as duplicate_count_check
from raw_flight_events_data 
group_by id
HAVING count(*) > 1;
```
###### create table flight_measurements_data

```
create table staging as
	select * 
	from read_parquet('flight-measurements-01-10-03-2026.parquet'); 

create table main as
	select *
	from staging;
	
drop table staging; 

create table staging as
	select * 
	from read_parquet('flight-measurements-11-21-03-2026.parquet'); 

merge into main as target
using staging as source
on  source.id = target.id and 
	source.event_id = target.event_id and 
 
when not matched then
	insert(id, event_id, type, value, version)
	values(source.id, source.event_id, source.type, source.value, source.version); 
	
drop table staging;

create table staging as
	select * 
	from read_parquet('flight-measurements-21-31-03-2026.parquet'); 

merge into main as target
using staging as source
on  source.id = target.id and 
	source.event_id = target.event_id and 
	
when not matched then
	insert(id, flight_id, type, event_time, altitude, source, version, info)
	values(source.id, source.event_id, source.type, source.value, source.version);
	
create table pg.raw_measurements_data as
	select *
	from main; 

drop table staging;
drop table main;
```

Post insertion into database cross-check if any duplicates got created during joining various parquet files. 

```
select count(*) as duplicate_count_check
from raw_measurements_data 
group_by id
HAVING count(*) > 1;
```

Data ingestion into psql is completed. Bronze layer is ready. 