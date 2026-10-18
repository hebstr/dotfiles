---
name: reference_streamlit_config_cwd
description: "Streamlit reads .streamlit/config.toml from the launch directory only, so a copy inside the app's own subdirectory is dead config while the CSS beside it still works"
metadata:
  type: reference
---

Streamlit resolves its project config as `$CWD/.streamlit/config.toml`, against the directory the process is launched from, never against the directory holding the script.
An app at `annot/app.py` launched from the project root therefore ignores `annot/.streamlit/config.toml` entirely: the theme, server and client settings in it never apply.

What still works from a subdirectory is whatever the app opens by explicit path, the CSS read through `Path(f"{CONFIG_DIR}/{file}.css")` among it.
That is what makes such a copy look alive while its `config.toml` half is inert, and why the symptom is a theme that never takes rather than an error.

Found in `crpv-ciclo` on 2026-10-18, where `note/.streamlit/config.toml` had never applied since the app was written.
`eds-prise` keeps the directory at the project root for this reason, and its launcher `cd`s to the root before `streamlit run`.

So the robust shape is `.streamlit/` at the project root plus a launcher holding `cd "$(dirname "${BASH_SOURCE[0]}")/.."`, which makes the resolution independent of where the user stood.
`secrets.toml` goes through the same `config.get_config_files()`, so an app reading it by explicit path keeps working where `st.secrets` does not.

**The script-directory copy is dead code rather than an absent feature**, which is what bounds this note's shelf life. Measured on streamlit 1.66.0: `get_config_files()` always includes `Path.cwd()/.streamlit/config.toml`, and a second branch adds the script's own directory under `if _main_script_path is not None`, but `config._main_script_path` is declared `None` and assigned nowhere in the package.
Re-check that branch after a streamlit upgrade before relying on the rule, since enabling it upstream would make a subdirectory copy live again.

Related: [[reference_streamlit_altair_charts]], [[reference_streamlit_dataframe_styler]].
