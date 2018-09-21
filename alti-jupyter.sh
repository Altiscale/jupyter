#!/bin/bash

# This script sets up Jupyter on behalf of a user.
# Dependencies:
#   conda virtualenv with jupyter, ipython, R modules installed in a known place,
#   typically /opt. See variables below as to how to point to this conda install.
#
# usage:
# alti-jupyter.sh [-hsrx]
# 
# ----------


# ------------

ALTI_JUPYTER_VERSION="0.3.1"

function version() {
    echo "Version $ALTI_JUPYTER_VERSION"
}

function usage() {
    # Output script usage.

    version
    cat << EOF
    Usage: ${0##*/} OPTIONS

    This is a convenience script from Altiscale intended to help set up and run Jupyter for users.

    OPTIONS:

        -s  Setup Jupyter configs in the home directory for the user invoking this script.
	    Creates a kernel called "pyspark" with default settings that uses the Altiscale 
	    supplied conda/python2.7 environment.

        -r  invoke Jupyter notebook. Assumes setup has been run first.

        -t  <Options to pass onto Spark>    Like -s but also accepts a string that is added to Jupyter's
					    pyspark_submit arguments when it's invoked.
					    eg. -t "--executor-memory 1G --queue production --num-executors 3"

	-k <Custom Conda Virtual Environmant>

	   Set up user supplied conda environment for PySpark. This assumes the user has created a conda custom 
	   environment called <Custom Conda Virtual Environmant> set up in the user's home directory. 
	   There's a specific layout that's required. For more info, please look at http://documentation.altiscale.com/jupyter.

	   It sets up Jupyter configs such that:
	   	- a custom Jupyter kernel called custom-<Custom Conda Virtual Environmant Name> is created
		- If the custom kernel is selected, Jupyter will deploy PySpark onto the cluster using this 
		  particular user created conda virtual environment.

	   If the "-t <Options to pass onto Spark>" option is invoked together with "-k", the Spark options
	   are added to the custom kernel config.
        
        -d <Spark Version>   Setup a jupyter kernel for specified spark version. eg. -d 1.6.2  
                             Run "ll -d /opt/alti-spark*" to know the list of available Spark versions. 

        -h  Show help message.
	-v  Show version
        -x  run verbosely (for debugging)
EOF
}

# --------

# CMD Arguments
ALTI_JUPYTER_SETUP=
ALTI_JUPYTER_PYSPARK_ADDENDUM=
ALTI_JUPYTER_LAUNCH=

#
# Option Parsing

while getopts "hsrxvt:k:d:" OPTION; do

    case $OPTION in
	s) ALTI_JUPYTER_SETUP=1
	   ;;
	r) ALTI_JUPYTER_LAUNCH=1
	   ;;
	t) ALTI_JUPYTER_SETUP=1
	   ALTI_JUPYTER_PYSPARK_ADDENDUM=$OPTARG
	   echo "Alti_jupyter_pyspark_addendum: $ALTI_JUPYTER_PYSPARK_ADDENDUM"
	   ;;
	k) ALTI_JUPYTER_SETUP=1
	   JUPYTER_KERNEL_NAME="custom-$OPTARG"
	   CONDA_CUSTOM_VENVNAME=$OPTARG
	   ;;
	d) ALTI_JUPYTER_SETUP=1
	   JUPYTER_KERNEL_NAME="Pyspark-$OPTARG"
	   JUPYTER_KERNEL_DISPLAY_NAME="Pyspark ($OPTARG)"
	   SPARK_VERSION=$OPTARG
	   ;;
	h) usage
	   exit 0
	   ;;
	x) set -x ; 
	   ;;
	v) version
	   exit 0
	   ;;
	*) echo 'Invalid option.' 1>&2
	   usage 1>&2
	   exit 1
	   ;;
    esac
done

# When user provides -k and -d options, set the kernel name and display name according to -k option
if [ ! -z "$CONDA_CUSTOM_VENVNAME" ]; then
  # set the kernel name again incase -d option overwrites it
  JUPYTER_KERNEL_NAME=$K_JUPYTER_KERNEL_NAME
  # unset the display name so that default value take care of
  # setting the correct display name
  unset JUPYTER_KERNEL_DISPLAY_NAME
fi

# ---------------
# Global Variables

# anaconda virtualenv location
CONDA_VENVLOC=${CONDA_VENVLOC:-"/opt/anaconda2"}
CONDA_VENVNAME=${CONDA_VENVNAME:-"py27"}
CONDA_VENVPYTHON=$CONDA_VENVLOC/envs/$CONDA_VENVNAME/bin/python

# files and directories touched by this script
JUPYTER_LOCALCACHE_DIR=$HOME/.local

# "pyspark" is a reserved kernel name used by Altiscale supplied conda environment
JUPYTER_KERNEL_NAME=${JUPYTER_KERNEL_NAME:-"pyspark"}
JUPYTER_KERNEL_SETUP_FILE=$HOME/.ipython/profile_$JUPYTER_KERNEL_NAME/startup/00-setup.py
JUPYTER_KERNEL_DIR=$HOME/.ipython/kernels

PYSPARK_KERNEL_DIR=$JUPYTER_KERNEL_DIR/$JUPYTER_KERNEL_NAME
PYSPARK_KERNEL_FILE=$PYSPARK_KERNEL_DIR/kernel.json

JUPYTER_NOTEBOOK_CONFIG=$HOME/.jupyter/jupyter_notebook_config.py

export SPARK_VERSION=${SPARK_VERSION:-"1.6.1"}

# ------------

function checkRetVal() {

    # check exit codes
    RETVAL=$?
    if [ $RETVAL -ne 0 ]; then
	echo "Error: completed with non zero exit code of $RETVAL"
	exit 1
    fi
}

# ------------

function checkAndSetSparkEnv() {
    # first, figure out Spark version on this workbench
    echo "Checking Spark version"
    if [[ ! $SPARK_VERSION =~ 1\.6\.? ]] && [[ ! $SPARK_VERSION =~ 2\.0\.[012] ]] && [[ ! $SPARK_VERSION =~ 2\.1\.1 ]]; then
	echo "ERROR - Invalid Spark version: $SPARK_VERSION"
        echo "Use one of the installed Spark versions on the cluster, verify \"ll -d /opt/alti-spark*\""
	exit 1
    else
	echo "Spark version is $SPARK_VERSION"
    fi
    
    MY_SPARK_CONF_DIR=${SPARK_CONF_DIR}
    if [ -z "$MY_SPARK_CONF_DIR" ]; then
        MY_SPARK_CONF_DIR=/etc/alti-spark-${SPARK_VERSION}
        SPARK_CONF_DIR=$MY_SPARK_CONF_DIR
    fi
    # This sets things like SPARK_VERSION, SPARK_HOME and HIVE_HOME all of which
    # are needed just belowa
    if [ ! -f $MY_SPARK_CONF_DIR/spark-env.sh ] ; then
	2>&1 echo "ERROR - you must include spark-env.sh in your own spark config directory"
	2>&1 echo "ERROR - you can simply copy and modify it from /etc/spark/spark-env.sh"
    fi
    unset SPARK_HOME
    source $MY_SPARK_CONF_DIR/spark-env.sh
    checkRetVal
    
}

# ----------

function altiJupyterSetup() {
    
    checkAndSetSparkEnv
    
    # run init Spark script
    echo "Running init spark script at $SPARK_HOME/test_spark/init_spark.sh"
    source $SPARK_HOME/test_spark/init_spark.sh
    
    SCALA_VERSION=${SCALA_VERSION:-"2.10"}
    spark_version=$SPARK_VERSION
    
    if [[ $spark_version == 2.* ]] ; then
	SCALA_VERSION="2.11"
	echo "ok - Scala version requires 2.11+ for Spark $spark_version, setting to $SCALA_VERSION"
    fi
    
    #sparksql_hivejars="$SPARK_HOME/lib/spark-hive_$SCALA_VERSION.jar"
    #sparksql_hivethriftjars="$SPARK_HOME/lib/spark-hive-thriftserver_$SCALA_VERSION.jar"
    
    #hive_jars=$sparksql_hivejars,$sparksql_hivethriftjars,$(find $HIVE_HOME/lib/ -type f -name "*.jar" | tr -s '\n' ',' | tr -s '//' '/') 

    # Avoid any jars from Hive that contain HttpServletResponse
    hive_jars_colon=$(find $HIVE_HOME/lib/ -type f -name "*.jar" | grep -v servlet | grep -v hive-jdbc-.*-standalone.jar | tr -s '\n' ':' | tr -s '//' '/')
    
    # Default values
    spark_hive_conf="--driver-class-path $MY_SPARK_CONF_DIR/hive-site.xml:$hive_jars_colon --files $MY_SPARK_CONF_DIR/hive-site.xml,$hive_jars"
    
    if [ -f $SPARK_HOME/test_spark/deploy_hive_jar.sh ] ; then
	$SPARK_HOME/test_spark/deploy_hive_jar.sh
    else
	2>&1 echo "ERROR - Your Spark installation for $spark_version is NOT Complete!!"
	2>&1 echo "ERROR - Either someone from your organization modified the $spark_version or you are on an older version!!"
	exit -1
    fi

    
    
    # -----------
    # need to delete ~/.local if it exists or these changes will not be captured by jupyter
    if [ -d $JUPYTER_LOCALCACHE_DIR ]; then
	# directory exists
	echo "** WARNING! ** "
	echo "You have possible previous Jupyter/iPython values cached in $JUPYTER_LOCALCACHE_DIR"
	echo "Please delete this directory by running \"rm -r $JUPYTER_LOCALCACHE_DIR"\"
	echo "Otherwise changes made by this script will not take effect."
	echo -n "OK to continue? [Y/N] "
	read response
	
	# convert to lowercase
	lc_response=`echo "$response" | awk '{print tolower($0)}'`
	if [ "$lc_response" = "n" -o "$lc_response" = "no" ]; then
	    echo "You've elected to not continue. Quitting"
	    exit 1
	    # /bin/rm -rf $JUPYTER_LOCALCACHE_DIR
	fi
    fi
    
    # activate the special conda virtual env
    echo "Activating the conda virtual environment"
    source $CONDA_VENVLOC/bin/activate $CONDA_VENVNAME
    checkRetVal
    
    # create the pyspark profile for the user
    echo "creating the $JUPYTER_KERNEL_NAME profile"
    ipython profile create $JUPYTER_KERNEL_NAME
    checkRetVal
    
    # we create $JUPYTER_KERNEL_SETUP_FILE next but do check first to see if this
    # file exists
    
    if [ -e $JUPYTER_KERNEL_SETUP_FILE ]; then
	echo "making a backup of $JUPYTER_KERNEL_SETUP_FILE"
	/bin/mv -f $JUPYTER_KERNEL_SETUP_FILE "$JUPYTER_KERNEL_SETUP_FILE.bak"
	checkRetVal
    fi
    
    # find the py4j lib relative path
    PY4J_LIB_LOC=$(find -L $SPARK_HOME -name *py4j*.zip -printf "%P")
    if [ -z $PY4J_LIB_LOC ]; then
        echo "py4j library is not found"
        checkRetVal
    fi

    # create pyspark setup file
    cat <<EOF > $JUPYTER_KERNEL_SETUP_FILE
import os     
import sys    

spark_home = os.environ.get('SPARK_HOME', None)
sys.path.insert(0, os.path.join(spark_home, 'python'))
sys.path.insert(0, os.path.join(spark_home, '$PY4J_LIB_LOC'))
execfile(os.path.join(spark_home, 'python/pyspark/shell.py'))
EOF

    # create the kernel directory
    echo "Creating $JUPYTER_KERNEL_DIR"
    if  [ ! -d $JUPYTER_KERNEL_DIR ]; then
	/bin/mkdir -p $JUPYTER_KERNEL_DIR
	checkRetVal
    fi
    
    echo "Creating $PYSPARK_KERNEL_DIR"
    if  [ ! -d $PYSPARK_KERNEL_DIR ]; then
	/bin/mkdir -p $PYSPARK_KERNEL_DIR
	checkRetVal
    fi
    
    # check Spark version and generate config 
    if [[ $spark_version == 2\.[123]\.? ]]; then
        spark_hive_conf="--driver-class-path $MY_SPARK_CONF_DIR/hive-site.xml:$hive_jars_colon --conf spark.executor.extraClassPath=./hive/* --conf spark.yarn.dist.archives=hdfs:///user/$USER/apps/hive-1.2.1-lib.zip#hive"
    else
        spark_hive_conf="--driver-class-path $MY_SPARK_CONF_DIR/hive-site.xml:$hive_jars_colon --conf spark.executor.extraClassPath=./hive/* --files $MY_SPARK_CONF_DIR/hive-site.xml --conf spark.yarn.dist.archives=hdfs:///user/$USER/apps/hive-1.2.1-lib.zip#hive"
    fi
    
    # ------------------
    # create kernel file
    
    if [[ -z "$CONDA_CUSTOM_VENVNAME" ]] ; then
	echo "Creating default $PYSPARK_KERNEL_FILE"
	cat <<EOF > $PYSPARK_KERNEL_FILE
{
"display_name": "${JUPYTER_KERNEL_DISPLAY_NAME:-PySpark kernel=$JUPYTER_KERNEL_NAME (Spark $spark_version)}",
"language": "python",
"argv": [
  "$CONDA_VENVPYTHON",
  "-m",
  "ipykernel",
  "--profile=$JUPYTER_KERNEL_NAME",
  "-f",
  "{connection_file}"
],
"env": {
  "SPARK_HOME": "$SPARK_HOME",
  "SPARK_CONF_DIR": "$MY_SPARK_CONF_DIR",
  "PYSPARK_PYTHON": "/opt/rh/python27/root/usr/bin/python",
  "PYSPARK_DRIVER_PYTHON": "/usr/bin/python",
  "PYSPARK_SUBMIT_ARGS": "--master yarn --deploy-mode client --conf spark.executor.extraLibraryPath=/opt/rh/python27/root/usr/lib64 --driver-java-options '-XX:MaxPermSize=1024M -Djava.library.path=/opt/hadoop/lib/native/' $spark_hive_conf $ALTI_JUPYTER_PYSPARK_ADDENDUM pyspark-shell"
}
}
EOF
	
	checkRetVal
	
    else

	#
	if [ ! -e "$HOME/$CONDA_CUSTOM_VENVNAME.zip" ]; then
	    echo "Can't find $HOME/$CONDA_CUSTOM_VENVNAME.zip"
	    exit 1
	fi

	CONDA_CUSTOM_VENVPYTHON="$HOME/$CONDA_CUSTOM_VENVNAME/bin/python"
	if [ ! -e $CONDA_CUSTOM_VENVPYTHON ]; then
	    echo "Can't find $CONDA_CUSTOM_VENVPYTHON"
	    exit 1
	fi

	anaconda_venvpython="./ANACONDA/$CONDA_CUSTOM_VENVNAME/bin/python"
	anaconda_venvpython_home="$HOME/ANACONDA/$CONDA_CUSTOM_VENVNAME/bin/python"
	if [ ! -e $anaconda_venvpython_home ]; then
	    echo "Can't find $anaconda_venvpython_home"
	    exit 1
	fi
        # Check Spark version and generate config. Note that --archives override spark.yarn.dist.archives
        if [[ $spark_version == 2\.[123]\.? ]]; then
            spark_hive_conf="--driver-class-path /etc/spark/hive-site.xml:$hive_jars_colon --conf spark.executor.extraClassPath=./hive/*"
        else
            spark_hive_conf="--driver-class-path /etc/spark/hive-site.xml:$hive_jars_colon --conf spark.executor.extraClassPath=./hive/* --files /etc/spark/hive-site.xml"
        fi
	echo "Creating custom $PYSPARK_KERNEL_FILE, spark python runtime path is $anaconda_venvpython"
	cat <<EOF > $PYSPARK_KERNEL_FILE
{	
"display_name": "${JUPYTER_KERNEL_DISPLAY_NAME:-PySpark kernel=$JUPYTER_KERNEL_NAME (Spark $spark_version)}",
"language": "python",
"argv": [
  "$CONDA_CUSTOM_VENVPYTHON",
  "-m",
  "ipykernel",
  "--profile=$JUPYTER_KERNEL_NAME",
  "-f",
  "{connection_file}"
],
"env": {
  "SPARK_HOME": "$SPARK_HOME",
  "SPARK_CONF_DIR": "$MY_SPARK_CONF_DIR",
  "PYSPARK_PYTHON": "$anaconda_venvpython",
  "PYSPARK_DRIVER_PYTHON": "$anaconda_venvpython",
  "PYSPARK_SUBMIT_ARGS": "--master yarn --deploy-mode client --archives hdfs:///user/$USER/apps/hive-1.2.1-lib.zip#hive,./$CONDA_CUSTOM_VENVNAME.zip#ANACONDA --conf spark.yarn.appMasterEnv.PYSPARK_PYTHON=$anaconda_venvpython --driver-java-options '-XX:MaxPermSize=1024M -Djava.library.path=/opt/hadoop/lib/native/' $spark_hive_conf $ALTI_JUPYTER_PYSPARK_ADDENDUM pyspark-shell"
}
}
EOF
	checkRetVal
    fi
  
    # -- generate jupyter config
    echo "Generating Jupyter config"
    
    # first need to do an overwrite check for $JUPYTER_NOTEBOOK_CONFIG
    if [ -e $JUPYTER_NOTEBOOK_CONFIG ]; then
	echo "making a backup of Jupyter config $JUPYTER_NOTEBOOK_CONFIG"
	/bin/mv -f $JUPYTER_NOTEBOOK_CONFIG "$JUPYTER_NOTEBOOK_CONFIG.bak"
	checkRetVal
    fi
    
    jupyter notebook --generate-config
    checkRetVal
    
    # need to make a modification to the jupyter notebook config file
    echo "Modifying $JUPYTER_NOTEBOOK_CONFIG"
    if [ ! -e $JUPYTER_NOTEBOOK_CONFIG ]; then
	echo "Can't find $JUPYTER_NOTEBOOK_CONFIG!"
	exit 1
    fi
    
    # c.NotebookApp.ip = 'localhost'
    sed -i.bak "s#\#[[:space:]]*c.NotebookApp.ip = 'localhost'#c.NotebookApp.ip = '*'#" $JUPYTER_NOTEBOOK_CONFIG

    # c.NotebookApp.open_browser = True
    sed -i.bak "s#\#[[:space:]]*c.NotebookApp.open_browser = True#c.NotebookApp.open_browser = False#" $JUPYTER_NOTEBOOK_CONFIG

    checkRetVal

  
    # deactivate
    echo "Deactivating virtualenv"
    source $CONDA_VENVLOC/bin/deactivate
}

# ------------

# launch jupyter
function altiJupyterLaunch() {
    
    # first - activate the special conda virtual env
    echo "Activating the conda virtual environment"
    source $CONDA_VENVLOC/bin/activate $CONDA_VENVNAME
    checkRetVal
    
    # next, launch actual jupyter notebook
    echo "Launching Jupyter notebook"
    jupyter notebook
    
    # deactivate
    echo "Deactivating virtualenv"
    source $CONDA_VENVLOC/bin/deactivate
    
}

# ------------

function main() {
    
    if [[ ! -z "$ALTI_JUPYTER_SETUP" ]]; then
	altiJupyterSetup
    elif [[ ! -z "$ALTI_JUPYTER_LAUNCH" ]]; then
	altiJupyterLaunch
    else
	usage
	exit 1001
    fi
    
}


# We don't want to call main, if this file is being sourced.
if [[ $BASH_SOURCE == $0 ]]; then
  main
fi
