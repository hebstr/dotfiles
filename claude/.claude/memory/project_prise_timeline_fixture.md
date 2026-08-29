---
name: eds-prise timeline data comes from the EDS Oracle base
description: eds-prise timeline stays are queried live from the CHU EDS Oracle base via `annot/lib/eds.py` (python-oracledb thin, tns `vlp`, service account); replaced the simulated-stay fixture and its parquet snapshot on 2026-08-02
metadata:
  type: project
---

In `~/Documents/des/eds/eds-prise`, the annotation app's timeline reads the patient's stays from the CHU EDS Oracle base at display time (`annot/lib/eds.py`, `fetch_sej(id_pat)`), not from a saved table. Decided and implemented 2026-08-02, replacing both the `*_annot_data_timeline.parquet` snapshot and the earlier `annot/prise_annot_timeline.py` fixture generator (simulated `SIM*` stays, never committed, deleted). The `numpy`-stays-undeclared note attached to that fixture is void; `altair` remains a direct dependency because `annot/lib/timeline.py` imports it.

Decisions taken that day, not to re-litigate: the Streamlit app runs on the CHU workstation (which alone has network access to the base), authentication uses the shared `sas_eds` service account rather than a per-annotator EDS login, and the tns key is `vlp` (`TRA_DATA_19_P`), the same one `collect/prise_collect-eds.R` uses.

The service-account password is never written to disk. It is typed at server launch by `annot/prise_annot_run.sh` (`read -rsp`, exported as `EDS_USER`/`EDS_PASSWORD`, consumed by `eds_pool()`), the equivalent of R's `rstudioapi::askForPassword` in `edsConnect()`. Two options were weighed and rejected: `.streamlit/secrets.toml` (the user does not want the password stored, even gitignored and in 600), and an in-app `st.text_input(type="password")` modal, because `@st.cache_resource` is global to the server process, so the prompt falls on whoever opens the app first after a restart, which would be an annotator who cannot type that password. Typing it at launch makes that case impossible: no password, no server.

Two facts that shaped the design: `connect.yml` (`/opt/oracle/instantclient_23_7/connect/connect.yml`, absent from the personal laptop) holds a JDBC address whose part after `jdbc:oracle:thin:@` is exactly an Oracle Easy Connect DSN, so R's `edsConnect()` and Python read the same file with no duplicated address; and python-oracledb runs thin by default, needing neither the Instant Client nor a JVM, which is why the JDBC route (`jaydebeapi` plus the ojdbc jar) was rejected. Reserve it for a server that refuses thin connections.

Open at implementation time and verifiable only from the CHU host: whether `EDBM_EDS.EHOP_SEJOUR` carries `ID_PAT` (the collect pipeline selects that table without it and links patients through `EHOP_ENTREPOT`). The query in `annot/lib/eds.py` assumes it does.

Related: [[project_edscrib_annotation_package]] covers the sibling eds-avc annotation socle, [[reference_streamlit_altair_charts]] the timeline chart itself.
