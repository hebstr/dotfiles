#!/usr/bin/env Rscript

fail <- \(status, ...) {
  message("board.R: ", ...)
  quit(save = "no", status = status)
}

parse_args <- \(args) {
  out <- NULL
  setup <- NULL
  candidates <- character()
  i <- 1L

  while (i <= length(args)) {
    arg <- args[[i]]

    if (arg %in% c("--out", "--setup")) {
      if (i == length(args)) {
        fail(2L, arg, " needs a value")
      }

      if (arg == "--out") {
        out <- args[[i + 1L]]
      } else {
        setup <- args[[i + 1L]]
      }
      i <- i + 2L
    } else if (startsWith(arg, "--")) {
      fail(2L, "unknown option ", arg)
    } else {
      candidates <- c(candidates, arg)
      i <- i + 1L
    }
  }

  list(out = out, setup = setup, candidates = candidates)
}

resolve_path <- \(path) {
  path <- path.expand(path)

  if (!startsWith(path, "/")) {
    path <- file.path(getwd(), path)
  }

  tail <- character()

  while (!file.exists(path) && dirname(path) != path) {
    tail <- c(basename(path), tail)
    path <- dirname(path)
  }

  do.call(file.path, as.list(c(normalizePath(path), tail)))
}

is_under_tmp <- \(path) {
  path == "/tmp" || startsWith(path, "/tmp/")
}

board_html <- \(rows, dark_surface) {
  cell <- \(src, class) {
    sprintf('<td class="%s"><img src="%s"></td>', class, utils::URLencode(src))
  }

  body <- vapply(
    rows,
    \(row) {
      sprintf(
        "<tr><th>%s</th>%s%s</tr>",
        row$name,
        cell(row$light, "light"),
        cell(row$dark, "dark")
      )
    },
    character(1)
  )

  paste(
    "<!DOCTYPE html>",
    '<html lang="en"><head><meta charset="utf-8"><title>diagram board</title>',
    "<style>",
    "body { margin: 16px; font: 14px sans-serif; }",
    "table { border-collapse: collapse; }",
    "th { vertical-align: top; text-align: left; padding: 8px 16px 8px 0; }",
    "td { vertical-align: top; padding: 8px; border: 1px solid #888; }",
    "td.light { background: #ffffff; }",
    sprintf("td.dark { background: %s; }", dark_surface),
    "img { display: block; }",
    "</style></head><body>",
    "<table>",
    "<tr><th></th><th>light</th><th>dark</th></tr>",
    paste(body, collapse = "\n"),
    "</table>",
    "</body></html>",
    sep = "\n"
  )
}

main <- \(args) {
  opts <- parse_args(args)

  if (is.null(opts$out)) {
    fail(2L, "usage: board.R --out <dir> [--setup <file>] <candidate.mmd>...")
  }

  if (length(opts$candidates) == 0L) {
    fail(2L, "no candidate file given")
  }

  out_dir <- resolve_path(opts$out)

  if (is_under_tmp(out_dir)) {
    fail(
      3L,
      "the output folder ",
      out_dir,
      " is under /tmp, which the snap Chromium cannot read: use a folder of the project"
    )
  }

  missing <- opts$candidates[!file.exists(opts$candidates)]

  if (length(missing) > 0L) {
    fail(2L, "candidate not found: ", paste(missing, collapse = ", "))
  }

  if (!is.null(opts$setup) && !file.exists(opts$setup)) {
    fail(2L, "setup file not found: ", opts$setup)
  }

  stems <- tools::file_path_sans_ext(basename(opts$candidates))

  if (anyDuplicated(stems) > 0L) {
    fail(2L, "two candidates share the name ", stems[anyDuplicated(stems)])
  }

  if (!requireNamespace("hebstr", quietly = TRUE)) {
    fail(4L, "the hebstr package is not available to this R")
  }

  if (!"easy_diagram" %in% getNamespaceExports("hebstr")) {
    fail(
      4L,
      "this hebstr ",
      as.character(utils::packageVersion("hebstr")),
      " does not export easy_diagram(): use a project whose hebstr supports diagrams"
    )
  }

  if (!is.null(opts$setup)) {
    source(opts$setup)
  }

  dark_surface <- get(".dark_surface", envir = asNamespace("hebstr"))

  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  rows <- Map(
    \(file, stem) {
      text <- paste(readLines(file, warn = FALSE), collapse = "\n")
      sub_dir <- file.path(out_dir, stem)

      tryCatch(
        hebstr::easy_out(
          hebstr::easy_diagram(text),
          filename = stem,
          dir = sub_dir,
          subdir = FALSE,
          pair = TRUE,
          quiet = TRUE,
          export = TRUE
        ),
        error = \(e) fail(6L, "rendering ", file, " failed: ", conditionMessage(e))
      )

      written <- list.files(sub_dir, pattern = "-(light|dark)\\.svg$")
      light <- grep("-light\\.svg$", written, value = TRUE)
      dark <- grep("-dark\\.svg$", written, value = TRUE)

      if (length(light) != 1L || length(dark) != 1L) {
        fail(5L, "easy_out() did not write one light and one dark SVG for ", file)
      }

      list(
        name = stem,
        light = file.path(stem, light),
        dark = file.path(stem, dark)
      )
    },
    opts$candidates,
    stems
  )

  board <- file.path(out_dir, "board.html")
  writeLines(board_html(unname(rows), dark_surface), board)
  cat(board, "\n", sep = "")
}

if (sys.nframe() == 0L) {
  main(commandArgs(trailingOnly = TRUE))
}
