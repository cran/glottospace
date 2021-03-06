
#' Clean glottodata/glottosubdata
#'
#' This function cleans glottodata/glottosubdata and returns a simplified glottodata/glottosubdata object containing only the cleaned data table and a structure table.
#'
#' This function has some built in default values that are being recoded:
#' For example, if column type is 'symm' or 'asymm', values such as "No" and 0 are recoded to FALSE
#' Values such as "?" are recoded to NA.
#'
#'
#' @param glottodata glottodata (either a list or a data.frame)
#' @param tona Optional additional values to recode to NA (besides default)
#' @param tofalse Optional additional values to recode to FALSE (besides default)
#' @param totrue Optional additional values to recode to TRUE (besides default)
#' @param id By default, glottoclean looks for a column named 'glottocode', if the id is in a different column, this should be specified.
#'
#' @return A cleaned-up and simplified version of the original glottodata object
#' @export
#' @examples
#' glottodata <- glottoget("demodata", meta = TRUE)
#' glottodata <- glottoclean(glottodata)
#'
#' glottosubdata <- glottoget("demosubdata", meta = TRUE)
#' glottosubdata <- glottoclean(glottosubdata)
glottoclean <- function(glottodata, tona = NULL, tofalse = NULL, totrue = NULL, id = NULL){

  if(sum(!glottocheck_isglottodata(glottodata) | !glottocheck_isglottosubdata(glottodata))==2){
    stop("glottodata object does not adhere to glottodata/glottosubdata format. Use glottocreate() or glottoconvert().")
  }

  if(!glottocheck_hasstructure(glottodata) ){
    stop("structure table not found. You can create one using glottocreate_structuretable() and add it with glottocreate_addtable().")
  } else{
    structure <- glottodata[["structure"]]
    glottodata <- glottosimplify(glottodata)
  }

  all2false <- glottoclean_all2false()
  all2true <- glottoclean_all2true()
  all2na <- glottoclean_all2na()

  if(!is.null(tona)){all2na <- c(all2na, tona)}
  if(!is.null(tofalse)){all2false <- c(all2false, tofalse)}
  if(!is.null(totrue)){all2true <- c(all2true, totrue)}

  glottodata <- glottorecode_logical(glottodata = glottodata, structure = structure, tofalse = all2false, totrue = all2true)

  glottodata <- glottorecode_missing(glottodata, tona = all2na)

  glottodata <- glottojoin(glottodata, structure)

  glottodata <- contrans_glottoclass(glottodata)

  invisible(glottodata)
}

glottoclean_all2false <- function(){
  c("n", "N", "No", "no", "NO", 0, 0.0, "F", "FALSE", "False", "false", "0", "0.0")
}

glottoclean_all2true <- function(){
  c("y", "Y", "Yes", "yes", "YES", 1, 1.0, "T", "TRUE", "True", "true", "1", "1.0")
}

glottoclean_all2na <- function(){
  c("NA", "N A", "N/A", "#N/A", "NA ", " NA", "N /A", "N / A", " N / A", "N / A ", "na", "n a", "n/a",
    "na ", " na", "n /a", "n / a", " a / a", "n / a ", "NULL", "null", "", "\\?", "\\*", "\\.")
}

#' Recode values across a glottodataset
#'
#' This function recodes values within a glottodataset to NA or TRUE/FALSE. Recoding is done based on column types in the structure table. Run glottocreate_structuretable() to create one.
#'
#' @param glottodata glottodata list
#' @param tona Values to recode to NA
#' @param tofalse Values to recode to FALSE
#' @param totrue Values to recode to TRUE
#' @noRd
#' @family <glottorecode><glottoclean>
#'
#' @examples
#' glottodata <- glottoget("demodata", meta = TRUE)
#' glottodata <- glottorecode(glottodata, tona = c("?", "missing"))
glottorecode <- function(glottodata, structure, tofalse = NULL, totrue = NULL, tona = NULL){

  if(!is.null(tofalse) | !is.null(totrue)){
    glottodata <- glottorecode_logical(glottodata = glottodata, structure = structure, tofalse = tofalse, totrue = totrue)
  }

  if(!is.null(tona)){
    glottodata <- glottorecode_missing(glottodata, tona = tona)
  }

 glottodata
}

#' Recode character columns to TRUE/FALSE
#'
#' @param structure structure table
#' @param totrue values to recode to TRUE
#' @param tofalse values to recode to FALSE
#' @param glottodata glottodata list
#'
#' @noRd
#' @examples
#' glottodata <- glottoget("demodata", meta = TRUE)
#' glottorecode_logical(glottodata, totrue = c("y", "Y", 1), tofalse = c("n", "N", 0), structure = glottodata[["structure"]])
#'
#' glottosubdata <- glottoget("demosubdata", meta = TRUE)
#' glottorecode_logical(glottosubdata, totrue = c("y", "Y", 1), tofalse = c("n", "N", 0), structure = glottosubdata[["structure"]])
glottorecode_logical <- function(glottodata, structure, totrue = NULL, tofalse = NULL){

  data <- glottosimplify(glottodata)

  types <- structure$type
  cbinary <- structure$varname[which(types == "asymm" | types == "symm")]

  if(!purrr::is_empty(cbinary)){
    bindat <- data[, cbinary]
    # Prepare message about what will be converted:
      allevmat <- sapply(lapply(bindat, as.factor), levels)
      allevuniq <- unique(unlist(allevmat))
      notlog <- allevuniq[allevuniq %nin% c(totrue, tofalse)]
      if(!purrr::is_empty(notlog)){
        message("\n\n For some variables of type 'symm' and 'asymm' it is unclear whether they are TRUE or FALSE. \n If you do want to convert them, you should specify 'totrue' and 'tofalse'. \n\n The following values are not converted to TRUE or FALSE, but are set to NA:")
        printmessage(paste(notlog, collapse = ", "))
        bindat <- recode_df(data = bindat, old = notlog, new = NA)
      }
    if(!is.null(totrue)){bindat <- recode_df(data = bindat, old = totrue, new = TRUE) }
    if(!is.null(tofalse)){bindat <- recode_df(data = bindat, old = tofalse, new = FALSE) }
    bindat <- apply(bindat, 2, as.logical)
    data[, cbinary] <- bindat
    message("Values in binary columns (symm/asymm) recoded to TRUE/FALSE \n")
  }
  data
}

#' Recode missing values to NA
#'
#' @param glottodata glottodata
#' @param tona Optional, additional values to recode to NA
#' @family <glottorecode>
#' @noRd
#' @examples
#' glottodata <- glottoget("demodata", meta = TRUE)
#' glottorecode_missing(glottodata, tona = "?")
#'
#' glottosubdata <- glottoget("demosubdata", meta = TRUE)
#' glottorecode_missing(glottosubdata, tona = "?")
glottorecode_missing <- function(glottodata, tona){

  glottodata <- glottosimplify(glottodata)

  glottocols <- colnames(glottodata)
  glottodata <- data.frame(lapply(glottodata, recode_tona, tona = tona)) # As a side-effect, this drops row names, and changes colnames
  colnames(glottodata) <- glottocols


  message("Missing values recoded to NA \n")

  glottodata
}

#' Fix colnames of excel files in which colnames refer to another cell
#'
#' @param glottodata glottodata or glottosubdata
#' @noRd
#'
glottoclean_colnamerepair <- function(glottodata){
  if(glottocheck_isglottodata(glottodata)){
    splitted <- glottosplitmergemeta(glottodata)
    glottodata <- glottoclean_colnamerepair_table(splitted[[1]])
    glottodata <- glottosplitmergemeta(glottodata = glottodata, splitted = splitted)
  } else if(glottocheck_isglottodata(glottodata)){
    splitted <- glottosplitmergemeta(glottodata)
    glottodata <- lapply(splitted[[1]], glottoclean_colnamerepair_table)
    glottodata <- glottosplitmergemeta(glottodata = glottodata, splitted = splitted)
  }
  glottodata
}

glottoclean_colnamerepair_table <- function(table){
  colnames(table) <- gsub("\\...[0-9]*$","",colnames(table))
  table
}
