###########################################################################################################
# Build an SDM (GAM or BRT) by calling buildSDM, return the model object and predictions to withheld
# test data (1 year forecast)
# Contact Barbara.Muhling@noaa.gov
###########################################################################################################

scoreSDM <- function(subObs, sdmType, varNames, targetName, k, tc, lr, max.trees, yrsToForecast, includePersistence) {
  # Define the training and test forecast years
  yrs <- unique(sort(subObs$year)) # Years in the observational dataset
  terminalYr <- max(yrs) - yrsToForecast # The last year of training data 
  train <- subset(subObs, year <= terminalYr)
  test <- subset(subObs, year > terminalYr & year <= (terminalYr + yrsToForecast)) # Observations after the training data ends
  
  # Sometimes a whole year/s of observations is missing (e.g. 2020), or there are very few observations
  # In that case, stop and return NA
  if(nrow(test) < 10) { # Could use another cutoff, here it's 10 observations
    return(NA) # Note! This does not currently test if there's whole years without data, do that below
  }
  
  # Otherwise, build an SDM using helper function
  source("./R/buildSDM.R")
  mod1 <- buildSDM(sdmType = sdmType, train = train, varNames = varNames, targetName = targetName, 
                   k = k, tc = tc, lr = lr, max.trees = max.trees)
  # summary(mod1) # If you want to check convergence etc. But GAMs/BRTs nearly always converge unless parameters v inappropriate
  # gbm.step prints model convergence progress as it goes, so you'll see if the number of trees is too small (< ~ 1500)
  
  # Score the test dataset: the specified years of data following the training data (X year forecast)
  test$pred <- predict(mod1, test, type = "response") 
  
  # If includePersistence is TRUE, calculate the model skill using environmental predictors from the year before
  if(includePersistence == TRUE) {
    newEnvVars <- test[c(grepl("_lag1", colnames(test)))] 
    colnames(newEnvVars) <- gsub("_lag1", "", colnames(newEnvVars))
    newEnvVars$pa <- test$pa
    test$predPersist <- predict(mod1, newEnvVars, type = "response")
  }
  
  # For now, returning model object (which contains the training data), as well as the test/forecast data
  # For a large training dataset, this could result in a very large object though
  out <- list("sdm" = mod1, "test" = test) 
  return(out)
}