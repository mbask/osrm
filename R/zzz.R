.onAttach <- function(libname, pkgname) {
  packageStartupMessage("Data: (c) OpenStreetMap contributors, ODbL 1.0 - http://www.openstreetmap.org/copyright")
  packageStartupMessage("Routing: OSRM - http://project-osrm.org/")
  options(osrm.server = "http://router.project-osrm.org/", osrm.profile = "driving")
  # options(osrm.server = "http://0.0.0.0:5000/", osrm.profile = "driving")
}

