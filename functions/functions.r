#' Add on fish names
#'
#' This function adds full fish names from six digit species codes
#'
#' @export
add.fish.names <- function(.data){
  .data %>%
    left_join(fish_names, by = c("spcode" = "NZFFD code"))
}


#' Add fishing methods
#'
#' This function adds the full names for fishing methods from abbreviation
#'
#' @export
add.fish.method <- function(.data){
  .data %>%
    left_join(fish_methods, by = c("fishmeth" = "Abbreviation"))
}

#' Add better formatted dates
#'
#' This function takes dates as formatted by the NZFFD and converts them into actual date columns
#'
#' @export
add.fish.dates <- function(.data){
  .data %>%
    mutate(date = as.Date(paste(y, m, "01", sep="-"), "%Y-%m-%d")) %>%
    mutate(m = month(date))
}

#' Prepare site metrics
#'
#' This function prepares site-level summaries for later metric calculations
#'
#' @export
prep.site.metrics <- function(.data){
  .data %>%
    group_by(nzreach) %>%
    distinct(spcode, .keep_all = TRUE) %>%
    inner_join(species_ibi_metrics, by = "spcode") %>%  # filtering to only species with metric info. change to left_join to get all.
    summarise(
      altitude = first(altitude),
      penet = first(penet),
      east = first(east),
      north = first(north),
      total_sp_richness = n(),
      metric1 = sum(native, na.rm = T),
      metric2 = sum(benthic_riffle, na.rm = T),
      metric3 = sum(benthic_pool, na.rm = T),
      metric4 = sum(pelagic_pool, na.rm = T),
      metric5 = sum(intolerant, na.rm = T),
      number_non_native = sum(non_native, na.rm = T),
      metric6 = metric1 / number_non_native
    )
}

#' Fit quantile regression
#'
#' This function fits a quantile regression for scoring of metrics. This improves
#' upon methods which require fitting by eye.
#'
#' @export
#'
qr.construct <- function(y, x, data = site_metrics_all){
  rq(paste(y, x, sep = " ~ "), tau = c(1/3, 2/3), data = data)
}

#' Score metrics according to quantile regression
#'
#' Once you've fit a quantile regression, you then need to score it
#'
#' @export
qr.score <- function(x, y, qr){

  line_66 <- y > coef(qr)[4] * x + coef(qr)[3]
  line_33 <- y > coef(qr)[2] * x + coef(qr)[1]

  case_when(
    line_66 == TRUE ~ 5,
    line_33 == TRUE ~ 3,
    line_66 == FALSE & line_33 == FALSE ~ 1
  )
}

#' Add metric scores
#'
#' Add each metrics scores onto df
#'
#' @export
add.fish.metrics <- function(.data){
  .data %>%
    mutate(metric1_rating_elev = pmap_dbl(list(x = altitude, y = metric1), qr.score, qr = qr.1.elev),
           metric2_rating_elev = pmap_dbl(list(x = altitude, y = metric2), qr.score, qr = qr.2.elev),
           metric3_rating_elev = pmap_dbl(list(x = altitude, y = metric3), qr.score, qr = qr.3.elev),
           metric4_rating_elev = pmap_dbl(list(x = altitude, y = metric4), qr.score, qr = qr.4.elev),
           metric5_rating_elev = pmap_dbl(list(x = altitude, y = metric5), qr.score, qr = qr.5.elev)) %>%
    mutate(metric1_rating_pene = pmap_dbl(list(x = penet, y = metric1), qr.score, qr = qr.1.penet),
           metric2_rating_pene = pmap_dbl(list(x = penet, y = metric2), qr.score, qr = qr.2.penet),
           metric3_rating_pene = pmap_dbl(list(x = penet, y = metric3), qr.score, qr = qr.3.penet),
           metric4_rating_pene = pmap_dbl(list(x = penet, y = metric4), qr.score, qr = qr.4.penet),
           metric5_rating_pene = pmap_dbl(list(x = penet, y = metric5), qr.score, qr = qr.5.penet))

}

#' Add metric six score
#'
#' Metric six is a bit different, so get scored separately
#'
#' @export
add.fish.metric6 <- function(.data){
  .data %>%
    mutate(metric6_rating = case_when(
      metric6 > 0.67 ~ 5,
      metric6 > 0.33 ~ 3,
      metric6 <= 0.33 ~ 1
    ))
}

#' Add combined IBI score
#'
#' Takes the individual metric scores and combines them to form the final IBI score
#' (continuous)
#'
#' @export
add.fish.ibi <- function(.data){
  .data %>%
    mutate(ibi_score =
             metric1_rating_elev +
             metric2_rating_elev +
             metric3_rating_elev +
             metric4_rating_elev +
             metric5_rating_elev +
             metric1_rating_pene +
             metric2_rating_pene +
             metric3_rating_pene +
             metric4_rating_pene +
             metric5_rating_pene +
             metric6_rating*2)
}

#' Cut IBI score
#'
#' Takes the continuous IBI overall score and cuts it into the three categories
#' originally proposed by Joy and Death (2004)
#'
#' @export
cut.fish.ibi <- function(.data){
  .data %>%
    mutate(ibi_score_cut = cut(ibi_score, breaks = c(0, 20, 40, 60), labels = c("Low quality",
                                                                                "Medium quality",
                                                                                "High quality")))
}