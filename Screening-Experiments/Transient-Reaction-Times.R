## This R script provides the reaction times of the transient flow experiments
# attributed to the loop numbers of the parking decks as determined by external calibration.
##

transReactTime <- list(
  # Manual input of the reaction times for each loop, necessary for transient methods
  medium = c(0.39, 0.789, 0.976, 1.32, 1.95), # Loop 1 -> Loop 5
  slow = c(1.95, 2.54, 2.80, 3.30, 3.9) # Loop 1 -> Loop 5
)