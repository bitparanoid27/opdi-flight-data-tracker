-- Transform raw data into usable data. 

-- inspect column data-types, and other table related information. 
select c.column_name, c.data_type  
from information_schema."columns" c    
where table_name = 'raw_measurements_data';

-- check for any duplicates or in-valid enteries in airports data. 
-- find out if any incorrect data present in raw_table.
-- check if any bad exists by iterating
create or replace function data_validator(incoming_table_nm text)
returns table (
    column_name text,
    total bigint,
    real_nulls bigint,
    whitespace_only bigint,
    text_nulls bigint,
    actual_values bigint
)
language plpgsql
as $$
declare
    query text;
begin
    select string_agg(
        format(
            $sql$
            select
                %L as column_name,
                count(*) as total,

                count(*) filter (where col is null) as real_nulls,

                count(*) filter (where col is not null and trim(col) = '') as whitespace_only,

                count(*) filter (where col is not null and lower(trim(col)) = 'null') as text_nulls,

                count(*) filter (
                    where col is not null
                      and trim(col) <> ''
                      and lower(trim(col)) <> 'null'
                ) as actual_values

            from (
                select %I::text as col
                from %I
            ) s
            $sql$,
            c.column_name,
            c.column_name,
            incoming_table_nm
        ),
        ' union all '
    )
    into query
    from information_schema.columns c
    where c.table_name = incoming_table_nm
      and c.data_type in ('text', 'character varying');

    return query execute query;
end;
$$;

select * from data_validator('table_name');
-- table_name to check such as raw_flights_data, raw_runway_data, raw_flight_events_data, raw_measurements_data

-- if no data mis-match. create airports_data_sl table. 
create table airports_data_sl (
  id bigint primary key,
  ident varchar(255),
  type varchar(255),
  name varchar(255),
  latitude_deg double precision,
  longitude_deg double precision,
  elevation_ft bigint, 
  continent varchar(255),
  iso_country varchar(255),
  iso_region varchar(255),
  municipality varchar(255),
  scheduled_service varchar(255),
  icao_code varchar(255),
  iata_code varchar(255),
  gps_code varchar(255),
  local_code varchar(255)
); 

-- insert operation can be used here as the airports data is still under ~200K rows. So insert can do the job but it's not efficient. 

insert into airports_data_sl (id,
    ident,
    type,
    name,
    latitude_deg,
    longitude_deg,
    elevation_ft,
    continent,
    iso_country,
    iso_region,
    municipality,
    scheduled_service,
    icao_code,
    iata_code,
    gps_code,
    local_code )
  select 
    id :: bigint,
    ident :: varchar,
    type :: varchar,
    name :: varchar,
    latitude_deg :: double precision,
    longitude_deg :: double precision,
    elevation_ft :: bigint,
    continent :: varchar,
    iso_country :: varchar,
    iso_region :: varchar,
    municipality :: varchar,
    scheduled_service :: varchar,
    icao_code :: varchar,
    iata_code :: varchar,
    gps_code :: varchar,
    local_code :: varchar
  from raw_airports_data;

alter table airports_data_sl add primary key (id);

-- Similarly check for runway valid data using the data-validator function. 

create table runway_data_sl (
  id bigint primary key,
  airport_ref bigint,
  airport_ident varchar(255),
  length_ft bigint,
  width_ft bigint, 
  surface varchar(255),
  lighted bigint,
  closed bigint,
  le_ident varchar(255),
  le_latitude_deg double precision,
  le_longitude_deg double precision,
  le_elevation_ft bigint,
  le_heading_degT double precision,
  le_displaced_threshold_ft bigint,
  he_ident varchar(255),
  he_latitude_deg double precision,
  he_longitude_deg double precision,
  he_elevation_ft bigint,
  he_heading_degT double precision,
  he_displaced_threshold_ft bigint
); 

insert into runway_data_sl (
    id,
    airport_ref,
    airport_ident,
    length_ft, 
    width_ft,
    surface,
    lighted,
    closed,
    le_ident,
    le_latitude_deg,
    le_longitude_deg,
    le_elevation_ft,
    le_heading_degT,
    le_displaced_threshold_ft,
    he_ident,
    he_latitude_deg,
    he_longitude_deg,
    he_elevation_ft,
    he_heading_degT,
    he_displaced_threshold_ft 
  )
  select 
    id :: bigint,
    airport_ref :: bigint,
    airport_ident :: varchar(255),
    length_ft :: bigint, 
    width_ft :: bigint,
    surface :: varchar(255),
    lighted :: bigint,
    closed :: bigint,
    le_ident :: varchar(255),
    le_latitude_deg :: double precision,
    le_longitude_deg :: double precision,
    le_elevation_ft :: bigint,
    le_heading_degT :: double precision,
    le_displaced_threshold_ft :: bigint,
    he_ident :: varchar(255),
    he_latitude_deg :: double precision,
    he_longitude_deg :: double precision,
    he_elevation_ft :: bigint,
    he_heading_degT :: double precision,
    he_displaced_threshold_ft :: bigint 
  from raw_runway_data;

-- add constraints, primary key, foreign key. 
alter table runway_data_sl add primary key (id);

alter table runway_data_sl 
add constraint "airport_ref_fk" foreign key (airport_ref)
  references airports_data_sl (id);

-- airports and runways are inserted and linked. 

-- Insert flights data into flights_data_sl. Check for any discrepencies in data. If found update the same data in flights_data_sl table. 

create table flights_data_sl (
	id bigint primary key, 
	icao24 varchar(255),
	flt_id varchar(255),
	dof timestamp without time zone,
	adep varchar(255),
	ades varchar(255),
	adep_p varchar(255),
	ades_p varchar(255),
	registration varchar(255),
	model varchar(255),
	typecode varchar(255),
	icao_aircraft_class varchar(255),
	icao_operator varchar(255),
	firt_seen timestamp without time zone,
	last_seen timestamp without time zone, 
	version varchar(255)
);

insert into flights_data_sl  
  select 
    id, 
    case 
      when icao24 is null then null 
      when (trim(icao24) in ('', 'null')) then null
      else icao24
    end, 
    case 
      when flt_id is null then null 
      when (trim(flt_id) in ('', 'null')) then null
      else flt_id
    end,
    case 
      when dof is null then null
      when trim(dof) in ('', 'null') then null
      else trim(dof)::timestamp
    end,
    case
      when adep is null then null
      when (lower(trim(adep)) in ('', 'null')) then null
      else upper(trim(adep))
    end, 
    case
      when ades is null then null
      when (lower(trim(ades)) in ('', 'null')) then null
      else upper(trim(ades))
    end,
    case 
      when adep_p is null then null
      when (lower(trim(adep_p)) in ('', 'null')) then null
      else upper(trim(adep_p))
    end, 
    case 
      when ades_p is null then null
      when (lower(trim(ades_p)) in ('', 'null')) then null
      else upper(trim(ades_p))
    end, 
    case 
      when registration is null then null
      when (lower(trim(registration)) in ('', 'null')) then null
      else upper(trim(registration))
    end, 
    case
      when model is null then null
      when (lower(trim(model)) in ('', 'null')) then null
      else upper(trim(model))
    end,
    case
      when typecode is null then null
      when (lower(trim(typecode)) in ('', 'null')) then null
      else upper(trim(typecode))
    end,
    case
      when icao_aircraft_class is null then null
      when (lower(trim(icao_aircraft_class)) in ('', 'null')) then null
      else upper(trim(icao_aircraft_class))
    end,
    case
      when icao_operator is null then null
      when (lower(trim(icao_operator)) in ('', 'null')) then null
      else upper(trim(icao_operator))
    end,
    case
      when first_seen is null then null
      when trim(first_seen) in ('', 'null') then null
      else trim(first_seen)::timestamp 
    end, 
    case
      when last_seen is null then null
      when trim(last_seen) in ('', 'null') then null
      else trim(last_seen)::timestamp 
    end, 
    case
      when version is null then null
      when trim(version) in ('', 'null') then null
      else upper(trim(version)) 
    end
  from raw_flights_data;

alter table flights_data_sl add primary key (id);

-- Insert flight_events_data into flight_events_data_sl 
-- using insert on data with ~31 million enteries would be a nightmare. So utilising ctas unlogged table. 

create table flight_events_data_sl as 
  select 
    id :: bigint,
    flight_id :: bigint, 
    nullif(nullif(lower(trim(type)), ''), 'null') :: varchar(255) as type,
    event_time :: timestamp without time zone,
    longitude :: double precision,
    latitude :: double precision,
    altitude :: double precision,
    nullif(nullif(lower(trim(source)), ''), 'null') :: varchar(255) as  source,
    nullif(nullif(lower(trim(version)), ''), 'null') :: varchar(255) as  version
  from raw_flight_events_data;

-- Add primary and foreign key constraints. 

alter table flight_events_data_sl add primary key (id);
alter table flight_events_data_sl
add constraint "flight_id_FK" foreign key (flight_id)
  references flights_data_sl (id);


-- Insert flight measurements into flight_measurements_data_sl
create table measurements_data_sl as 
  select 
    id::bigint,
    event_id::bigint,
    nullif(nullif(lower(trim(type)), ''), 'null')::varchar(255) AS type,
    value::double precision,
    nullif(nullif(lower(trim(version)), ''), 'null')::varchar(255) AS version
  from raw_measurements_data;

-- Add primary and foreign key constraints. 

alter table measurements_data_sl add primary key (id);
alter table measurements_data_sl
add constraint "event_id_FK" foreign key (event_id)
  references flight_events_data_sl(id);