# ----------------
# --- PACKAGES ---
#-----------------

# Load packages

require(pacman)
pacman::p_load(data.table, gdata, caTools, plotly, reshape2)
pacman::p_load_gh("luca-scr/smef")


# -----------------
# --- FUNCTIONS ---
# -----------------

# Return statistical mode of v
getmode <- function(v) {
  uniqv <- unique(v)
  uniqv[which.max(tabulate(match(v, uniqv)))]
}


# ---------------
# --- GLOBALS ---
# ---------------

set.seed(100)


# ---------------
# --- DATASET ---
# ---------------

# Load dataset

car_data = fread("./data/car_price_train.csv")

# Dataset info

head(car_data)

dim(car_data)

smef::describe(car_data)

str(car_data)

# List of categorical features

cat_feat <- c('Make', 
              'Model',
              "Engine_Fuel_Type",
              'Transmission_Type', 
              'Driven_Wheels', 
              'Market_Category', 
              'Vehicle_Size', 
              'Vehicle_Style')

# Unique values for categorical features

lapply(car_data[,cat_feat, with=F], unique)

# MSRP distribution

hist(car_data[, MSRP], breaks = 50, main = "Histogram of MSRP", xlab = "MSRP")

# ----------------------------------------------
# --- FEATURE ENGENEERING and MISSING VALUES ---
# ----------------------------------------------

# Count Unknown\unknown values for each categorical feature

lapply(car_data[,cat_feat, with=F], 
       function(col) sum(isUnknown(col, unknown = c("Unknown","unknown"))))
#
# Drop Market Category column (too many Unknown values)

car_data[,Market_Category:=NULL]
head(car_data)

# Drop ID column

car_data[,ID:=NULL]
head(car_data)

# Drop Year column

car_data[,Year:=NULL]
head(car_data)

# Replace *Unknown/unknown* values with *NA*

car_data <- car_data[, lapply(.SD, function(x) replace(x, which(x=="Unknown"), NA))]
car_data <- car_data[, lapply(.SD, function(x) replace(x, which(x=="unknown"), NA))]
sum(is.na(car_data))

# Replace NA values for Engine_Fuel_type and Transmission_type with respective mode value

fuel_transmission_mode = getmode(car_data[,c("Engine_Fuel_Type", "Transmission_Type"), with=F])
car_data <- replace_na(car_data, replace = c(fuel_transmission_mode))
sum(is.na(car_data))

# Split dataset into training and validation set

split <- sample.split(car_data$MSRP, SplitRatio = 0.7)
train_set <- subset(car_data, split == "TRUE")
dim(train_set)
valid_set <- subset(car_data, split == "FALSE")
dim(valid_set)


# --------------------------------
# --- MODEL 1.1: RANDOM FOREST ---
# --------------------------------

# Fit the model using the whole training set

rf_reg = randomForest(x = train_set[, .SD, .SDcols = !'MSRP'],
                      y = train_set[, MSRP],
                      ntree = 10, 
                      nodesize = 1,
                      mtry = dim(train_set)[2] - 1,
                      importance = T)
rf_reg

# Calculate RMSE on train set

y_pred = predict(rf_reg, newdata=train_set[, .SD, .SDcols = !'MSRP'])
rmse(train_set[, MSRP], y_pred)

# Calculate RMSE on validation set

y_pred = predict(rf_reg, newdata = valid_set[, .SD, .SDcols = !'MSRP'])
rmse(valid_set[, MSRP], y_pred)

# Visualize results

hist(valid_set[, MSRP], 
     breaks = 50, 
     col = rgb(0,0,1,1/4), 
     main = "Random Forest",
     xlab = "MSRP")
hist(y_pred, breaks = 50, col=rgb(1,0,0,1/4), add = T)
box()

# Feature Importance (normalized)

feat_imp = randomForest::importance(rf_reg, type=2)
feat_imp <- scale(feat_imp, center=F, scale=colSums(feat_imp))
feat_imp

# Top 10 Features

top_values = feat_imp[order(feat_imp[,1],decreasing=T),][1:10]
top_feat = rownames(feat_imp)[order(feat_imp[,1], decreasing=T)[1:10]]
barplot(height=top_values, names=top_feat, col="#69b3a2", las=2)

# Select topmost numerical features as FEATURES of INTEREST (FOI)

foi = c('Age', 
        'Engine_HP', 
        'Engine_Cylinders', 
        'City_MPG', 
        'Highway_MPG', 
        'Popularity')


# ----------------------------------------------------------
# --- MODEL 1.2: RANDOM FOREST WITH FEATURES of INTEREST ---
# ----------------------------------------------------------

# Prepare Dataset

train_set_foi = train_set[, append(foi, 'MSRP'), with=F]
head(train_set_foi)
valid_set_foi = valid_set[, append(foi, 'MSRP'), with=F]
head(valid_set_foi)

# Fit the model

rf_reg_foi = randomForest(x = train_set_foi[, .SD, .SDcols = !'MSRP'],
                          y = train_set_foi[, MSRP],
                          ntree = 10, 
                          nodesize = 1,
                          mtry = dim(train_set_foi)[2] - 1)
rf_reg_foi

# Calculate RMSE on train set

y_pred = predict(rf_reg_foi, newdata = train_set_foi[, .SD, .SDcols = !'MSRP'])
rmse(train_set_foi[, MSRP], y_pred)

# Calculate RMSE on validation set

y_pred = predict(rf_reg_foi, newdata = valid_set_foi[, .SD, .SDcols = !'MSRP'])
rmse(valid_set_foi[, MSRP], y_pred)

# Visualize results

hist(valid_set[, MSRP], 
     breaks = 50, 
     col = rgb(0,0,1,1/4), 
     main = "Random Forest 2",
     xlab = "MSRP")
hist(y_pred, breaks = 50, col=rgb(1,0,0,1/4), add = T)
box()


# ----------------------------------------------------------------
# --- MODEL 1.3: TUNED RANDOM FOREST with FEATURES of INTEREST ---
# ----------------------------------------------------------------

# Fit the model ...

# rf_reg_2 = train(MSRP ~ .,
#                  data = train_set_foi,
#                  method = 'rf',
#                  tuneGrid = expand.grid(mtry = 1:(dim(train_set_foi)[2] - 1)),
#                  ntree = 10,
#                  nodesize = 5,
#                  trControl = trainControl(method = 'cv',
#                                           number = 10,
#                                           selectionFunction = "oneSE"))
# rf_reg_2

# ... or load trained forest

load("models/m_1_3_tuned_random_forest.RData")
rf_reg_2

# Calculate RMSE on train set

y_pred = predict(rf_reg_2, newdata = train_set_foi[, .SD, .SDcols = !'MSRP'])
rmse(train_set_foi[, MSRP], y_pred)

# Calculate RMSE on validation set

y_pred = predict(rf_reg_2, newdata = valid_set_foi[, .SD, .SDcols = !'MSRP'])
rmse(valid_set_foi[, MSRP], y_pred)

# Visualize results

hist(valid_set[, MSRP], 
     breaks = 50, 
     col = rgb(0,0,1,1/4), 
     main = "Random Forest 3",
     xlab = "MSRP")
hist(y_pred, breaks = 50, col=rgb(1,0,0,1/4), add = T)
box()


# -------------------------------
# --- MODEL 2: NEURAL NETWORK ---
# -------------------------------

# Scale dataset

X_train = train_set_foi[, .SD, .SDcols = !'MSRP']
Y_train = train_set_foi[, MSRP]
dataScaler = caret::preProcess(X_train, method = c("center", "scale"))
X_train_scaled = predict(dataScaler, X_train)
X_valid_scaled = predict(dataScaler, valid_set_foi)
smef::describe(X_train_scaled)
smef::describe(X_valid_scaled)

# Fit the model ...

# nn_reg = train(x = X_train_scaled,
#                y = Y_train,
#                method = "nnet",
#                tuneGrid = expand.grid(decay = c(0.01, 0.1, 1), size = 64),
#                linout = T,
#                maxit = 100,
#                trace = F,
#                trControl = trainControl(method = "cv", 
#                                         number = 10, 
#                                         selectionFunction = "oneSE"))
# nn_reg

# ... or load trained network

load("models/m_2_neural_network.RData")
print(nn_reg)

# Calculate RMSE on train set

y_pred = predict(nn_reg, newdata=X_train_scaled)
rmse(train_set_foi[, MSRP], y_pred)

# Calculate RMSE on validation set

y_pred = predict(nn_reg, newdata = X_valid_scaled)
rmse(valid_set_foi[, MSRP], y_pred)

# Visualize results

hist(valid_set[, MSRP], 
     breaks = 50, 
     col = rgb(0,0,1,1/4), 
     main = "Neural Network",
     xlab = "MSRP")
hist(y_pred, breaks = 50, col=rgb(1,0,0,1/4), add = T)
box()


# ----------------------------------
# --- MODEL 3: LINEAR REGRESSION ---
# ----------------------------------

# Plot Age, Engine_HP and MSRP
  
plot_ly(train_set, x = ~Age, y = ~Engine_HP, z = ~MSRP, size = 1)

# Set an Age threshold

age_ths = 17

# Linear Regression for 'YOUNG' cars

young_train_set = train_set[train_set[, Age < age_ths]]
young_valid_set = valid_set[valid_set[, Age < age_ths]]
young_lin_reg = lm(MSRP ~ Age + Engine_HP + Age:Engine_HP,
                   data = young_train_set)
summary(young_lin_reg)

# Calculate RMSE on training and validation set

y_pred = predict(young_lin_reg, newdata = young_train_set)
rmse(young_train_set[, MSRP], y_pred)
y_pred = predict(young_lin_reg, newdata = young_valid_set)
rmse(young_valid_set[, MSRP], y_pred)

# Visualize results

hist(young_valid_set[, MSRP], 
     breaks = 50, 
     col = rgb(0,0,1,1/4), 
     main = "Linear Regression (Young Cars)",
     xlab = "MSRP")
hist(y_pred, breaks = 50, col=rgb(1,0,0,1/4), add = T)
box()

# Visualize model

graph_res <- 1
axis_x <- seq(0, age_ths, by = graph_res)
axis_y <- seq(min(young_train_set$Engine_HP), max(young_train_set$Engine_HP), by = graph_res)
reg_surface <- expand.grid(Age = axis_x, Engine_HP = axis_y, KEEP.OUT.ATTRS = F)
reg_surface$MSRP <- predict(young_lin_reg, newdata = reg_surface)
reg_surface <- acast(reg_surface, Engine_HP ~ Age, value.var = "MSRP")

young_plot <- plot_ly(young_train_set, x = ~Age, y = ~Engine_HP, z = ~MSRP, type = "scatter3d", size = 1, mode ="markers")
young_plot <- add_trace(young_plot, x = axis_x, y = axis_y, z = reg_surface, type = "surface")
young_plot

# Linear Regression for '*OLD*' cars

old_train_set = train_set[train_set[, Age >= age_ths]]
old_valid_set = valid_set[valid_set[, Age >= age_ths]]
old_lin_reg = lm(MSRP ~ Age + Age:Engine_HP + poly(Engine_HP, 2),
                 data = old_train_set)
summary(old_lin_reg)

# Calculate RMSE on training and validation set

y_pred = predict(old_lin_reg, newdata = old_train_set)
rmse(old_train_set[, MSRP], y_pred)
y_pred = predict(old_lin_reg, newdata = old_valid_set)
rmse(old_valid_set[, MSRP], y_pred)

# Visualize results

hist(old_valid_set[, MSRP], 
     breaks = 20, 
     col = rgb(0,0,1,1/4), 
     main = "Linear Regression (Old Cars)",
     xlab = "MSRP")
hist(y_pred, breaks = 20, col=rgb(1,0,0,1/4), add = T)
box()

# Visualize model

graph_res <- 1
axis_x <- seq(age_ths, max(old_train_set$Age), by = graph_res)
axis_y <- seq(min(old_train_set$Engine_HP), max(old_train_set$Engine_HP), by = graph_res)
reg_surface <- expand.grid(Age = axis_x, Engine_HP = axis_y, KEEP.OUT.ATTRS = F)
reg_surface$MSRP <- predict(old_lin_reg, newdata = reg_surface)
reg_surface <- acast(reg_surface, Engine_HP ~ Age, value.var = "MSRP")

old_plot <- plot_ly(old_valid_set, x = ~Age, y = ~Engine_HP, z = ~MSRP, type = "scatter3d", size = 1, mode ="markers")
old_plot <- add_trace(old_plot, x = axis_x, y = axis_y, z = reg_surface, type = "surface")
old_plot

# Using only Engine_HP
  
old_lin_reg = lm(MSRP ~ poly(Engine_HP, 2),
                 data = old_train_set)
summary(old_lin_reg)

# Calculate RMSE on training and validation set

y_pred = predict(old_lin_reg, newdata = old_train_set)
rmse(old_train_set[, MSRP], y_pred)
y_pred = predict(old_lin_reg, newdata = old_valid_set)
rmse(old_valid_set[, MSRP], y_pred)

# Visualize model

ggplot(data = old_valid_set, aes(x = Engine_HP, y = MSRP)) + geom_point()
ggmatplot(x = old_valid_set$Engine_HP, y = y_pred, add = T, type = "l", col = "red")


# ------------------------
# --- PREDICT TEST SET ---
# ------------------------

# Load test set

car_test = fread("./data/car_price_test.csv")

# Check for missing values in Features of Interest

sum(is.na(car_test[,foi, with = F]))

# MODEL 1.3 : Tuned Random Forest

y_pred_rf = predict(rf_reg_2, newdata=car_test[, foi, with=F])

# Save as csv file

# write.csv(data.frame(ID = car_test$ID, Price = y_pred_rf),
#           row.names = FALSE,
#           file = "./results/Davide_Belfiori_submission1.csv")

# MODEL 2 : Neural Network

car_test_scaled = predict(dataScaler, car_test[, foi, with=F])
y_pred_nn = predict(nn_reg, car_test_scaled)

# Save as csv file

# write.csv(data.frame(ID = car_test$ID, Price = y_pred_nn),
#           row.names = FALSE,
#           file = "./results/Davide_Belfiori_submission2.csv")

# MODEL 3 : Linear Regression

young_car_test = car_test[car_test[, Age < age_ths]]
y_pred_new = predict(young_lin_reg, newdata = young_car_test)
old_car_test = car_test[car_test[, Age >= age_ths]]
y_pred_old = predict(old_lin_reg, newdata = old_car_test)

# Save as csv file

# write.csv(rbind(data.frame(ID = young_car_test$ID, Price = y_pred_new),
#                 data.frame(ID = old_car_test$ID, Price = y_pred_old)),
#           row.names = FALSE,
#           file = "./results/Davide_Belfiori_submission3.csv")

# Compare results

hist(y_pred_rf, 
     breaks = 20, 
     col = rgb(0,0,1,1/4), 
     main = "Summary",
     xlab = "MSRP")
hist(y_pred_nn, breaks = 20, col=rgb(1,0,0,1/4), add = T)
hist(append(y_pred_new, y_pred_old), breaks = 20, col=rgb(0,1,0,1/4), add = T)
box()
