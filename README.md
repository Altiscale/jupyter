# Jupyter notebook

This repo includes sample Jupyter notebooks with PySpark and SparkR kernels.

## Installation

https://documentation.altiscale.com/jupyter

The above document provides detailed steps on
* creating a python virtual environment using anconda
* installing Jupyter 
* creating PySpark kernel and integrating with Jupyter notebook
* integrating SparkR to Jupyter notebook

## Files

- pyspark.ipynb 
  - Demos PySpark jobs via Jupyter on Altiscale platform
  - Uses PySpark kernel configured in the above step
- 201508_trip_data.json.gz 
  - Bay Area Bike Share system's [open dataset](http://www.bayareabikeshare.com/open-data).
  - Input data for PySpark jobs used in pyspark.ipynb notebook. 
  - Unzip the data once it's downloaded. For ex: ``gunzip 201508_trip_data.json.gz``
- sparkr.ipynb 
  - Demos SparkR jobs via Jupyter on Altiscale platform
  - Uses R kernel integrated with SparkR configuration
- people.json 
  - A sample json file
  - Input data for SparkR jobs used in sparkr.ipynb notebook

## Author

- Bala Krishna Gangisetty (bala@altiscale.com)




