
# initial camera group
camera_group <- 1

# gasera measurement time (in seconds)
t_meas <- 56

# computer time is GMT
Sys.setenv(TZ = 'GMT')

# check for rain
rain <- function()
{
	# read csv
	pluvio <- read.csv('C:/Campbellsci/LoggerNet/CR1000XSeries_Datos_90s.csv', header=FALSE)
	# select last column
	pluvio <- pluvio[ , ncol(pluvio)] 
	# select last 10 measurements
	pluvio <- max(tail(pluvio, n=10))
	# precipitation threshold
	if(pluvio > 0.2) # 0.2mm
	{
		return (TRUE)
	}
	return (FALSE)
}

# multiplexer commands
library(httr2)
openValve <- function(id)
{
	req <- request(paste0("http://192.168.1.101/relayOn?id=", id))
	req_perform(req)
}
closeValves <- function()
{
	id <- 0
	req <- request(paste0("http://192.168.1.101/relayOff?id=", id))
	req_perform(req)
}

# electrovalve relay command
relay_cmd <- '"C:\\Users\\campoMSCG_localAdmin\\Desktop\\programa\\ProjectExes v1.2.1\\RelayCmd.exe" '

# gasera socket connection
con <- socketConnection(host="192.168.1.110", port = 8888, blocking=TRUE, server=FALSE, open="r+", timeout=5)

# stop analyzer
write_resp <- writeLines("\x02 STPM K0 \x03", con) # stop analyzer
#cmd <- readLines(con, 1)

# open all cameras
date <- as.POSIXlt(Sys.time(), tz = "UTC")
cat(paste0(date, " Opening all cameras\n"))
cmd <- system(paste0(relay_cmd, 'ID=1 OFF=ALL'), intern = TRUE) # open all cameras
Sys.sleep(1)

# close all valves
date <- as.POSIXlt(Sys.time(), tz = "UTC")
cat(paste0(date, " Closing all valves\n"))
closeValves()  # close all valves

# open random valve
random <- sample(1:18, 1)
cat(paste0(date, " Opening random valve ", random, "\n"))
openValve(random) # open random valve

while(1)
{
	# Wait till next 00m or 30m
	t_ini <- as.integer(as.integer(Sys.time())/1800)*1800+1800
	wait <- t_ini - as.integer(Sys.time())
	cat(paste0(date, " Waiting ", as.integer(wait), " seconds for next group measurement\n"))
	Sys.sleep(wait)

	# open all cameras
	date <- as.POSIXlt(Sys.time(), tz = "UTC")
	cmd <- system(paste0(relay_cmd, 'ID=1 OFF=ALL'), intern = TRUE) # open all cameras
	Sys.sleep(1)
	
	# close camera group
	if(!(rain()))
	{
		cat(paste0(date, " Closing camera group ", camera_group, "\n"))
		cmd <- system(paste0(relay_cmd, 'ID=1 ON=', camera_group + 4), intern = TRUE) # close camera group i
		Sys.sleep(1)
	}

	# close all valves
	date <- as.POSIXlt(Sys.time(), tz = "UTC")
	cat(paste0(date, " Closing all valves\n"))
	closeValves()  # close all valves

	# open initial valve
	multiplexer  <- (camera_group - 1) * 6 + 1
	cat(paste0(date, " Opening valve ", multiplexer, "\n"))
	openValve(multiplexer) # open valve
	
	# Delay to evacuate the line
	Sys.sleep(40)

	# Connect with the analyzer and start measurements
	if(!(rain()))
	{
		write_resp <- writeLines("\x02 STAM K0 23 \x03", con)
		cmd <- readLines(con, 1)
	}
	
	# group start time
	t_ini <- as.integer(Sys.time())

	# for each measurement
	for (meas in 1:5) 
	{
		# for each camera
		for(camera in 1:6)
		{
			# Delay to finish suction
			Sys.sleep(6)
			
			# advance valve to preare next suction
			valve <- multiplexer + camera
			if(camera == 6)
			{
				valve <- multiplexer
			}
			
			# close all valves
			closeValves()  # close all valves
			
			# open next valve
			date <- as.POSIXlt(Sys.time(), tz = "UTC")
			cat(paste0(date, " Opening valve ", valve, "\n"))
			openValve(valve) # open valve
			
			# wait for the measurement to finish
			wait <- t_ini + ( camera + ( meas - 1 ) * 6 ) * t_meas - as.integer(Sys.time())
			cat(paste0(date, " Waiting ", as.integer(wait), " seconds\n"))
			Sys.sleep(wait)
			
			# Delay to finish processing
			Sys.sleep(4)
			
			# read measurement
			write_resp <- writeLines("\x02 ACON K0 \x03", con)
			cmd <- readLines(con, 1)
			date <- as.POSIXlt(Sys.time(), tz = "UTC")
			cat(paste0(date, " C", camera, " B", camera_group, " ", cmd, "\n"))
			cat(file="prueba_1.txt", append=TRUE, paste0(date, " C", camera, " B", camera_group, " rain=", rain(), " ", cmd, "\n"))
		
			if(rain())
			{
				# stop analyzer
				write_resp <- writeLines("\x02 STPM K0 \x03", con) # stop analyzer
				#cmd <- readLines(con, 1)
				
				# open all cameras
				date <- as.POSIXlt(Sys.time(), tz = "UTC")
				cat(paste0(date, " Opening all cameras\n"))
				cmd <- system(paste0(relay_cmd, 'ID=1 OFF=ALL'), intern = TRUE) # open all cameras
				Sys.sleep(1)
			}
		}
	} 

	# stop analyzer
	write_resp <- writeLines("\x02 STPM K0 \x03", con) # stop analyzer
	#cmd <- readLines(con, 1)

	# open all cameras
	date <- as.POSIXlt(Sys.time(), tz = "UTC")
	cat(paste0(date, " Opening all cameras\n"))
	cmd <- system(paste0(relay_cmd, 'ID=1 OFF=ALL'), intern = TRUE) # open all cameras
	Sys.sleep(1)

	# close all valves
	date <- as.POSIXlt(Sys.time(), tz = "UTC")
	cat(paste0(date, " Closing all valves\n"))
	closeValves()  # close all valves
	
	# open random valve
	random <- sample(1:18, 1)
	cat(paste0(date, " Opening random valve ", random, "\n"))
	openValve(random) # open valve

	# advance group 
	camera_group <- camera_group + 1
	if(camera_group == 4)
	{
		camera_group <- 1
	}
}

close(con)

