fmt_pct <- function(x, digits = 1) {
  value <- formatC(100 * x, format = "f", digits = digits, decimal.mark = ",")
  paste0(value, " %")
}
