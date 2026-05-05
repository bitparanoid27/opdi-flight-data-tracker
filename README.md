# opdi-flight-data-parser

Data provided by [OPDI](<[url](https://www.opdi.aero/)>). To track flights, data provided is in airports.csv, runways.csv, flight_list202603.parquet, flight_events and measurements parquet files.
Events and measurements data is provided in 10 day interval. So that data had to be patched up and then inserted into psql database.

Airports and runways data is provided by `ourairports.com`. Whereas OPDI provides raw data related to flights, events and measurements.
DuckDB is used to ingest `.parquet` files data into database. DuckDB commands used can be found in [duckdb.md](/flight-tracker//duckdb.md) .
