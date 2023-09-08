import sys
import os
import re
import random

cwd = os.getcwd()

python_versions = ["2.7", "3.4", "3.5", "3.6", "3.7", "3.8", "3.9", "3.10", "3.11"]
python_modules  = ["pyspark-core", "pyspark-sql", "pyspark-streaming", "pyspark-mllib", "pyspark-ml"]
spark_submit_examples = ['UDF_Example', 'Pandas_Example', 'Numpy_Example']
spark2_versions = ["2.3.0","2.3.1","2.3.2","2.3.3","2.3.4","2.4.0","2.4.1","2.4.2","2.4.3","2.4.4","2.4.5","2.4.6","2.4.7","2.4.8"]
spark3_versions = ["3.0.0","3.0.1","3.0.2","3.0.3","3.1.1","3.1.2","3.1.3","3.2.0","3.2.1","3.2.2","3.2.3","3.3.0","3.3.1","3.3.2","3.4.0","3.4.1"]
spark_versions  = []
spark_versions.extend(spark2_versions)
spark_versions.extend(spark3_versions)
#spark_versions  = ["2.3.0"]

def check_file_or_directory_exists(file_path):
    return os.path.exists(file_path)

def get_directory_path(directory_path, folder_name):
    file_path = os.path.join(directory_path, folder_name)
    if not check_file_or_directory_exists(file_path):
        print(f"Path {file_path} does not exist.")
        sys.exit(1)
    return file_path

def get_dir_file_list(dir_name):
    if os.path.isdir(dir_name) and check_file_or_directory_exists(dir_name):
        return os.listdir(dir_name)
    else:
        return []

def get_file_content(file_path):
  with open(file_path, "r") as f:
    content = f.read()

  return content

def get_file_list(file_list, file_name):
    return [f for f in file_list if f.__contains__(file_name)]

def check_file_in_list(file_list, file_name):
    return any(file_name in file for file in file_list)

def extract_content_between_strings(input_string, beginning_str = None, ending_str = None):
    lines = input_string.split("\n")
    spark_submit_error_message = ""
    spark_error_message_started = False
    for line in lines:
        if (beginning_str == None or ending_str == None):
            if (ending_str == None and line.__contains__(beginning_str)) or (beginning_str == None and line.__contains__(ending_str)):
                spark_submit_error_message = line + "\n"
                break
        else:
            if spark_error_message_started != True and (beginning_str == None or line.__contains__(beginning_str)):
                spark_submit_error_message = line + "\n"
                spark_error_message_started = True
            elif ending_str == None or line.__contains__(ending_str):
                spark_submit_error_message = spark_submit_error_message + line + "\n"
                break
            elif spark_error_message_started:
                spark_submit_error_message = spark_submit_error_message + line + "\n"

    return spark_submit_error_message

def get_spark_submit_result(py_version, spark_submit_apps_logs_dir):
    spark_submit_tests_files = get_dir_file_list(spark_submit_apps_logs_dir)
    spark_submit_python_result_files = get_file_list(spark_submit_tests_files, py_version)
    spark_submit_test_results = []
    for spark_submit_example in spark_submit_examples:
        file_list = get_file_list(spark_submit_python_result_files, spark_submit_example)
        test_result = "Not Tested"
        test_result_message = ""
        if file_list:
            spark_submit_test_result_file = file_list[0]
            spark_submit_test_output = get_file_content(get_directory_path(spark_submit_apps_logs_dir, spark_submit_test_result_file))
            if spark_submit_test_output.__contains__("Traceback (most recent call last):"):
                failed_output_message = extract_content_between_strings(spark_submit_test_output, "Traceback (most recent call last):", 
                                                                        "TypeError:")
                test_result = "Failed"
                test_result_message = failed_output_message
            else:
                test_result = "Success"
        
        spark_submit_test_results.append({"spark_submit_example" : spark_submit_example, "test_result": test_result, "test_result_message": test_result_message})

    return spark_submit_test_results

def get_pyspark_unit_test_modules(py_version, pyspark_unit_tests_logs_dir):
    pyspark_unit_test_modules = []
    pyspark_run_tests_files = get_dir_file_list(pyspark_unit_tests_logs_dir)
    spark_python_unit_test_result_files = get_file_list(pyspark_run_tests_files, py_version)

    for python_module in python_modules:
        python_module_result = "Not Tested"
        python_module_message = ""
        pyspark_unit_test_module_file_name = next(
            (f for f in spark_python_unit_test_result_files if f.startswith(py_version) and f.__contains__(python_module)),
            None
        )
        if pyspark_unit_test_module_file_name:
            pyspark_unit_test_module_file = os.path.join(pyspark_unit_tests_logs_dir, pyspark_unit_test_module_file_name)
            pyspark_unit_test_module_content = get_file_content(pyspark_unit_test_module_file)
            python_module_result = "Failed"
            if "Tests passed in" in pyspark_unit_test_module_content:
                python_module_result = "Success"
            elif "***Test Failed***" in pyspark_unit_test_module_content:
                python_module_message = extract_content_between_strings(pyspark_unit_test_module_content,
                                "**********************************************************************", "***Test Failed***")
            elif pyspark_unit_test_module_content.__contains__("Traceback (most recent call last):"):
                python_module_message = extract_content_between_strings(pyspark_unit_test_module_content, 
                                "Traceback (most recent call last):", "TypeError:")
            elif "No module named" in pyspark_unit_test_module_content:
                python_module_message = extract_content_between_strings(pyspark_unit_test_module_content, "No module named")
            else:
                python_module_message = pyspark_unit_test_module_content
            
        pyspark_unit_test_module_result = {"module_name": python_module, "test_result": python_module_result, 
                                       "test_result_message": python_module_message}

        pyspark_unit_test_modules.append(pyspark_unit_test_module_result)

    return pyspark_unit_test_modules

def get_random_color(index):
    colors_list = ["#FAEBD7", "#F0FFFF", "#AFEEEE", "#FFE4C4", "#FFF0F5", "#A9A9A9", "#DEB887", "#8FBC8F", "#FFFAF0", 
                   "#FFFACD", "#E0FFFF", "#3CB371", "#FFDEAD", "#FFB6C1", "#F0E68C", "#FFDAB9", "#D8BFD8", "#B0E0E6"]
    colors_list_len = len(colors_list)
    return colors_list[int(index%colors_list_len)]

def get_color_by_status(status):
    spark_submit_status_color = "brown"
    if status == 'Success' :
        spark_submit_status_color = "green"
    elif status == 'Failed' :
        spark_submit_status_color = "red"

    return spark_submit_status_color

def get_escaped_message(message):
    #replace('&', "&amp;").replace("#", "&#35;").
    return  message. \
        replace('<', "&lt;").replace('>', "&gt;").replace('"', "&#34;").replace('"', "&#34;").\
        replace("'", "\\'").replace("(", "&#40;").replace(")", "&#41;").replace("/", "&#47;").\
        replace("!", "&#33;").replace("$", "&#36;").replace("%", "&#37;").replace("*", "&#42;").\
        replace("+", "&#43;").replace("\n", "\\n")

def get_td_by_status(title, obj_res):
    status = obj_res['test_result']
    message = obj_res['test_result_message']

    if message:
        message = get_escaped_message(message)
    
    obj_status = "Not Tested"
    obj_status_color = "brown"
    if status == 'Success' :
        obj_status = f"<span class=\"glyphicon glyphicon-ok\" aria-hidden=\"true\"></span> {status}"
        obj_status_color = "green"
    elif status == 'Failed' :
        obj_status = f"""<span class="glyphicon glyphicon-remove" aria-hidden="true"></span>
            {status} <i class="bi bi-eye" onclick="display_message('{title}', '{message}')"></i>"""
        obj_status_color = "red"
    
    return f"<td style='color: {obj_status_color};'>{obj_status}</td>"

def get_overall_test_status(spark_submit_result_obj, pyspark_unit_test_modules):
    overall_status_count = 0
    spark_submit_result_udf_example = spark_submit_result_obj[0]
    spark_submit_result_status = spark_submit_result_udf_example['test_result']
    if spark_submit_result_status == 'Success':
        overall_status_count = 50
        for pyspark_core_unit_test in pyspark_unit_test_modules:
            module_test_status = pyspark_core_unit_test['test_result']
            if module_test_status == 'Success':
                overall_status_count = overall_status_count + 10
            elif module_test_status == 'Failed':
                test_result_message = pyspark_core_unit_test['test_result_message']
                #print("Check this logic later" + test_result_message)
        
        return ("Success" if overall_status_count == 100 else "Not Tested" if overall_status_count < 50 else "Failed")
    else:
        if spark_submit_result_status == "Not Tested":
            return "Not Tested"
        else:
            spark_submit_test_result_message = spark_submit_result_udf_example['test_result_message']
            spark_submit_error_message = extract_content_between_strings(spark_submit_test_result_message, "TypeError:")
            pyspark_core_unit_test = pyspark_unit_test_modules[0]
            test_result_message = pyspark_core_unit_test['test_result_message']
            pyspark_unit_test_error_message = extract_content_between_strings(test_result_message, "TypeError:")
            if spark_submit_error_message == pyspark_unit_test_error_message:
                status = "Not Compatible"
                message = get_escaped_message(spark_submit_test_result_message)
                title = "Spark Python Not Compatible Exception"
                obj_status = f"""<span class="glyphicon glyphicon-remove" aria-hidden="true"></span>
                    {status} <i class="glyphicon glyphicon-sunglasses" onclick="display_message('{title}', '{message}')"></i>"""
                return obj_status
            else:
                return "Review the Logs output {spark_submit_error_message}:${pyspark_unit_test_error_message} "
        
def get_html_content(data):
    html_page = """
    <!DOCTYPE html>
    <html lang="en">
        <head>
            <meta charset="utf-8">
            <meta http-equiv="X-UA-Compatible" content="IE=edge">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@3.3.7/dist/css/bootstrap.min.css">
            <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.10.5/font/bootstrap-icons.css">
            <title>Spark Python Compatability Matrix</title>
            <script>
                function display_message(title, message) {
                    var modal = $('#myModal').modal({
                        keyboard: true
                    })
                    modal.find('.modal-title').text(title + ' Exception')
                    let txt = document.createElement("textarea");
                    txt.innerHTML = message;
                    modal.find('.modal-body-content').text(txt.value)
                }
            </script>
        </head>
    <body>
        <div class="container-fluid">
        <h1 align='center' style='color: #D2691E;'>Spark Python Compatability Matrix</h1>
        <table class="table table-striped table-hover">
            <tr>
                <th scope="col">Spark Version</th>
                <th scope="col">Python Version</th>
                <th scope="col">Spark Submit Status</th>
                <th scope="col">Spark Pandas Status</th>
                <th scope="col">Spark Numpy Status</th>
                <th scope="col">PySpark Core Unit Tests</th>
                <th scope="col">PySpark SQL Unit Tests</th>
                <th scope="col">PySpark Streaming Unit Tests</th>
                <th scope="col">PySpark Mllib Unit Tests</th>
                <th scope="col">PySpark Ml Unit Tests</th>
                <th scope="col">Overall Status</th>
            </tr>
    """
    random_color = None
    previous_spark_version = None
    index = 0
    for row in data:
        spark_version = row['spark_version']
        if previous_spark_version != spark_version:
            random_color = get_random_color(index)
            previous_spark_version = spark_version
            index = index + 1
        
        python_version = row['python_version']
        spark_submit_result = row['spark_submit_result']
        pyspark_unit_test_modules = row['pyspark_unit_test_modules']
        overall_status = get_overall_test_status(spark_submit_result, pyspark_unit_test_modules)   
        html_page += f"""        
            <tr scope=\"row\" style='background-color: {random_color}'>
                <td>{spark_version}</td>
                <td>{python_version}</td>
                {get_td_by_status('Spark Submit UDF Status', spark_submit_result[0])}
                {get_td_by_status('Spark Submit Pandas Status', spark_submit_result[0])}
                {get_td_by_status('Spark Submit Numpy Status', spark_submit_result[0])}
                {get_td_by_status('PySpark Core Unit Tests', pyspark_unit_test_modules[0])}
                {get_td_by_status('PySpark SQL Unit Tests', pyspark_unit_test_modules[1])}
                {get_td_by_status('PySpark Streaming Unit Tests', pyspark_unit_test_modules[2])}
                {get_td_by_status('PySpark MLLib Unit Tests', pyspark_unit_test_modules[3])}
                {get_td_by_status('PySpark ML Unit Tests', pyspark_unit_test_modules[4])}
                <td style='color: {get_color_by_status(overall_status)};'>{overall_status}</td>
            </tr>"""

    html_page += "      </table>\n"
    html_page += """
        <div class="modal fade bs-example-modal-lg" id="myModal" tabindex="-1" role="dialog" aria-labelledby="myModalLabel">
            <div class="modal-dialog modal-lg" role="document">
                <div class="modal-content" style='max-height: 70%'>
                    <div class="modal-header">
                        <button type="button" class="close" data-dismiss="modal" aria-label="Close"><span aria-hidden="true">&times;</span></button>
                        <h4 class="modal-title" id="myModalLabel"></h4>
                    </div>
                    <div class="modal-body" style="max-height: 500px; overflow: auto;"><pre><div class="modal-body-content"></div></pre></div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-default" data-dismiss="modal">Close</button>
                    </div>
                </div>
            </div>
        </div>"""

    html_page += "      <script src='https://code.jquery.com/jquery-1.12.4.min.js'></script>\n"
    html_page += "      <script src='https://cdn.jsdelivr.net/npm/bootstrap@3.4.1/dist/js/bootstrap.min.js'></script>\n"
    html_page += "      </div>\n"
    html_page += "</body>\n"
    html_page += "</html>\n"

    return html_page

def write_html_content_to_file(file_name, html_content):
    # Write the HTML page to a file
    output_file = os.path.join("spark-python-test-report", file_name)
    with open(output_file, "w") as f:
        f.write(html_content)

def main():
    data_dir_path = get_directory_path(cwd, "data")
    spark_app_logs_dir = get_directory_path(data_dir_path, "spark_app_logs")
    spark_python_test_report_data = []

    # Spark Versions
    for spark_version in spark_versions:
        spark_min_version = spark_version.replace(".", "")
        pyspark_unit_tests_logs_dir = get_directory_path(spark_app_logs_dir, f"{spark_min_version}/spark_python_unit_test_logs")
        spark_submit_apps_logs_dir = get_directory_path(spark_app_logs_dir, f"{spark_min_version}/spark_submit_app_logs")

        # Python Versions
        for python_version in python_versions:
            py_version = python_version.replace(".", "")
            spark_version_report = {"spark_version": spark_version, "python_version":python_version}

            # Spark-Submit Result
            spark_version_report["spark_submit_result"] = get_spark_submit_result(py_version, spark_submit_apps_logs_dir)
            
            # Pyspark Unit Tests Result
            spark_version_report["pyspark_unit_test_modules"] = get_pyspark_unit_test_modules(py_version, pyspark_unit_tests_logs_dir)
            spark_python_test_report_data.append(spark_version_report)

    html_content = get_html_content(spark_python_test_report_data)
    write_html_content_to_file("spark_python_matrix.html", html_content)
    print("Python Script Successfully finished")

if __name__ == "__main__":
    main()