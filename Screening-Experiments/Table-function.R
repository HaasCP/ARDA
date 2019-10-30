library(devtools)

makeRDS <- function() {
  fileNames <- dir(path = wd)                        # character vector of all file names in the wd
  folders <- grep("\\.D", fileNames, value = T)      # vector reduced to experimental folders
  
  for (i in 1:length(folders)) {
    setwd(as.character(folders[i]))                         # sets the the wd to the ith folder of the folderlist
    resultTable <- makeResultTable(reactorVolume = 0.39)    # creates result table for the ith experiment
    resultTable$reactTime <- c(transReactTime$medium, transReactTime$slow)  # pastes the calibrated reaction times of the transient experiments
    name <- as.character(folders[i])                                      # folder name
    saveRDS(resultTable, paste0(substr(name, 1,nchar(name)-2), ".rds") )  # save the result table as rds file with the name of the sample
    setwd(wd)                                                             # reset the wd to the main folder
  }
}
