#' @name osrmRoute
#' @title Get the Shortest Path Between Two Points
#' @description Build and send an OSRM API query to get the travel geometry between two points.
#' This function interfaces the \emph{route} OSRM service. 
#' @param src a numeric vector of identifier, longitude and latitude (WGS84), a 
#' SpatialPointsDataFrame or a SpatialPolygonsDataFrame of the origine 
#' point.
#' @param dst a numeric vector of identifier, longitude and latitude (WGS84), a 
#' SpatialPointsDataFrame or a SpatialPolygonsDataFrame of the destination 
#' point.
#' @param overview "full", "simplified" or FALSE. Add geometry either full (detailed), simplified 
#' according to highest zoom level it could be display on, or not at all. 
#' @param sp if sp is TRUE the function returns a SpatialLinesDataFrame.
#' @return If sp is FALSE, a data frame is returned. It contains the longitudes and latitudes of 
#' the travel path between the two points.\cr
#' If sp is TRUE a SpatialLinesDataFrame is returned. It contains 4 fields : 
#' identifiers of origine and destination, travel time in minutes and travel distance in 
#' kilometers.\cr
#' If overview is FALSE, a named numeric vector is returned. It contains travel time (in minutes) 
#' and travel distance (in kilometers).
#' @examples
#' \dontrun{
#' # Load data
#' data("berlin")
#' 
#' # Travel path between points
#' route <- osrmRoute(src = apotheke.df[1, c("id", "lon","lat")],
#'                    dst = apotheke.df[15, c("id", "lon","lat")])
#' # Display the path
#' plot(route[,1:2], type = "l", lty = 2, asp =1)
#' points(apotheke.df[c(1,15),2:3], col = "red", pch = 20, cex = 1.5)
#' text(apotheke.df[c(1,15),2:3], labels = c("A","B"), pos = 1)
#' 
#' # Travel path between points - output a SpatialLinesDataFrame
#' route2 <- osrmRoute(src = c("A", 13.23889, 52.54250),
#'                     dst = c("B", 13.45363, 52.42926),
#'                     sp = TRUE, overview = "full")
#' 
#' # Display the path
#' library(sp)
#' plot(route2, lty = 1,lwd = 4, asp = 1)
#' plot(route2, lty = 1, lwd = 1, col = "white", add=TRUE)
#' points(x = c(13.23889, 13.45363), y = c(52.54250,52.42926), 
#'        col = "red", pch = 20, cex = 1.5)
#' text(x = c(13.23889, 13.45363), y = c(52.54250,52.42926), 
#'      labels = c("A","B"), pos = 2)
#' 
#' # Input is SpatialPointsDataFrames
#' route3 <- osrmRoute(src = apotheke.sp[1,], dst = apotheke.sp[2,], sp = TRUE)
#' route3@data
#' }
#' @export
osrmRoute <- function(src, dst, overview = "simplified", sp = FALSE){
  tryCatch({
    oprj <- NA
    if(testSp(src)){
      oprj <- sp::proj4string(src)
      src <- src[1,]
      x <- spToDf(x = src)
      src <- c(x[1,1],x[1,2], x[1,3])
    }
    if(testSp(dst)){
      dst <- dst[1,]
      x <- spToDf(x = dst)
      dst <- c(x[1,1],x[1,2], x[1,3])
    }
    
    # build the query
    req <- paste(getOption("osrm.server"),
                 "route/v1/", getOption("osrm.profile"), "/", 
                 src[2], ",", src[3], ";", dst[2],",",dst[3], 
                 "?alternatives=false&geometries=polyline&steps=false&overview=",
                 tolower(overview), sep="")

    # Sending the query
    resRaw <- RCurl::getURL(utils::URLencode(req),
                            useragent = "'osrm' R package")
    # Deal with \\u stuff
    vres <- jsonlite::validate(resRaw)[1]
    if(!vres){
      resRaw <- gsub(pattern = "[\\]", replacement = "zorglub", x = resRaw)
    }
    # Parse the results
    res <- jsonlite::fromJSON(resRaw)
    
    # Error handling
    e <- simpleError(res$message)
    if(res$code != "Ok"){stop(e)}
    
    if (overview == FALSE){
      return(round(c(duration = res$routes$duration/60,
                     distance = res$routes$distance/1000), 2))
    }
    if(!vres){
      res$routes$geometry <- gsub(pattern = "zorglub", replacement = "\\\\",
                                  x = res$routes$geometry)
    }
    # Coordinates of the line
    geodf <- gepaf::decodePolyline(res$routes$geometry)[,c(2,1)]
    
    # Convert to SpatialLinesDataFrame
    if (sp == TRUE){
      routeLines <- sp::Lines(slinelist = sp::Line(geodf[,1:2]),
                              ID = "x")
      routeSL <- sp::SpatialLines(LinesList = list(routeLines),
                                  proj4string = sp::CRS("+init=epsg:4326"))
      df <- data.frame(src = src[1], dst = dst[1],
                       duration = res$routes$legs[[1]]$duration/60,
                       distance = res$routes$legs[[1]]$distance/1000)
      geodf <- sp::SpatialLinesDataFrame(routeSL, data = df, match.ID = FALSE)
      row.names(geodf) <- paste(src[1], dst[1],sep="_")
      if (!is.na(oprj)){
        geodf <- sp::spTransform(geodf, oprj)
      }
      names(geodf)[1:2] <- c("src", "dst")
    }
    return(geodf)
  }, error=function(e) {message("OSRM returned an error:\n", e)})
  return(NULL)
}


