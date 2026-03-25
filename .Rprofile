### OPTIONS --------------------------------------------------------------------

if (interactive()) {
  tryCatch(
    {
      jvm_path <- Sys.getenv("LIBJVM_PATH", unset = NA)
      if (is.na(jvm_path)) {
        jvm_path <- system("find /usr/lib -name libjvm.so", intern = TRUE)[1]
      }
      if (!is.na(jvm_path) && nzchar(jvm_path)) dyn.load(jvm_path)
    },
    error = \(e) message("Note: JVM not loaded — ", conditionMessage(e))
  )
}

options(
  duckdb.enable_rstudio_connection_pane = TRUE,
  tidyverse.quiet = TRUE,
  tidymodels.quiet = TRUE,
  openxlsx2.maxWidth = 60,
  digits = 3
)

# conflicted::conflicts_prefer(dplyr::filter(), .quiet = TRUE)
