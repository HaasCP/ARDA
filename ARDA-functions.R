## This R script provides functions to import all available raw data recorded with 2D-Agilent systems.
# Author: Christian Haas
# Date: May 2019
##
# Required Libraries ---------------------------------------------

library(tidyverse) # see http://tidyverse.org/
library(XML) # https://cran.r-project.org/web/packages/XML

# Import functions --------------------------------------------------------

importMethod <- function()
{
  methodFiles <- grep("MethodXML", list.files("RUN.M"), value = TRUE)   # finds all files containing the substring "MethodXML" in the subfolder Run.M and returns a vector of strings containing all matching file names
  DADFiles <- grep("1200erDad", methodFiles, value = TRUE)              # identify the xml files correlated to DAD methods
  methodFiles <- setdiff(methodFiles, DADFiles)                         # remove DAD file names from the string vector
  methodList <- list()                                                  # initialize list to be filled in the following for-loop
  for (i in 1:length(methodFiles)) {
    xml <- xmlParse(paste0("RUN.M/", methodFiles[i]))                   # parsing xml file with the name of the indexed entry of the string vector
    methodList[[methodFiles[i]]] <- xmlToDataFrame(xml, nodes = getNodeSet(xml, "//Timetable/TimetableEntry"))  # convert parsed xml file into a data frame using "Timetable" as node and "TimetableEntry" as node-child and add this data frame to the list
  }
  
  #Bring the data frames in the right format
  pumpFiles <- grep("Pump", methodFiles, value = TRUE)                  # identify the xml files correlated to pump methods
  for (i in 1:length(pumpFiles)) {
    methodList[[pumpFiles[i]]][is.na(methodList[[pumpFiles[i]]])] <- ""
    methodList[[pumpFiles[i]]] <- methodList[[pumpFiles[i]]] %>%
      group_by(Time) %>%
      summarise_all(funs(trimws(paste(., collapse = ''))))
    methodList[[pumpFiles[i]]][] <- lapply(methodList[[pumpFiles[i]]], function(x) as.numeric(as.character(x)))
    methodList[[pumpFiles[i]]] <- methodList[[pumpFiles[i]]][order(methodList[[pumpFiles[i]]]$Time), ]
  }
  return(methodList)
}

importDAD <- function()
{
  methodFiles <- grep("MethodXML", list.files("RUN.M"), value = TRUE) # finds all files containing the substring "MethodXML" in the subfolder Run.M and returns a vector of strings containing all matching file names
  DADFiles <- grep("1200erDad", methodFiles, value = TRUE)            # identify the xml files correlated to DAD methods
  DADList <- list()                                                   # initialize list to be filled in the following for-loop
  for (i in 1:length(DADFiles)) {
    xml <- xmlParse(paste0("RUN.M/", DADFiles[i]))                    # parsing xml file with the name of the indexed entry of the string vector
    DADList[[DADFiles[i]]] <- xmlToDataFrame(xml, nodes = getNodeSet(xml, "//Signals/Signal")) # convert parsed xml file into a data frame using "Signals" as node and "Signal" as node-child and add this data frame to the list
  }
  return(DADList)
}

getValveFunc <- function()
{
  methodList <- importMethod()
  inputList <- importMethod()
  
  deck1 <- inputList$AgilentValveDriver1.RapidControl.MethodXML.xml   # which xml file corresponds to the upper parking deck
  deck1 <- data.frame(lapply(deck1, as.character), stringsAsFactors=FALSE)
  main <- inputList$AgilentValveDriver2.RapidControl.MethodXML.xml    # which xml file corresponds to the duo valve in the middle of the parking decks
  main <- data.frame(lapply(main, as.character), stringsAsFactors=FALSE)
  deck2 <- inputList$AgilentValveDriver3.RapidControl.MethodXML.xml   # which xml file corresponds to the lower parking deck
  deck2 <- data.frame(lapply(deck2, as.character), stringsAsFactors=FALSE)
  
  x <- bind_rows(deck1, main, deck2, .id = "id")              # merges the three data frames to one and adds an id column with 1 for deck1, 2 for main, and 3 for deck2
  x$Time <- as.numeric(x$Time)                                # converts the "Time" column in a numeric data type
  x$Position <- as.numeric(x$Position)                        # converts the "Position" column in a numeric data type 
  x <- x[order(x$Time), ]                                     # sorts the data by event time
  if(is_empty(deck1) == TRUE) {                               #assing the correct valves if only valve 1 or valve 3 is used
    for (i in 1:nrow(x)) {
      if(x$id[i] == "1")
        x$id[i] <- "2"
      else
        x$id[i] <- "3"
    }
  }
  
  currPos <- data.frame("deck1" = 1, "main" = 1, "deck2" = 1) # currPos is a data frame which represents the actual position of the three valves assuming an initial state in position 1 for all three valves
  
  valveList <- list("Injections" = data.frame("time" = c(),
                                              "deck" = c(),
                                              "loop" = c()),
                    "Samples" = data.frame("time" = c(),
                                           "deck" = c(),
                                           "loop" = c())
  )                 # initializes list to be filled in the following for-loop
  
  for (i in 1:nrow(x)) {
    if(x$id[i] == 1 && currPos$main == 1 && x$Position[i] != currPos$deck1) {
      valveList$Samples <- data.frame("time" = c(valveList$Samples$time, x$Time[i]),
                                      "deck" = c(valveList$Samples$deck, currPos$main), 
                                      "loop" = c(valveList$Samples$loop, currPos$deck1) 
                                      # sample is stored in the loop from which is switched
      )
    }               # if the upper deck is switched AND the duo valve is in position 1 the valve switch can be assigned as sampling event
    if(x$id[i] == 3 && currPos$main == 2 && x$Position[i] != currPos$deck2) {
      valveList$Samples <- data.frame("time" = c(valveList$Samples$time, x$Time[i]),
                                      "deck" = c(valveList$Samples$deck, currPos$main),
                                      "loop" = c(valveList$Samples$loop, currPos$deck2) 
                                      # sample is stored in the loop from which is switched
      )
    }               # if the lower deck is switched AND the duo valve is in position 2 the valve switch can be assigned as sampling event
    if(x$id[i] == 1 && currPos$main == 2 && x$Position[i] != currPos$deck1) {
      valveList$Injections <- data.frame("time" = c(valveList$Injections$time, x$Time[i]),
                                         "deck" = c(valveList$Injections$deck, 1),
                                         "loop" = c(valveList$Injections$loop, x$Position[i]) 
                                         # sample is injected from the loop to which is switched
      )
    }                # if the upper deck is switched AND the duo valve is in position 2 the valve switch can be assigned as injection event
    if(x$id[i] == 3 && currPos$main == 1 && x$Position[i] != currPos$deck2) {
      valveList$Injections <- data.frame("time" = c(valveList$Injections$time, x$Time[i]),
                                         "deck" = c(valveList$Injections$deck, 2),
                                         "loop" = c(valveList$Injections$loop, x$Position[i]) 
                                         # sample is injected from the loop to which is switched
      )
    }                # if the lower deck is switched AND the duo valve is in position 1 the valve switch can be assigned as injection event
    if(x$id[i] == 1) {
      currPos$deck1 = x$Position[i]
    }
    if(x$id[i] == 2) {
      currPos$main = x$Position[i]
    }
    if(x$id[i] == 3) {
      currPos$deck2 = x$Position[i]
    }
    # updates the current positions of the valves
  }
  
  combined <- data.frame("injection" = c(),
                         "deck" = c(),
                         "loop" = c(),
                         "sample" = c()
  )                 # initializes data frame to be filled in the following for-loop
  
  for (i in 1:nrow(valveList$Samples)) {
    combined <- data.frame(
      "injection" = c(combined$injection, valveList$Injections$time[i]),
      "deck" = c(combined$deck, valveList$Samples$deck[i]),
      "loop" = c(combined$loop, valveList$Samples$loop[i]),
      "sample" = c(combined$sample, valveList$Samples$time[which(valveList$Samples$deck == valveList$Injections$deck[i] & valveList$Samples$loop == valveList$Injections$loop[i])])
    )
  }               # takes the "Injections" data frame and adds a "sample" column with the sampling times corresponding to the respective duo valve position and loop number
  
  valveList$"Combined" <- combined # adds data frame to the existing list
  
  return(valveList)
}

importSignals <- function()
{
  signals <- grep("\\.csv", list.files(), value = TRUE)   # finds all .csv data in the working direcotry (case sensitive, reports are .CSV!)
  
  dataList <- list()                                      # initializes list to be filled in the following for-loop
  
  for (i in 1:length(signals)) {
    rawdata <- read.csv(signals[i], 
                        header=FALSE, stringsAsFactors=FALSE, 
                        fileEncoding="UCS-2LE")
    dataList[[signals[i]]] = rawdata
  }                                                       # reads raw data and adds it to the list
  return(dataList)
}

importInfo <- function()
{
  reports <- grep("\\.CSV", list.files(), value = TRUE)   # finds all .CSV data in the working direcotry (case sensitive, signals are .csv!)
  infoReport <- grep("00", reports, value = TRUE)         # the first report with the counter "00" represents the method information (sample comments included)
  info <- read.delim(infoReport, 
                     header=FALSE, stringsAsFactors=FALSE, 
                     fileEncoding="UCS-2LE")
  return(info)
}

importReports <- function()
{
  reports <- grep("\\.CSV", list.files(), value = TRUE)   # finds all .CSV data in the working direcotry (case sensitive, signals are .csv!)
  
  detectorList <- importDAD()
  activeSignalsDAD1 <- detectorList[[1]] %>%
    filter(UseSignal == "true") %>%
    .$Wavelength
  activeSignalsDAD2 <- detectorList[[2]] %>%
    filter(UseSignal == "true") %>%
    .$Wavelength
  reports <- reports[(2 + length(activeSignalsDAD1)):(1 + length(activeSignalsDAD1) + length(activeSignalsDAD2))] # + Info report
  
  reportList <- list()
  for (i in 1:length(reports)) {
    rawdata <- read.csv(reports[i], 
                        header=FALSE, stringsAsFactors=FALSE, 
                        fileEncoding="UCS-2LE")
    reportList[[as.character(activeSignalsDAD2[i])]] = rawdata
  }
  return(reportList)
}

makeResultTable <- function(reactorVolume)
{
  # Import data
  valve <- getValveFunc()
  methods <- importMethod()
  reports <- importReports()
  
  # Flow rates and reaction times
  flowRate <- c()
  for (i in 1:length(valve$Samples$time)) {
    flowRate <- c(flowRate, methods$AgilentPumpDriver1.RapidControl.MethodXML.xml$Flow[max(which(methods$AgilentPumpDriver1.RapidControl.MethodXML.xml$Time < valve$Samples$time[i]))])
  }
  resultTable <- data.frame("flowRate" = flowRate,
                            "reactTime" = reactorVolume / flowRate)
  
  # Starting concentrations on the reactor
  for (i in 1:length(reactants)) {
    conc <- c()
    for (j in 1:length(valve$Samples$time)) {
      conc <- c(conc, (methods$AgilentPumpDriver1.RapidControl.MethodXML.xml[[paste0("Percent", reactants[[i]]$channel)]][max(which(methods$AgilentPumpDriver1.RapidControl.MethodXML.xml$Time < valve$Samples$time[j]))] * reactants[[i]]$bottleConc / 100))
    }
    resultTable[paste0("conc0", names(reactants)[i])] <- conc
  }
  
  # Reactant concentrations after the reaction
  for (i in 1:length(reactants)) {
    report <- reports[[reactants[[i]]$detectWavelength]]
    expSignals <- data.frame("injectTime" = valve[["Injections"]]$time,
                             "expPeakTime" = valve[["Injections"]]$time + reactants[[i]][["retTime"]])
    if(is_empty(reactants[[i]]$calibFactor)){
      area <- c()
      for (j in 1:length(expSignals$expPeakTime)) {
        rowNum <- which(report$V2 >= expSignals$expPeakTime[j] - 0.1 &
                          report$V2 <= expSignals$expPeakTime[j] + 0.1)
        if(is_empty(rowNum)){
          area <- c(area, 0)
        } else{#
          area <- c(area, report$V5[rowNum])
        }
      }
      toOrder <- data.frame("area" = area,
                            "sampleTime" = valve$Combined$sample)
      toOrder <- toOrder[order(toOrder$sampleTime), ]
      area <- toOrder$area
      resultTable[paste0("area", names(reactants)[i])] <- area
    } else {
      conc <- c()
      for (j in 1:length(expSignals$expPeakTime)) {
        rowNum <- which(report$V2 >= expSignals$expPeakTime[j] - 0.1 &
                          report$V2 <= expSignals$expPeakTime[j] + 0.1)
        if(is_empty(rowNum)){
          conc <- c(conc, 0)
        } else{
          conc <- c(conc, (report$V5[rowNum] / reactants[[i]]$calibFactor))
        }
      }
      toOrder <- data.frame("conc" = conc,
                            "sampleTime" = valve$Combined$sample)
      toOrder <- toOrder[order(toOrder$sampleTime), ]
      conc <- toOrder$conc
      resultTable[paste0("conc", names(reactants)[i])] <- conc
      resultTable["conversion"] <- (1 - resultTable[paste0("conc", names(reactants)[i])] / resultTable[paste0("conc0", names(reactants)[i])]) * 100
    }
  }
  
  # Product areas or concentrations after the reaction
  if(!is_empty(products)) {
    for (i in 1:length(products)) {
      report <- reports[[products[[i]]$detectWavelength]]
      expSignals <- data.frame("injectTime" = valve[["Injections"]]$time,
                               "expPeakTime" = valve[["Injections"]]$time + products[[i]][["retTime"]])
      if(is_empty(products[[i]]$calibFactor)){
        area <- c()
        for (j in 1:length(expSignals$expPeakTime)) {
          rowNum <- which(report$V2 >= expSignals$expPeakTime[j] - 0.11 &
                            report$V2 <= expSignals$expPeakTime[j] + 0.11)
          if(is_empty(rowNum)){
            area <- c(area, 0)
          } else{
            area <- c(area, report$V5[rowNum])
          }
        }
        toOrder <- data.frame("area" = area,
                              "sampleTime" = valve$Combined$sample)
        toOrder <- toOrder[order(toOrder$sampleTime), ]
        area <- toOrder$area
        resultTable[paste0("area", names(products)[i])] <- area
      } else {
        conc <- c()
        for (j in 1:length(expSignals$expPeakTime)) {
          rowNum <- which(report$V2 >= expSignals$expPeakTime[j] - 0.06 &
                            report$V2 <= expSignals$expPeakTime[j] + 0.06)
          if(is_empty(rowNum)){
            conc <- c(conc, 0)
          } else{
            conc <- c(conc, (report$V5[rowNum] / products[[i]]$calibFactor))
          }
        }
        toOrder <- data.frame("conc" = conc,
                              "sampleTime" = valve$Combined$sample)
        toOrder <- toOrder[order(toOrder$sampleTime), ]
        conc <- toOrder$conc
        resultTable[paste0("conc", names(products)[i])] <- conc
      }
    }
  }
  
  # Add loop information
  resultTable["deck"] <- as.character(valve$Samples$deck)
  resultTable["loop"] <- as.character(valve$Samples$loop)
  resultTable["loopID"] <- paste0(valve$Samples$deck, "-", valve$Samples$loop)
  return(resultTable)
}