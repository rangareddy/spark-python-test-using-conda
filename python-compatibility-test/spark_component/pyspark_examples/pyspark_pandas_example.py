from __future__ import print_function
import platform
import pkg_resources
installed_packages = pkg_resources.working_set
installed_packages_list = sorted(["%s==%s" % (i.key, i.version)
   for i in installed_packages])

print("List of Python packages: ", installed_packages_list)

import pandas as pd
from pyspark.sql import SparkSession

spark = SparkSession.builder.appName('PySpark Pandas Example').getOrCreate()

app_name=spark.conf.get("spark.app.name")
python_version=spark.sparkContext.pythonVer
py_version=platform.python_version()
spark_version=spark.version
pandas_version=pkg_resources.get_distribution('pandas').version

print('======== AppName: {}, SparkVersion: {}, PythonVersion={}, PythonMinVersion={} and PandasVersion={} ========'.format(app_name, spark_version, py_version, python_version, pandas_version))

emp_data = {'Id' : [1,2,3], 'Name' : ['"ranga reddy"', '"Nishanth Reddy"', '"Meena P"']}
pdf = pd.DataFrame.from_dict(emp_data)
df = spark.createDataFrame(pdf)
df.show(truncate=False)
spark.stop()

print('------- SparkVersion: {}, PythonVersion={}, PythonMinVersion={} and PandasVersion={} -------'.format(spark_version, py_version, python_version, pandas_version))