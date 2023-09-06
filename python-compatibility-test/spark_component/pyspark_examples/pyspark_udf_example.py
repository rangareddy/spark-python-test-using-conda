from __future__ import print_function
import platform

import pkg_resources
installed_packages = pkg_resources.working_set
installed_packages_list = sorted(["%s==%s" % (i.key, i.version)
   for i in installed_packages])

print("List of Python packages: ", installed_packages_list)

from pyspark.sql import SparkSession
from pyspark.sql.functions import col, udf
from pyspark.sql.types import StringType

spark = SparkSession.builder.appName('PySpark UDF Example').getOrCreate()

app_name=spark.conf.get("spark.app.name")
python_version=spark.sparkContext.pythonVer
python_release_version=platform.python_version()
spark_version=spark.version

print('------- SparkVersion: {}, PythonVersion={} and PythonReleaseVersion={} Start -------'.format(spark_version, python_version, python_release_version))

emp_schema = ["Num","Name"]
emp_data = [("1", "ranga reddy"),("2", "Nishanth Reddy"),("3", "Meena P")]

df = spark.createDataFrame(data=emp_data,schema=emp_schema)
df.show(truncate=False)

def upperCase(str):
    return str.upper()

# Converting function to UDF
upperCaseUDF = udf(lambda z:upperCase(z),StringType()) 

df.withColumn("Cureated Name", upperCaseUDF(col("Name"))).show(truncate=False)

spark.stop()

print('------- SparkVersion: {}, PythonVersion={} and PythonReleaseVersion={} End -------'.format(spark_version, python_version, python_release_version))
