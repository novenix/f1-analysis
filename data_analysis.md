# Análisis del Dataset: F1 1950-2025

Este documento resume el contenido y la estructura de los archivos de datos para el proyecto de análisis de estrategias de Fórmula 1.

## Resumen General

El dataset contiene una colección completa de archivos CSV que describen exhaustivamente los resultados y eventos de las carreras de Fórmula 1 desde 1950. Los datos son altamente estructurados, normalizados y están interrelacionados, formando un modelo relacional clásico que servirá como la base fundamental del proyecto.

Se identifican dos categorías principales de datos:

- **Datos Maestros / Dimensionales**: Describen las entidades principales y estáticas del dominio (quién, qué, dónde).

- **Datos de Eventos / Hechos**: Registran las ocurrencias y mediciones dinámicas durante los fines de semana de carrera (qué pasó, cuándo).

Este conjunto de datos es ideal para una base de datos relacional (como PostgreSQL) y su granularidad en los archivos de eventos (lap_times, pit_stops) lo hace un candidato excelente para ser procesado y analizado en bases de datos orientadas a analítica (como BigQuery).

## Desglose por Archivo

### Datos Maestros y de Contexto (Tablas de Dimensión)

Estos archivos describen las entidades principales del dominio de la F1.

#### drivers.csv

**Contenido**: Información personal y de identificación de cada piloto.

**Columnas Clave**: driverId (ID único), driverRef, forename, surname, dob, nationality.

**Análisis**: Dimensión "Piloto". Fundamental para enriquecer los datos de resultados con información biográfica.

#### constructors.csv

**Contenido**: Información de identificación de cada equipo (constructor).

**Columnas Clave**: constructorId (ID único), constructorRef, name, nationality.

**Análisis**: Dimensión "Equipo". Permite agregar resultados y analizar el rendimiento a nivel de equipo.

#### circuits.csv

**Contenido**: Información detallada de cada circuito donde se han corrido carreras.

**Columnas Clave**: circuitId (ID único), name, location, country, lat (latitud), lng (longitud).

**Análisis**: Dimensión "Circuito". Las coordenadas lat y lng son críticas y de alto valor, ya que son el nexo para poder consultar y unir estos datos con un dataset externo de condiciones climáticas históricas.

#### seasons.csv

**Contenido**: Un listado de las temporadas de Fórmula 1 incluidas.

**Columnas Clave**: year, url.

**Análisis**: Tabla de contexto simple, útil para validar los rangos de fechas del análisis.

#### status.csv

**Contenido**: Tabla de búsqueda (lookup table) que describe el estado final de un piloto en una carrera.

**Columnas Clave**: statusId (ID único), status (ej: "Finished", "Accident", "+1 Lap", "Engine").

**Análisis**: Dimensión "Estado Final". Esencial para dar contexto a los resultados. Permite analizar la fiabilidad de los coches y las causas de los abandonos.

### Datos de Eventos y Resultados (Tablas de Hechos)

Estos archivos contienen los datos dinámicos generados durante los fines de semana de carrera.

#### races.csv

**Contenido**: El registro central de cada evento de Gran Premio.

**Columnas Clave**: raceId (ID único), year, round, circuitId, name, date, time.

**Análisis**: Es el evento principal que conecta casi todos los demás datos. Define el "cuándo" y "dónde" de cada suceso.

#### results.csv

**Contenido**: Los resultados finales de cada piloto en cada Gran Premio.

**Columnas Clave**: resultId, raceId, driverId, constructorId, grid (salida), position (final), points, laps, fastestLap, statusId.

**Análisis**: Tabla de hechos principal para el rendimiento en carrera.

#### sprint_results.csv

**Contenido**: Similar a results.csv, pero para los resultados de las carreras "Sprint".

**Columnas Clave**: resultId, raceId, driverId, constructorId, grid, position, points.

**Análisis**: Representa un evento específico y más reciente en la F1.

#### qualifying.csv

**Contenido**: Resultados detallados de las sesiones de clasificación.

**Columnas Clave**: qualifyId, raceId, driverId, constructorId, position, q1, q2, q3.

**Análisis**: Hechos clave para entender el rendimiento a una vuelta y el ritmo puro.

#### pit_stops.csv

**Contenido**: Registro de cada parada en pits realizada durante una carrera.

**Columnas Clave**: raceId, driverId, stop (número), lap, duration.

**Análisis**: ¡Este es un archivo crucial para tu objetivo de análisis de estrategias! Es un dato de evento muy granular que nos permitirá analizar las tácticas de carrera, el desgaste de neumáticos (implícito) y el rendimiento del equipo de pits.

#### lap_times.csv

**Contenido**: Datos extremadamente granulares que registran el tiempo de cada vuelta para cada piloto en cada carrera.

**Columnas Clave**: raceId, driverId, lap, position, time.

**Análisis**: El archivo con mayor volumen de datos. Es la fuente principal para analizar ritmo de carrera, degradación de neumáticos y cómo evoluciona el rendimiento de un piloto durante un stint. Candidato ideal para una base de datos analítica/columnar.

#### driver_standings.csv

**Contenido**: La clasificación del campeonato de pilotos después de cada carrera.

**Columnas Clave**: driverStandingsId, raceId, driverId, points, position, wins.

**Análisis**: Tabla de "snapshots" o instantáneas, que muestra la evolución del campeonato.

#### constructor_standings.csv

**Contenido**: Equivalente al anterior, pero para el campeonato de constructores.

**Columnas Clave**: constructorStandingsId, raceId, constructorId, points, position.

**Análisis**: Muestra la evolución del rendimiento de los equipos.

#### constructor_results.csv

**Contenido**: Un resumen de los puntos obtenidos por un constructor en una carrera.

**Columnas Clave**: constructorResultsId, raceId, constructorId, points.

**Análisis**: Tabla agregada que puede simplificar consultas sobre el rendimiento de equipos.