import sys
import os

# Create a list of data
data = [
    ["3", "3.1.2", "Success", "Passed"],
    ["3.8", "3.1.2", "Success", "Passed"],
    ["3.9", "3.1.2", "Success", "Passed"],
]

# Create the HTML page
html_page = """
<!DOCTYPE html>
<html lang="en">
    <head>
        <meta charset="utf-8">
        <meta http-equiv="X-UA-Compatible" content="IE=edge">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@3.3.7/dist/css/bootstrap.min.css">
        <title>Spark Python Compatability Matrix</title>
    </head>
<body>
    <div class="container-fluid">
    <h1 align='center'>Spark Python Compatability Matrix</h1>
    <table class="table table-striped table-hover">
        <tr>
            <th scope="col">Python Version</th>
            <th scope="col">Spark Version</th>
            <th scope="col">Spark Submit Status</th>
            <th scope="col">Py Spark Unit Tests</th>
        </tr>
"""

for row in data:
    html_page += "        <tr scope=\"row\">\n"
    for column in row:
        html_page += "            <td>" + str(column) + "</td>\n"
    html_page += "        </tr>\n"

html_page += "      </table>\n"
html_page += "      <script src='https://code.jquery.com/jquery-1.12.4.min.js'></script>\n"
html_page += "      <script src='https://cdn.jsdelivr.net/npm/bootstrap@3.4.1/dist/js/bootstrap.min.js'></script>\n"
html_page += "      </div>\n"
html_page += "</body>\n"
html_page += "</html>\n"

# Write the HTML page to a file
output_file = os.path.join(".", "spark_python_matrix.html")
with open(output_file, "w") as f:
    f.write(html_page)