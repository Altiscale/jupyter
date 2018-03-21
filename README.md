DISCLAIMER
==========
THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS” AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Altiscale BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# Jupyter notebook

This repo includes sample Jupyter notebooks with PySpark and SparkR kernels.

## Installation

An example of instructions can be found here:
https://documentation.altiscale.com/jupyter

The above document provides detailed steps on
* creating a python virtual environment using anconda
* installing Jupyter 
* creating PySpark kernel and integrating with Jupyter notebook
* integrating SparkR to Jupyter notebook

## Files

- alti-jupyter.sh
  - An example script to produce various spark kernels for Jupyter
- pyspark.ipynb 
  - Demos PySpark jobs via Jupyter on Altiscale platform
  - Uses PySpark kernel configured in the above step
- 201508_trip_data.json.gz 
  - Bay Area Bike Share system's [open dataset](http://www.bayareabikeshare.com/open-data).
    By using this dataset for demo or example, you agree the following license [Ford GoBike Data License Agreement](https://assets.fordgobike.com/data-license-agreement.html)
  - Input data for PySpark jobs used in pyspark.ipynb notebook. 
  - Unzip the data once it's downloaded. For ex: ``gunzip 201508_trip_data.json.gz``
- sparkr.ipynb 
  - Demos SparkR jobs via Jupyter on Altiscale platform
  - Uses R kernel integrated with SparkR configuration
- people.json 
  - A sample json file
  - Input data for SparkR jobs used in sparkr.ipynb notebook
- altiscale_logo.png 
  - An example of Altiscale logo accessed in the Jupyter notebooks

