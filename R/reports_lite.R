#### reports_lite.R — small shared hand-rolled HTML/Markdown helpers ####
#
# Both eri_feedback_report()'s weekly digest and eri_dq_export() are
# deliberately hand-rolled HTML/Markdown rather than routed through
# eri_report_html() (which hard-requires a working Quarto install -- a
# one-line standing report or a DA mid-review clicking "print report" is
# exactly the case that would fail for someone without Quarto). This file is
# the one place their small shared building blocks live, so the two don't
# duplicate escaping/table/page-wrapper logic.

#' @keywords internal
.eri_html_escape <- function(x) {
  x <- as.character(x)
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;",  x, fixed = TRUE)
  x <- gsub(">", "&gt;",  x, fixed = TRUE)
  x
}

#' @keywords internal
.eri_html_row <- function(cells) paste0("<tr>", paste0(cells, collapse = ""), "</tr>")

#' @keywords internal
.eri_html_td <- function(x, cls = "") {
  paste0("<td", if (nzchar(cls)) paste0(" class='", cls, "'") else "", ">", x, "</td>")
}

#' @keywords internal
.eri_html_th_row <- function(xs) paste0("<tr>", paste0("<th>", xs, "</th>", collapse = ""), "</tr>")

#' @keywords internal
.eri_html_fmt_date <- function(x) {
  d <- substr(x %||% "", 1L, 10L)
  if (is.na(d) || !nzchar(d)) "—" else d
}

# Shared CSS foundation for the Carter Center ORG palette (navy #001737 /
# green #00873f) -- shared artifacts (feedback reports, DQ handback exports)
# get this brand; data products get the package's own eri_brand_colors().
# Callers append their own additional rules (chips, print stylesheet, ...).
#' @keywords internal
.eri_org_html_css_base <- function() {
  paste(
    "body{font-family:'Source Sans 3',system-ui,Segoe UI,Roboto,sans-serif;color:#1c2638;",
    "max-width:960px;margin:2rem auto;padding:0 1.2rem;line-height:1.45}",
    "h1{font-family:'Source Serif 4',Georgia,serif;color:#001737;margin-bottom:.2rem}",
    "h2{font-family:'Source Serif 4',Georgia,serif;color:#001737;margin-top:2rem;",
    "border-bottom:1px solid #dde6ef;padding-bottom:.3rem}",
    ".meta{color:#5b6678;margin-bottom:1rem}",
    "table{border-collapse:collapse;width:100%;margin:.5rem 0;font-size:.92rem}",
    "th,td{text-align:left;padding:.45rem .6rem;border-bottom:1px solid #eef2f7;vertical-align:top}",
    "th{color:#5b6678;font-size:.78rem;text-transform:uppercase;letter-spacing:.04em}",
    ".empty{color:#5b6678;font-style:italic}",
    sep = ""
  )
}

# Wraps a body + CSS into a full, self-contained HTML page (Google Fonts link,
# shared doctype/head skeleton) -- the same page shell for every hand-rolled
# org-branded export.
#' @keywords internal
.eri_html_page <- function(title, css, body) {
  paste0(
    "<!DOCTYPE html><html lang='en'><head><meta charset='utf-8'>",
    "<title>", .eri_html_escape(title), "</title>",
    "<link href='https://fonts.googleapis.com/css2?family=Source+Serif+4:wght@600;700&",
    "family=Source+Sans+3:wght@400;600;700&display=swap' rel='stylesheet'>",
    "<style>", css, "</style></head><body>",
    "<h1>", .eri_html_escape(title), "</h1>",
    body, "</body></html>"
  )
}
