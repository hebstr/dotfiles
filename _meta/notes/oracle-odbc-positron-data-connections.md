# Oracle ODBC for Positron Data Connections

*2026-11-12*

Positron 2026.11.1 has Data Connections enabled by default (since 2026.10). That panel interferes with the Oracle JDBC connection opened via rJava/DatabaseConnector: the Oracle session dies within seconds of opening, intermittently, and reconnecting does not help. With `dataConnections.enabled: false`, everything works again. Confirmed on 2026-11-12.

Goal: let Data Connections manage the Oracle connection natively over ODBC (no rJava/JVM), then re-enable `dataConnections.enabled: true` and confirm the JDBC path no longer dies.

## What was done

- Driver registered in `/etc/odbcinst.ini`: `[Oracle 23 ODBC driver]`, `Driver=/opt/oracle/instantclient_23_7/libsqora.so.23.1`.
- DSN written in `~/.odbc.ini`: `[OracleEDS]`, full option set from the Oracle script, `ServerName = odadc5-scan.chrul.net:1521/EHOP.chrul.net`, plus an `[ODBC Data Sources]` section so Positron can auto-detect it.
- ODBC connection verified from the command line with pyodbc: `SELECT 1 FROM DUAL` returns 1, `V$VERSION` shows Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production, clean close.
- Test script stored in the project as a PEP 723 standalone: `eds-prise/test_odbc_oracle.py`, run with `uv run --script test_odbc_oracle.py` (prompts for the password, connects via `DSN=OracleEDS`).

## What remains

1. Open Positron on `eds-prise`.
2. In the Data Connections view (primary sidebar), create a connection: it should offer a dedicated Oracle entry (recognized ODBC driver) or an ODBC entry; the DSN `OracleEDS` should appear with a Detected badge.
3. Connect as user `sas_eds` (password prompted in the form). Browse one table to confirm the tree works.
4. Re-enable Data Connections: set `dataConnections.enabled: true` in Positron settings (`~/.positron-server/data/Machine/settings.json`, currently `false`) and reload Positron.
5. Run a collect script that opens the JDBC connection (DatabaseConnector, see `edsConnect()` in `lib/collect-helpers.R`) and confirm the Oracle session no longer dies within seconds.

## Notes

- Do not modify `lib/collect-helpers.R` or any collect script for this task: the R code works with `dataConnections.enabled: false`, and the goal here is configuring Positron, not the R code.
- No new ODBC package was installed; everything was already present (unixODBC 2.3.12, Oracle Instant Client 23.7 with `libsqora.so.23.1`).
- The JDBC connection string comes from `/opt/oracle/instantclient_23_7/connect/connect.yml` (`tns.ehop: odadc5-scan.chrul.net:1521/EHOP.chrul.net`), the same target as the ODBC DSN.
- If the JDBC session still dies with Data Connections enabled, the next step is to migrate `edsConnect()` from DatabaseConnector/JDBC to an ODBC driver (RooDBC or odbc), which would require a DSN per TNS (the collect scripts use `tns = "vlp"`, not ehop).
