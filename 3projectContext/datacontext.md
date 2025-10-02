# Descripción de Datos - Fórmula 1 (Año 2021 - 2025)

Este documento sirve como un resumen y descripción de los conjuntos de datos disponibles para el análisis de las temporadas de Fórmula 1. El objetivo es proporcionar un contexto claro sobre la estructura y el contenido de cada archivo para su posterior uso en el proyecto de Tópicos Avanzados en Bases de Datos. El análisis se basa en una muestra de datos del año 2021 a el 2025.

---

## `events_2021.csv`

Este archivo contiene el calendario de todos los eventos (Grandes Premios) de la temporada, con detalles sobre su ubicación y el horario de cada una de las sesiones oficiales.

| Columna | Descripción | Ejemplo (Fila 1) |
| :--- | :--- | :--- |
| **RoundNumber** | Número de la carrera en la temporada. | `1` |
| **Country** | País anfitrión del evento. | `Bahrain` |
| **Location** | Ciudad o localidad específica del circuito. | `Sakhir` |
| **OfficialEventName**| Nombre oficial completo del Gran Premio. | `FORMULA 1 GULF AIR BAHRAIN GRAND PRIX 2021` |
| **EventDate** | Fecha principal del evento (día de la carrera). | `2021-03-28` |
| **EventName** | Nombre común del Gran Premio. | `Bahrain Grand Prix` |
| **EventFormat** | Formato del fin de semana de carrera. | `conventional` |
| **Session1** | Nombre de la primera sesión. | `Practice 1` |
| **Session1Date** | Fecha y hora local de inicio de la Sesión 1. | `2021-03-26 14:30:00+03:00` |
| **Session1DateUtc** | Fecha y hora UTC de inicio de la Sesión 1. | `2021-03-26 11:30:00` |
| **Session2** | Nombre de la segunda sesión. | `Practice 2` |
| **Session2Date** | Fecha y hora local de inicio de la Sesión 2. | `2021-03-26 18:00:00+03:00` |
| **Session2DateUtc** | Fecha y hora UTC de inicio de la Sesión 2. | `2021-03-26 15:00:00` |
| **Session3** | Nombre de la tercera sesión. | `Practice 3` |
| **Session3Date** | Fecha y hora local de inicio de la Sesión 3. | `2021-03-27 15:00:00+03:00` |
| **Session3DateUtc** | Fecha y hora UTC de inicio de la Sesión 3. | `2021-03-27 12:00:00` |
| **Session4** | Nombre de la cuarta sesión. | `Qualifying` |
| **Session4Date** | Fecha y hora local de inicio de la Sesión 4. | `2021-03-27 18:00:00+03:00` |
| **Session4DateUtc** | Fecha y hora UTC de inicio de la Sesión 4. | `2021-03-27 15:00:00` |
| **Session5** | Nombre de la quinta sesión. | `Race` |
| **Session5Date** | Fecha y hora local de inicio de la Sesión 5. | `2021-03-28 18:00:00+03:00` |
| **Session5DateUtc** | Fecha y hora UTC de inicio de la Sesión 5. | `2021-03-28 15:00:00` |
| **F1ApiSupport** | Indica si el evento es compatible con la API de F1. | `True` |

---

## `laps_2021_enriched.csv`

Contiene datos por vuelta para cada piloto durante una sesión, incluyendo tiempos, información de neumáticos y telemetría enriquecida para cada sector del circuito.

| Columna | Descripción | Ejemplo (Fila 1) |
| :--- | :--- | :--- |
| **Time** | Tiempo transcurrido en la sesión hasta completar la vuelta. | `0 days 00:39:09.686000` |
| **Driver** | Abreviatura de 3 letras del piloto. | `HAM` |
| **DriverNumber** | Número del monoplaza del piloto. | `44` |
| **LapTime** | Tiempo total de la vuelta. | `0 days 00:01:59.538000` |
| **LapNumber** | Número de la vuelta. | `1.0` |
| **Stint** | Número del stint (periodo entre paradas en pits). | `1.0` |
| **PitOutTime** | Tiempo de sesión en el que el coche sale de pits. | |
| **PitInTime** | Tiempo de sesión en el que el coche entra a pits. | |
| **Sector1Time** | Tiempo del primer sector. | `0 days 00:00:54.367000` |
| **Sector2Time** | Tiempo del segundo sector. | `0 days 00:00:32.463000` |
| **Sector3Time** | Tiempo del tercer sector. | |
| **Sector1SessionTime**| Tiempo transcurrido en la sesión al cruzar la línea del Sector 1. | `0 days 00:38:37.358000` |
| **Sector2SessionTime**| Tiempo transcurrido en la sesión al cruzar la línea del Sector 2. | `0 days 00:39:09.824000` |
| **Sector3SessionTime**| Tiempo transcurrido en la sesión al cruzar la línea de meta. | |
| **SpeedI1** | Velocidad en el punto de medición del intermedio 1. | `233.0` |
| **SpeedI2** | Velocidad en el punto de medición del intermedio 2. | `124.0` |
| **SpeedFL** | Velocidad al cruzar la línea de meta. | `223.0` |
| **SpeedST** | Velocidad máxima registrada en la trampa de velocidad. | `258.0` |
| **IsPersonalBest** | Booleano que indica si fue la mejor vuelta personal del piloto. | `False` |
| **Compound** | Compuesto del neumático utilizado. | `MEDIUM` |
| **TyreLife** | Vueltas completadas con ese juego de neumáticos. | `4.0` |
| **FreshTyre** | Booleano que indica si era un neumático nuevo al inicio del stint. | `False` |
| **Team** | Nombre del equipo. | `Mercedes` |
| **LapStartTime** | Marca de tiempo del inicio de la vuelta. | `0 days 00:37:09.970000` |
| **LapStartDate** | Fecha y hora exactas del inicio de la vuelta. | `2021-03-28 15:07:09.980` |
| **TrackStatus** | Código numérico del estado de la pista. | `124` |
| **Position** | Posición del piloto en esa vuelta. | `2.0` |
| **Deleted** | Booleano que indica si la vuelta fue invalidada por los comisarios. | `False` |
| **DeletedReason** | Razón por la cual la vuelta fue invalidada. | |
| **FastF1Generated** | Indica si el dato fue generado por la librería FastF1. | `False` |
| **IsAccurate** | Indica si los datos de la vuelta son precisos. | `False` |
| **Year** | Año de la temporada. | `2021` |
| **EventName** | Nombre del Gran Premio. | `Bahrain Grand Prix` |
| **SessionName** | Nombre de la sesión. | `Race` |
| **Sector1_RPM_Avg** | Promedio de RPM en el Sector 1. | `9219.59...` |
| **Sector1_Throttle_Avg**| Porcentaje promedio de acelerador aplicado en el Sector 1. | `50.99...` |
| **Sector1_Speed_Avg** | Velocidad promedio en el Sector 1. | `155.05...` |
| **Sector1_Speed_Max** | Velocidad máxima en el Sector 1. | `293.0` |
| **Sector1_Speed_Min** | Velocidad mínima en el Sector 1. | `0.0` |
| **Sector1_nGear_Max** | Marcha más alta utilizada en el Sector 1. | `7.0` |
| **Sector1_nGear_Min** | Marcha más baja utilizada en el Sector 1. | `1.0` |
| **Sector1_Speed_StdDev**| Desviación estándar de la velocidad en el Sector 1. | `65.98...` |
| **Sector1_nGear_Mode**| Marcha más frecuente en el Sector 1. | `2.0` |
| **Sector1_Status_Mode**| Estado más frecuente del coche en el Sector 1 (ej. OnTrack). | `OnTrack` |
| **Sector1_Throttle_100_Time**| Tiempo con el acelerador al 100% en el Sector 1. | `0 days 00:00:27.88...` |
| **Sector1_Brake_Time** | Tiempo con el freno aplicado en el Sector 1. | `0 days 00:00:28.68...` |
| **Sector1_Throttle_Time**| Tiempo total con el acelerador presionado en el Sector 1. | `0 days 00:01:32.93...` |
| **Sector1_Coasting_Time**| Tiempo sin acelerar ni frenar en el Sector 1. | `0 days 00:00:03.67...` |
| **Sector1_DRS_Percentage**| Porcentaje del sector recorrido con DRS activo. | `100.0` |
| **Sector1_Gear_Changes**| Número de cambios de marcha en el Sector 1. | `56.0` |
| **Sector1_Distance_Sector**| Distancia total del Sector 1. | `5159.31...` |
| **Sector2_RPM_Avg** | Promedio de RPM en el Sector 2. | `9097.01...` |
| **Sector2_Throttle_Avg**| Porcentaje promedio de acelerador aplicado en el Sector 2. | `50.12...` |
| **Sector2_Speed_Avg** | Velocidad promedio en el Sector 2. | `154.03...` |
| **Sector2_Speed_Max** | Velocidad máxima en el Sector 2. | `293.0` |
| **Sector2_Speed_Min** | Velocidad mínima en el Sector 2. | `0.0` |
| **Sector2_nGear_Max** | Marcha más alta utilizada en el Sector 2. | `7.0` |
| **Sector2_nGear_Min** | Marcha más baja utilizada en el Sector 2. | `1.0` |
| **Sector2_Speed_StdDev**| Desviación estándar de la velocidad en el Sector 2. | `72.33...` |
| **Sector2_nGear_Mode**| Marcha más frecuente en el Sector 2. | `2.0` |
| **Sector2_Status_Mode**| Estado más frecuente del coche en el Sector 2. | `OnTrack` |
| **Sector2_Throttle_100_Time**| Tiempo con el acelerador al 100% en el Sector 2. | `0 days 00:00:24.66...` |
| **Sector2_Brake_Time** | Tiempo con el freno aplicado en el Sector 2. | `0 days 00:00:21.57...` |
| **Sector2_Throttle_Time**| Tiempo total con el acelerador presionado en el Sector 2. | `0 days 00:01:07.23...` |
| **Sector2_Coasting_Time**| Tiempo sin acelerar ni frenar en el Sector 2. | `0 days 00:00:03.21...` |
| **Sector2_DRS_Percentage**| Porcentaje del sector recorrido con DRS activo. | `100.0` |
| **Sector2_Gear_Changes**| Número de cambios de marcha en el Sector 2. | `42.0` |
| **Sector2_Distance_Sector**| Distancia total del Sector 2. | `3746.06...` |
| **Sector3_RPM_Avg** | Promedio de RPM en el Sector 3. | `9557.28...` |
| **Sector3_Throttle_Avg**| Porcentaje promedio de acelerador aplicado en el Sector 3. | `53.52...` |
| **Sector3_Speed_Avg** | Velocidad promedio en el Sector 3. | `158.07...` |
| **Sector3_Speed_Max** | Velocidad máxima en el Sector 3. | `228.81...` |
| **Sector3_Speed_Min** | Velocidad mínima en el Sector 3. | `64.0` |
| **Sector3_nGear_Max** | Marcha más alta utilizada en el Sector 3. | `6.0` |
| **Sector3_nGear_Min** | Marcha más baja utilizada en el Sector 3. | `2.0` |
| **Sector3_Speed_StdDev**| Desviación estándar de la velocidad en el Sector 3. | `44.55...` |
| **Sector3_nGear_Mode**| Marcha más frecuente en el Sector 3. | `4.0` |
| **Sector3_Status_Mode**| Estado más frecuente del coche en el Sector 3. | `OnTrack` |
| **Sector3_Throttle_100_Time**| Tiempo con el acelerador al 100% en el Sector 3. | `0 days 00:00:03.33...` |
| **Sector3_Brake_Time** | Tiempo con el freno aplicado en el Sector 3. | `0 days 00:00:07.12...` |
| **Sector3_Throttle_Time**| Tiempo total con el acelerador presionado en el Sector 3. | `0 days 00:00:25.85...` |
| **Sector3_Coasting_Time**| Tiempo sin acelerar ni frenar en el Sector 3. | `0 days 00:00:00.45...` |
| **Sector3_DRS_Percentage**| Porcentaje del sector recorrido con DRS activo. | `100.0` |
| **Sector3_Gear_Changes**| Número de cambios de marcha en el Sector 3. | `15.0` |
| **Sector3_Distance_Sector**| Distancia total del Sector 3. | `1419.94...` |

---

## `race_control_2021.csv`

Este archivo registra todos los mensajes emitidos por el control de carrera durante una sesión.

| Columna | Descripción | Ejemplo (Fila 1) |
| :--- | :--- | :--- |
| **Time** | Marca de tiempo exacta del mensaje. | `2021-03-28 14:45:06` |
| **Category** | Categoría del mensaje (ej: Flag, Other). | `Other` |
| **Message** | Contenido del mensaje. | `RISK OF RAIN FOR F1 RACE IS 0%` |
| **Status** | Estado asociado al mensaje (si aplica). | |
| **Flag** | Tipo de bandera mostrada (si aplica). | |
| **Scope** | Alcance del mensaje (ej: `Driver`, `Track`). | |
| **Sector** | Sector de la pista al que se refiere el mensaje. | |
| **RacingNumber** | Número del piloto al que se refiere el mensaje. | |
| **Lap** | Vuelta en la que se emitió el mensaje. | `1.0` |
| **Year** | Año de la temporada. | `2021` |
| **EventName** | Nombre del Gran Premio. | `Bahrain Grand Prix` |
| **SessionName** | Nombre de la sesión. | `Race` |

---

## `results_2021.csv`

Contiene los resultados finales de una sesión, incluyendo la posición, puntos y estado de cada piloto.

| Columna | Descripción | Ejemplo (Fila 1) |
| :--- | :--- | :--- |
| **DriverNumber** | Número del monoplaza del piloto. | `44` |
| **BroadcastName** | Nombre del piloto como se muestra en TV. | `L HAMILTON` |
| **Abbreviation** | Abreviatura de 3 letras del piloto. | `HAM` |
| **DriverId** | Identificador único del piloto. | `hamilton` |
| **TeamName** | Nombre del equipo. | `Mercedes` |
| **TeamColor** | Código hexadecimal del color del equipo. | `00D2BE` |
| **TeamId** | Identificador único del equipo. | `mercedes` |
| **FirstName** | Nombre de pila del piloto. | `Lewis` |
| **LastName** | Apellido del piloto. | `Hamilton` |
| **FullName** | Nombre completo del piloto. | `Lewis Hamilton` |
| **HeadshotUrl** | URL de la foto del piloto. | `https://www.formula1.com/...` |
| **CountryCode** | Código del país del piloto. | |
| **Position** | Posición final en la sesión. | `1.0` |
| **ClassifiedPosition** | Posición oficial en la clasificación final. | `1` |
| **GridPosition** | Posición de salida en la parrilla. | `2.0` |
| **Q1** | Tiempo en la Sesión de Clasificación 1. | |
| **Q2** | Tiempo en la Sesión de Clasificación 2. | |
| **Q3** | Tiempo en la Sesión de Clasificación 3. | |
| **Time** | Tiempo total de carrera o diferencia con el líder. | `0 days 01:32:03.897000` |
| **Status** | Estado final del piloto (ej: Finished, +1 Lap, DNF). | `Finished` |
| **Points** | Puntos obtenidos en la sesión. | `25.0` |
| **Laps** | Número de vueltas completadas. | `56.0` |
| **Year** | Año de la temporada. | `2021` |
| **EventName** | Nombre del Gran Premio. | `Bahrain Grand Prix` |
| **SessionName** | Nombre de la sesión. | `Race` |

---

## `sessions_2021.csv`

Un archivo simple que lista todas las sesiones que ocurrieron en cada evento y su fecha de inicio.

| Columna | Descripción | Ejemplo (Fila 1) |
| :--- | :--- | :--- |
| **Year** | Año de la temporada. | `2021` |
| **EventName** | Nombre común del Gran Premio. | `Bahrain Grand Prix` |
| **SessionName** | Nombre de la sesión (`Race`, `Qualifying`, etc.). | `Race` |
| **SessionDate** | Fecha y hora de inicio de la sesión. | `2021-03-28 15:00:00` |

---

## `weather_2021.csv`

Registra las condiciones meteorológicas a lo largo del tiempo durante una sesión.

| Columna | Descripción | Ejemplo (Fila 1) |
| :--- | :--- | :--- |
| **Time** | Tiempo transcurrido en la sesión. | `0 days 00:00:43.040000` |
| **AirTemp** | Temperatura del aire en °C. | `20.9` |
| **Humidity** | Porcentaje de humedad. | `56.4` |
| **Pressure** | Presión atmosférica en hPa. | `1014.8` |
| **Rainfall** | Booleano que indica si está lloviendo. | `False` |
| **TrackTemp** | Temperatura de la pista en °C. | `29.9` |
| **WindDirection** | Dirección del viento en grados. | `6` |
| **WindSpeed** | Velocidad del viento en km/h. | `1.0` |
| **Year** | Año de la temporada. | `2021` |
| **EventName** | Nombre del Gran Premio. | `Bahrain Grand Prix` |
| **SessionName** | Nombre de la sesión. | `Race` |