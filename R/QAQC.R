#' QAQC
#'
#' Check the imported soil carbon dataset for formatting and entry errors
#'
#' @param file directory to data file
#' @param writeQCreport if TRUE, a text report of the QC output will be written to the outfile. Default is FALSE
#' @param outfile filename of the output file if writeQCreport=TRUE. Default is NULL, and the outfile will be written to the directory where the dataset is stored, and named by the dataset being checked.
#' @export


QAQC <- function(file, writeQCreport=F, outfile=NULL){

  ##### setup #####
  requireNamespace("openxlsx")

  #start error count at 0
  error<-0
  #start note count at 0
  note<-0

  if (writeQCreport==T){
    if (is.null(outfile)){
      outfile<-paste0(dirname(file), "/QAQC/QAQC_", gsub("\\.xlsx", ".txt", basename(file)))
    }
    reportfile<-file(outfile)
    sink(reportfile)
    sink(reportfile, type = c("message"))
  }

  cat("         Thank you for contributing to the ISRaD database! \n")
  cat("                Please review the QAQC report below: \n")
  cat(rep("-", 30),"\n\n")

  cat("\nFile:", basename(file), "\n")

  ##### check file extension #####
  cat("\n\nChecking file type...")
  if(!grep(".xlsx", file)==1){
    cat("\tWARNING: ", file, " is not the corrent file type (shoukd have '.xlsx' extension)");error<-error+1
  }

  ##### check template #####

  cat("\n\nChecking file format compatability with ISRaD templates...")

  # get tabs for data and current template files from R package on github
  tabs_found<-getSheetNames(file)
  template_file_mpi<-system.file("extdata", "Master_template_MPI_v10.xlsx", package = "soilcarbon")
  mpi_tabs<-getSheetNames(template_file_mpi)
  template_file_orig<-system.file("extdata", "Master_template_orig.xlsx", package = "soilcarbon")
  orig_tabs<-getSheetNames(template_file_orig)

  if (all(tabs_found %in% mpi_tabs) & length(tabs_found) == length(mpi_tabs)){
    cat("\n Template format detected: ", basename(template_file_mpi))
    template<-read.soilcarbon(file=template_file_mpi, format = "MPI",template=T)
    template_info_file<-system.file("extdata", "Template_info_MPI_v10.xlsx", package = "soilcarbon")
    cat("\n Template info file to be used for QAQC: ", basename(template_info_file))
    template_info<-lapply(getSheetNames(template_info_file), function(s) read.xlsx(template_info_file , sheet=s))
    names(template_info)<-mpi_tabs
    data<-read.soilcarbon(file, format = "MPI")
    }

  if (all(tabs_found %in% orig_tabs)){
    cat("\n Template format detected: ", basename(template_file_orig))
    template<-read.soilcarbon(file=template_file_orig, format = "orig",template=T)
    template_info_file<-system.file("extdata", "Template_info_orig.xlsx", package = "soilcarbon")
    cat("\n Template info file to be used for QAQC: ", basename(template_info_file))
    template_info<-lapply(getSheetNames(template_info_file), function(s) read.xlsx(template_info_file , sheet=s))
    names(template_info)<-orig_tabs
    data<-read.soilcarbon(file, format = "original")
  }

  if (!all(tabs_found %in% orig_tabs) & !all(tabs_found %in% tabs_found)){
    cat("\tWARNING:  tabs in data file do not match accepted templates. Visit https://powellcenter-soilcarbon.github.io/soilcarbon/ for up to date templates")
  error<-error+1
    }

  ##### check for empty tabs ####
cat("\n\nChecking for empty tabs...")
emptytabs<-names(data)[unlist(lapply(data, function(x) all(is.na(x))))]

if(length(emptytabs)>0){
  cat("\n\tNOTE: empty tabs detected (", emptytabs,")")
  note<-note+1
  }

  ##### check for extra or misnamed columns ####
cat("\n\nChecking for misspelled column names...")
for (t in 1:length(names(data))){
  tab<-names(data)[t]
  cat("\n",tab,"tab...")
  data_colnames<-colnames(data[[tab]])
  template_colnames<-colnames(template[[tab]])

  #compare column names in data to template column names
  notintemplate<-setdiff(data_colnames, template_colnames)
  if (length(notintemplate>0)) {
    cat("\n\tWARNING: column name mismatch template:", notintemplate);error<-error+1
  }
}

  ##### check for missing values in required columns ####
cat("\n\nChecking for missing values in required columns...")
for (t in 1:length(names(data))){
  tab<-names(data)[t]
  cat("\n",tab,"tab...")
  required_colnames<-template_info[[tab]]$Column_Name[template_info[[tab]]$Required=="Yes"]
  missing_values<-sapply(required_colnames, function(c) NA %in% data[[tab]][[c]])
  T %in% unlist(missing_values)

  if (T %in% unlist(missing_values)) {
    cat("\n\tWARNING: missing values where required:", required_colnames[missing_values]);error<-error+1
  }
}

  ##### check levels #####
  cat("\n\nChecking that level names match between tabs...")

  # check site tab #
  cat("\n site tab...")
  if(!all(data$site$entry_name %in% data$metadata$entry_name)){
    cat("\tWARNING: 'entry_name' mismatch between 'site' and 'metadata' tabs");error<-error+1
  }

  # check profile tab #
  cat("\n profile tab...")
  if(!all(data$profile$entry_name %in% data$metadata$entry_name)){
    cat("\n\tWARNING: 'entry_name' mismatch between 'profile' and 'metadata' tabs");error<-error+1
  }
  if(!all(data$profile$site_name %in% data$site$site_name)){
    cat("\n\tWARNING: 'site_name' mismatch between 'profile' and 'site' tabs");error<-error+1
  }

  # check flux tab #
  cat("\n flux tab...")
  if(!all(data$flux$entry_name %in% data$metadata$entry_name)){
    cat("\n\tWARNING: 'entry_name' mismatch between 'flux' and 'metadata' tabs");error<-error+1
  }
  if(!all(data$flux$site_name %in% data$site$site_name)){
    cat("\n\tWARNING: 'site_name' mismatch between 'flux' and 'site' tabs");error<-error+1
  }
  if(!all(data$flux$pro_name %in% data$profile$pro_name)){
    cat("\n\tWARNING: 'pro_name' mismatch between 'flux' and 'profile' tabs");error<-error+1
  }

  # check layer tab #
  cat("\n layer tab...")
  if(!all(data$layer$entry_name %in% data$metadata$entry_name)){
    cat("\n\tWARNING: 'entry_name' mismatch between 'layer' and 'metadata' tabs");error<-error+1
  }
  if(!all(data$layer$site_name %in% data$site$site_name)){
    cat("\n\tWARNING: 'site_name' mismatch between 'layer' and 'site' tabs");error<-error+1
  }
  if(!all(data$layer$pro_name %in% data$profile$pro_name)){
    cat("\n\tWARNING: 'pro_name' mismatch between 'layer' and 'profile' tabs");error<-error+1
  }

  # check interstitial tab #
  cat("\n interstitial tab...")
  if(!all(data$interstitial$entry_name %in% data$metadata$entry_name)){
    cat("\n\tWARNING: 'entry_name' mismatch between 'interstitial' and 'metadata' tabs");error<-error+1
  }
  if(!all(data$interstitial$site_name %in% data$site$site_name)){
    cat("\n\tWARNING: 'site_name' mismatch between 'interstitial' and 'site' tabs");error<-error+1
  }
  if(!all(data$interstitial$pro_name %in% data$profile$pro_name)){
    cat("\n\tWARNING: 'pro_name' mismatch between 'interstitial' and 'profile' tabs");error<-error+1
  }

  # check fraction tab #
  cat("\n fraction tab...")
  if(!all(data$fraction$entry_name %in% data$metadata$entry_name)){
    cat("\n\tWARNING: 'entry_name' mismatch between 'fraction' and 'metadata' tabs");error<-error+1
  }
  if(!all(data$fraction$site_name %in% data$site$site_name)){
    cat("\n\tWARNING: 'site_name' mismatch between 'fraction' and 'site' tabs");error<-error+1
  }
  if(!all(data$fraction$pro_name %in% data$profile$pro_name)){
    cat("\n\tWARNING: 'pro_name' mismatch between 'fraction' and 'profile' tabs");error<-error+1
  }
  if(!all(data$fraction$lyr_name %in% data$layer$lyr_name)){
    cat("\n\tWARNING: 'lyr_name' mismatch between 'fraction' and 'layer' tabs");error<-error+1
  }

  # check incubation tab #
  cat("\n incubation tab...")
  if(!all(data$incubation$entry_name %in% data$metadata$entry_name)){
    cat("\n\tWARNING: 'entry_name' mismatch between 'incubation' and 'metadata' tabs");error<-error+1
  }
  if(!all(data$incubation$site_name %in% data$site$site_name)){
    cat("\n\tWARNING: 'site_name' mismatch between 'incubation' and 'site' tabs");error<-error+1
  }
  if(!all(data$incubation$pro_name %in% data$profile$pro_name)){
    cat("\n\tWARNING: 'pro_name' mismatch between 'incubation' and 'profile' tabs");error<-error+1
  }
  if(!all(data$incubation$lyr_name %in% data$layer$lyr_name)){
    cat("\n\tWARNING: 'lyr_name' mismatch between 'incubation' and 'layer' tabs");error<-error+1
  }

  ##### Summary #####

  cat("\n", rep("-", 20))
  if(error==0){
    cat("\nPASSED! Congratulations!")
  } else {
    cat("\n", error, "WARNINGS need to be fixed\n")
  }
  cat("\nPlease email Grey at greymonroe@gmail.com with and feedback or suggestions")

  ##### Close #####
if (writeQCreport==T){
  sink(type="message")
  sink()
  cat("\nQC report saved to", outfile)
}

return(error)

}

