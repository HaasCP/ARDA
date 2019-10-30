mergeRDS <- function(){
  fileNames <- dir(path = wd)                        # character vector of all file names in the wd
  folders <- grep("\\.D", fileNames, value = T)      # vector reduced to experimental folders
  dataList <- list()                                 # initializes list to be filled in the following for-loop
  
  for (i in 1:length(folders)) {
    setwd(as.character(folders[i]))                         # sets the the wd to the ith folder of the folderlist
    RDS <- read_rds(grep("\\.rds", list.files(), value = T))
    dataList[[grep("\\.rds", list.files(), value = T)]] = RDS
    setwd(wd) 
  }
  
  dataTable <- bind_rows(dataList, .id = "id")            # create the dataTable from the .rds files in the dataList and adding the id of the sample
  return(dataTable)
}