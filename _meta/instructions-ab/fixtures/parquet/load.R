read_visits <- function(path) {
  nanoparquet::read_parquet(path) |>
    tibble::as_tibble()
}
