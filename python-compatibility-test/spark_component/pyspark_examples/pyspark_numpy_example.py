from __future__ import print_function
import platform
import pkg_resources
installed_packages = pkg_resources.working_set
installed_packages_list = sorted(["%s==%s" % (i.key, i.version)
   for i in installed_packages])

print("List of Python packages: ", installed_packages_list)

import numpy as np
from pyspark.sql import SparkSession

spark = SparkSession.builder.appName('PySpark Numpy Example').getOrCreate()

app_name=spark.conf.get("spark.app.name")
python_version=spark.sparkContext.pythonVer
py_version=platform.python_version()
spark_version=spark.version
numpy_version=pkg_resources.get_distribution('numpy').version

print('======== AppName: {}, SparkVersion: {}, PythonVersion={}, PythonMinVersion={} and NumpyVersion={} ========'.format(app_name, spark_version, py_version, python_version, numpy_version))

def mult(x):
    y = np.array([2])
    return x*y

x = np.arange(1000)
distData = spark.sparkContext.parallelize(x)
count=distData.map(mult).count()
print("Numpy Count: " + str(count))
spark.stop()

print('------- SparkVersion: {}, PythonVersion={}, PythonMinVersion={} and NumpyVersion={} -------'.format(spark_version, py_version, python_version, numpy_version))