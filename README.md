# Spark Python Compatibilty Tests

## Build the Spark Python Compatibilty Image

```sh
bash build.sh
```

## Run the Spark Python Compatibilty Image

```sh
docker-compose up -d
```

## Stop the Spark Python Compatibilty Image

```sh
docker-compose down
```

## Spark Jiras

* (Spark 3.3.1 is not yet supported Python3.11)[https://issues.apache.org/jira/browse/SPARK-41125]
* (PySpark does not work with Python 3.8.0)[https://issues.apache.org/jira/browse/SPARK-29536]