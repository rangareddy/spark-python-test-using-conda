from __future__ import print_function
import os
import sys

def main(SPARK_HOME):

    sys.path.append(os.path.join(os.path.dirname(SPARK_HOME), "dev"))

    from sparktestsupport import SPARK_HOME  # noqa (suppress pep8 warnings)
    from sparktestsupport.shellutils import which, subprocess_check_output  # noqa
    from sparktestsupport.modules import all_modules, pyspark_sql  # noqa

    python_modules = dict((m.name, m) for m in all_modules if m.python_test_goals if m.name != 'root')
    python_modules=" ".join(sorted(python_modules.keys()))
    print(python_modules)
  
if __name__=="__main__":
    args = sys.argv[1:]
    if len(args) != 0:
        SPARK_HOME = args[0]
        if not SPARK_HOME.endswith("/"):
            SPARK_HOME = SPARK_HOME +"/"
            
        main(SPARK_HOME)
    else:
        print("Usage: Pyspark-Module.py <SPARK_HOME>")
        exit(1)