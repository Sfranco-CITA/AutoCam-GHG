Automated Greenhouse Gas Measurement System
===========

Script Name: AutoCam-GHG.R  
Version: 1.0  
Authors: S. Franco-Luesma, M. Alonso-Ayuso, B. Latorre, J. Álvaro-Fuentes
Date: 09/04/2025

DESCRIPTION  
-----------
This R script automates the complete workflow of a greenhouse gas (GHG) measurement system. It orchestrates the operation of suction chambers connected to a Gasera analyzer, precisely controlling solenoid valves via a network-connected multiplexer. The system executes scheduled measurement cycles across multiple chamber groups at 30-minute intervals, triggered at the top and half-hour marks. To ensure data quality, the script integrates real-time rain detection using a CSV data feed from a pluviometer, automatically pausing measurements during rainfall events to maintain the integrity of the GHG readings.

MAIN FUNCTIONALITY  
-------------------
- **Valve Control (HTTP):** Opens/closes individual valves via HTTP to the multiplexer.
- **Chamber Group Control (External):** Open/closes chamber groups using an external command-line tool.
- **Gas Analyzer Communication (Socket):** Sends commands and reads data from the Gasera analyzer.
- **Rain Detection (CSV Analysis):** Monitors rainfall data from a CSV to detect rain.
- **Scheduled Cycles (30-min):** Starts measurements at the hour and half-hour.
- **Repeated Measurements:** Performs multiple measurements per chamber.
- **Real-time Logging:** Saves data with timestamps and rain status to log file.
- **Rain-Triggered Pause:** Stops measurements automatically during rain.

REQUIREMENTS
------------
- **R Environment:** Version 4.x or higher is recommended.
- **R Package:**
    - `httr2`: For sending HTTP requests to the valve multiplexer. Install via `install.packages("httr2")`.
- **External Dependencies:**
    - **Rainfall Data File:** A CSV file (defined by the `rainfall_file` parameter) containing pluviometer readings. The script expects the rainfall data in the last column of this file. Ensure this file is accessible and updated regularly.
    - **Relay Control Executable:** An external command-line program (path defined by `relay_control_exe`) used to control the chamber group relays. This executable must be present at the specified location and be callable by the R `system()` function.
- **Network Configuration:**
    - **Valve Multiplexer:** Must be accessible via HTTP on the network at the IP address specified by the `valve_multiplexer_ip` parameter.
    - **Gasera Analyzer:** Must be reachable via TCP/IP socket connection at the IP address (`gasera_analyzer_ip`) and port (`8888`) defined in the script. Ensure no firewall is blocking this connection.
- **Logging:**
    - Write permissions to create and append to the log file in the script's working directory.

WORKFLOW
--------
1. **Initialization:**
   - Establishes a persistent TCP/IP socket connection with the Gasera GHG analyzer.
   - Sends a command to the Gasera analyzer to stop any ongoing measurements.
   - Uses the external relay control executable to initially open all chamber group relays.
   - Closes all individual solenoid valves connected to the multiplexer via HTTP requests.
   - Opens a single, randomly selected valve to prevent potential gas stagnation within the system lines before the first measurement cycle.

2. **Cyclic Measurements (Initiated at XX:00 and XX:30 CEST):**
   - The script enters a continuous loop, waiting until the next top of the hour or half-hour mark.
   - At the start of each 30-minute cycle:
     - Uses the external relay control executable to open all chamber group relays.
     - Checks for current rainfall using the `rain()` function (analyzing the latest data from the specified CSV file).
     - **If no rain is detected:**
       - Determines the current chamber group to be measured.
       - Uses the external relay control executable to close the relays corresponding to the current `chamber_group`.
       - Closes all individual solenoid valves connected to the multiplexer via HTTP requests.
       - Opens the first valve within the selected chamber group using an HTTP request to the multiplexer.
       - Pauses for a defined duration (40 seconds) to allow the gas lines to be evacuated before measurement.
       - Sends a command to the Gasera analyzer to start a new measurement sequence.
       - Records the start time of the current chamber group measurement cycle.
       - Enters a nested loop to perform `measurements_per_chamber` (5) repetitions for each of the `chambers_per_group` (6) chambers:
         - Waits for a short interval (6 seconds) after the previous valve operation.
         - Calculates and opens the next sequential valve within the current chamber group using an HTTP request to the multiplexer. If it's the last chamber, it cycles back to the first valve of that group for the next repetition.
         - Waits for the defined `measurement_duration` (56 seconds) to allow the Gasera analyzer to complete its measurement.
         - Briefly pauses (4 seconds) for internal processing.
         - Sends a command to the Gasera analyzer to retrieve the measurement data.
         - Reads the single line of measurement data received from the analyzer.
         - Logs the timestamp (UTC), chamber ID, chamber group ID, the raw measurement data, and the current rain status (`rain()`) to the log file.
     - **If rain is detected:**
       - Sends a command to the Gasera analyzer to stop any ongoing measurements.
       - Uses the external relay control executable to open all chamber group relays, effectively stopping measurements across all chambers.
       - Skips the measurement sequence for the current 30-minute cycle.

3. **Cycle Reset:**
   - After completing the measurements for all chambers in a group (or if rain was detected), the script sends a command to the Gasera analyzer to stop measurements.
   - Uses the external relay control executable to open all chamber group relays.
   - Closes all individual solenoid valves connected to the multiplexer via HTTP requests.
   - Opens a single, randomly selected valve.
   - Increments the `chamber_group` variable to move to the next group for the subsequent 30-minute cycle. If the last group was processed, it resets to the `initial_chamber_group`.

4. **Termination:**
   - The script continues this infinite loop until manually stopped. Upon termination, it closes the socket connection to the Gasera analyzer.


OUTPUT  
------
- Log file containing measurements, timestamps, and rain condition metadata.

```
2024-02-01 11:01:57.730504989624 C1 B1 rain=FALSE  ACON 0 1706785295 74-82-8 2.13337 1706785295 7732-18-5 11571.8 1706785295 10024-97-2 0.353235
2024-02-01 11:02:53.7482600212097 C2 B1 rain=FALSE  ACON 0 1706785356 74-82-8 2.09051 1706785356 7732-18-5 13324.5 1706785356 10024-97-2 0.3519
2024-02-01 11:03:49.3220999240875 C3 B1 rain=FALSE  ACON 0 1706785414 74-82-8 2.11028 1706785414 7732-18-5 13514 1706785414 10024-97-2 0.35526
2024-02-01 11:04:46.906142950058 C4 B1 rain=FALSE  ACON 0 1706785471 74-82-8 2.11166 1706785471 7732-18-5 14771.3 1706785471 10024-97-2 0.35538
2024-02-01 11:05:41.9656429290771 C5 B1 rain=FALSE  ACON 0 1706785471 74-82-8 2.11166 1706785471 7732-18-5 14771.3 1706785471 10024-97-2 0.35538

```

NOTES
-----
- This script is designed for continuous, unattended operation. You will need to manually interrupt the script execution (e.g., using Ctrl+C in the R console) to stop it.
- It is crucial to ensure that the rainfall CSV file (defined by `rainfall_file`) is regularly updated by the connected data logger for accurate rain detection. The script relies on the latest data in this file.
- The script assumes that all hardware components (valve multiplexer, Gasera analyzer, and relay controller) are correctly configured, powered on, and reliably reachable on the network at the IP addresses and port specified in the configuration parameters.
- The external relay control executable (defined by `relay_control_exe`) must be located at the specified path and function correctly with the provided command-line arguments (`ID=1 OFF=ALL` and `ID=1 ON=<group_number + 4>`). Verify these commands are appropriate for your relay hardware.
- The Gasera analyzer is expected to respond to the commands sent via the socket connection (`\002 STPM K0 \003`, `\002 STAM K0 23 \003`, `\002 ACON K0 \003`) according to its communication protocol. Consult the Gasera analyzer's documentation for details on these commands and expected responses.
- The timing parameters (delays for line evacuation and measurement duration) are critical for the correct operation of the system. Adjust these values (`measurement_duration`, `Sys.sleep()` calls) based on the specific characteristics of your setup and the Gasera analyzer's requirements.
- The script sets the system timezone to GMT (`Sys.setenv(TZ = "GMT")`) for consistent timestamping in the log file. Be aware of the time difference between GMT and your local time zone (e.g., CEST) when interpreting the log file entries. The script's 30-minute cycles are triggered based on GMT time.
- Error handling is minimal in the current script. For more robust operation, consider adding error handling mechanisms for network connections, file reading, and external command execution.
- The script assumes a specific structure for the rainfall CSV file (rainfall data in the last column). If your file format is different, you will need to adjust the `rain()` function accordingly.
- Ensure that the user running the R script has the necessary permissions to read the rainfall data file, execute the relay control program, and write to the log file.


LICENSE
-------
MIT License


CONTACT  
-------
Samuel Franco Luesma
sfranco@cita-aragon.es
Centro de Investigación y Tecnología Agroalimentaria de Aragón (CITA)
