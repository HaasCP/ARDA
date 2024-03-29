## This R script provides all required information on the chemicals used in this project.
##
# Chemicals ---------------------------------------------------------------

reactants <- list(
  "NMQ" = list(
    "CAS number" = "606-43-9",
    "detectWavelength" = "328",
    "calibFactor" = 246479,
    "retTime" = 2.8,
    "bottleConc" = 0.05, # mol/L
    "channel" = "B"
  ), 
  "Cou" = list(
    "CAS number" = "91-64-5",
    "detectWavelength" = "280",
    "calibFactor" = 424131,
    "retTime" = 3.6,
    "bottleConc" = 0.1, # mol/L
    "channel" = "C"
  )
)

products <- list(
  "HomoDimNMQ" = list(
    "CAS number" = "",
    "detectWavelength" = "210",
    "calibFactor" = 1704205,
    "retTime" = 6.12
    ),
  
  "HeteroDim" = list(
    "CAS number" = "",
    "detectWavelength" = "210",
    "calibFactor" = NULL,
    "retTime" = 6.97
    ),
  
  "HomoDimCou" = list(
    "CAS number" = "",
    "detectWavelength" = "210",
    "calibFactor" = 1629737,
    "retTime" = 7.75
    )
)
