############################################### word map #########################################################
library(stringr)
library(rgdal)
library(mapview)   # for general plotting
library(leaflet)
library(leaflet.extras)
library(rgeos)
library(spatialEco)
library(sp)
library(RMySQL)
library(plyr)
cities <- readOGR("/home/zoro/MineDeep-master/MineDeep/MineDeep_App/data/shapefiles/", "ne_10m_admin_0_countries")

ydb = dbConnect(MySQL(), user=user, password=password, dbname=dbname, host=host)

rs = dbSendQuery(ydb, "SELECT l.country, l.country_code, count(*) as users_count 
FROM 
	BDSProject.locations as l join 
	BDSProject.users as u on l.user_location=u.user_location
group by l.country, l.country_code;")

locations_data = fetch(rs, n=-1)

locations_data$country[2] <- "Åland"
locations_data$country[9] <- "Antigua and Barb."
locations_data$country[27] <- "Bosnia and Herz."
locations_data$country[37] <- "Cabo Verde"
locations_data$country[38] <- "Central African Rep."
locations_data$country[49] <- "Curaçao"
locations_data$country[52] <- "Dem. Rep. Congo"
locations_data$country[56] <- "Dominican Rep."
locations_data$country[60] <- "Eq. Guinea"
locations_data$country[64] <- "Falkland Is."
locations_data$country[123] <- "Marshall Is."
locations_data$country[151] <- "Palestine"
locations_data$country[157] <- "Pitcairn Is."
locations_data$country[178] <- "Solomon Is."
locations_data$country[182] <- "S. Sudan"
locations_data$country[207] <- "United States of America"
locations_data[,"NAME"] <- locations_data$country
merged <- join(cities@data,locations_data, by="NAME")
cities@data <- merged  
cities@data$users_count[is.na(cities@data$users_count)] <- 0
colnames(cities@data)

pal <- colorQuantile(
  palette = "Reds",
  domain = unique(cities$users_count),
  n=9)

 
leaflet(cities) %>%
  addPolygons(stroke = FALSE, smoothFactor = 0.2, fillOpacity = 1,
              color = ~pal(users_count), popup = ~paste("<h3 style='color:blue'>",cities$NAME,"</h3>","<b>","Users count: ",
                                                         "</b>", cities$users_count, sep= " "))%>%
  addLegend(position = "bottomright", pal = pal, values = ~users_count, 
            labFormat = function(type, cuts, p) {
              n = length(cuts)
              paste0(as.integer(cuts[-n]), " &ndash; ", as.integer(cuts[-1]))
            }
           )
