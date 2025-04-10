################################################################################
# Script Name: AutoCam-GHG.R
# Version: 1.0
# Authors: S. Franco-Luesma, M. Alonso-Ayuso, B. Latorre, J. Álvaro-Fuentes
# Date: 09/04/2025
#
# DESCRIPTION:
# This R script automates the control of a greenhouse gas (GHG)
# measurement system using suction chambers connected to a Gasera
# analyzer and solenoid valves managed via a multiplexer. The system
# performs scheduled measurements from multiple chambers in defined
# time cycles and includes rain detection to ensure measurement integrity.
#
# CONFIGURATION PARAMETERS (Modify these as needed)
################################################################################

# Number of chambers per group (controlled together)
chambers_per_group <- 6
# Total number of chamber groups
chamber_groups <- 3
# Initial group for the measurement cycle
initial_chamber_group <- 1

# Measurement repetitions to perform for each chamber
measurements_per_chamber <- 5
# Gasera measurement cycle in seconds
measurement_duration <- 56

# Threshold for considering it as rain in mm
rain_threshold <- 0.2

# External dependencies
rainfall_file <- "C:/Campbellsci/LoggerNet/CR1000XSeries_Datos_90s.csv"
relay_control_exe <- "\"C:\\Users\\campoMSCG_localAdmin\\Desktop\\programa\\ProjectExes v1.2.1\\RelayCmd.exe\""

# Network configuration
valve_multiplexer_ip <- "192.168.1.101"
gasera_analyzer_ip <- "192.168.1.110"

# Logging
log_file <- "log.txt"

# computer time is GMT
Sys.setenv(TZ = "GMT")

# Check for rain
rain <- function() {
  # Read rainfall data from CSV
  pluvio <- read.csv(rainfall_file, header = FALSE)
  # Select the last column (assuming it contains the rainfall data)
  pluvio <- pluvio[, ncol(pluvio)]
  # Select the last 10 measurements and find the maximum
  pluvio <- max(tail(pluvio, n = 10))
  # Precipitation threshold check
  if (pluvio > rain_threshold) {
    return(TRUE)  # Rain detected
  }
  return(FALSE)  # No rain detected
}

# Valve multiplexer control
library(httr2)
open_valve <- function(id) {
  req <- request(paste0("http://", valve_multiplexer_ip, "/relayOn?id=",
    id))
  req_perform(req)
}
close_valves <- function() {
  id <- 0
  req <- request(paste0("http://", valve_multiplexer_ip, "/relayOff?id=",
    id))
  req_perform(req)
}

# Establish a socket connection to the Gasera analyzer
con <- socketConnection(host = gasera_analyzer_ip, port = 8888, blocking = TRUE,
  server = FALSE, open = "r+", timeout = 5)

# Send command to the Gasera analyzer to stop measurements
write_resp <- writeLines("\002 STPM K0 \003", con)

# Open all chamber groups
date <- as.POSIXlt(Sys.time(), tz = "UTC")
cat(paste0(date, " Opening all chambers\n"))
cmd <- system(paste0(relay_control_exe, " ID=1 OFF=ALL"), intern = TRUE)
Sys.sleep(1)

# Close all valves connected to the multiplexer
date <- as.POSIXlt(Sys.time(), tz = "UTC")
cat(paste0(date, " Closing all valves\n"))
close_valves()

# Open a single random valve
random <- sample(1:(chambers_per_group * chamber_groups), 1)
cat(paste0(date, " Opening random valve ", random, "\n"))
open_valve(random)

# Assign the initial chamber group
chamber_group <- initial_chamber_group

# Perform one chamber group cycle
while (1) {
  # Wait till next 00m or 30m
  t_ini <- as.integer(as.integer(Sys.time())/1800) * 1800 + 1800
  wait <- t_ini - as.integer(Sys.time())
  cat(paste0(date, " Waiting ", as.integer(wait), " seconds to start next chamber group measurement\n"))
  Sys.sleep(wait)

  # Open all chamber groups
  date <- as.POSIXlt(Sys.time(), tz = "UTC")
  cmd <- system(paste0(relay_control_exe, " ID=1 OFF=ALL"), intern = TRUE)
  Sys.sleep(1)

  # Close current chamber group (unless it's raining)
  if (!(rain())) {
    cat(paste0(date, " Closing chamber group ", chamber_group, "\n"))
    cmd <- system(paste0(relay_control_exe, " ID=1 ON=", chamber_group +
      4), intern = TRUE)
    Sys.sleep(1)
  }

  # Close all valves connected to the multiplexer
  date <- as.POSIXlt(Sys.time(), tz = "UTC")
  cat(paste0(date, " Closing all valves\n"))
  close_valves()

  # Open the first valve within the current chamber group
  multiplexer <- (chamber_group - 1) * chambers_per_group + 1
  cat(paste0(date, " Opening valve ", multiplexer, "\n"))
  open_valve(multiplexer)

  # Delay to allow the gas line to evacuate
  Sys.sleep(40)

  # Connect with the analyzer and start measurements (unless it's raining)
  if (!(rain())) {
    write_resp <- writeLines("\002 STAM K0 23 \003", con)
    cmd <- readLines(con, 1)
  }

  # Record the start time of the current measurement group
  t_ini <- as.integer(Sys.time())

  # Measurement repetitions for each chamber
  for (measurement in 1:measurements_per_chamber) {
    # Loop through chambers within the current group
    for (chamber in 1:chambers_per_group) {
      # Wait to ensure suction is complete for the current chamber
      Sys.sleep(6)

      # Determine the valve to open for the next suction
      valve <- multiplexer + chamber
      if (chamber == chambers_per_group) {
        valve <- multiplexer
      }

      # Close all valves connected to the multiplexer
      close_valves()

      # Open next valve
      date <- as.POSIXlt(Sys.time(), tz = "UTC")
      cat(paste0(date, " Opening valve ", valve, "\n"))
      open_valve(valve)  # open valve

      # Calculate the remaining wait time until the expected measurement completion
      wait <- t_ini + (chamber + (measurement - 1) * chambers_per_group) *
        measurement_duration - as.integer(Sys.time())
      cat(paste0(date, " Waiting ", as.integer(wait), " seconds\n"))
      Sys.sleep(wait)

      # Small delay to allow internal processing after measurement
      Sys.sleep(4)

      # Request and read the measurement data
      write_resp <- writeLines("\002 ACON K0 \003", con)
      cmd <- readLines(con, 1)
      date <- as.POSIXlt(Sys.time(), tz = "UTC")
      cat(paste0(date, " C", chamber, " G", chamber_group, " ", cmd,
        "\n"))
      cat(file = log_file, append = TRUE, paste0(date, " C", chamber,
        " G", chamber_group, " rain=", rain(), " ", cmd, "\n"))

  		# If it's raining
      if (rain()) {
        # Send command to the Gasera analyzer to stop measurements
        write_resp <- writeLines("\002 STPM K0 \003", con)

        # Open all chamber groups
        date <- as.POSIXlt(Sys.time(), tz = "UTC")
        cat(paste0(date, " Opening all chambers\n"))
        cmd <- system(paste0(relay_control_exe, " ID=1 OFF=ALL"),
          intern = TRUE)
        Sys.sleep(1)
      }
    }
  }

  # Send command to the Gasera analyzer to stop measurements
  write_resp <- writeLines("\002 STPM K0 \003", con)  # stop analyzer

  # Open all chamber groups
  date <- as.POSIXlt(Sys.time(), tz = "UTC")
  cat(paste0(date, " Opening all chambers\n"))
  cmd <- system(paste0(relay_control_exe, " ID=1 OFF=ALL"), intern = TRUE)
  Sys.sleep(1)

  # Close all valves connected to the multiplexer
  date <- as.POSIXlt(Sys.time(), tz = "UTC")
  cat(paste0(date, " Closing all valves\n"))
  close_valves()

  # Open a single random valve
  random <- sample(1:(chambers_per_group * chamber_groups), 1)
  cat(paste0(date, " Opening random valve ", random, "\n"))
  open_valve(random)

  # Determine the next chamber group
  chamber_group <- chamber_group + 1
  if (chamber_group == chamber_groups + 1) {
    chamber_group <- 1
  }
}

# Close connection to the Gasera analyzer
close(con)
