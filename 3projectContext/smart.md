# Objetivos SMART del Proyecto F1

Este documento detalla los objetivos específicos, medibles, alcanzables, relevantes y temporales (SMART) que guiarán el desarrollo de nuestra Plataforma de Análisis Estratégico de Fórmula 1. Estos objetivos se dividen en dos áreas principales: el análisis estratégico profundo para el equipo (Objetivos 1-3) y la capa de servicio de baja latencia para aplicaciones externas (Objetivo 4).

---

## Objetivo 1: Analizar la Degradación de Neumáticos por Compuesto

Este objetivo es el núcleo de nuestro análisis y el principal caso de uso para nuestra arquitectura de Data Warehouse (BigQuery) y nuestra herramienta de Business Intelligence (Looker).

* **(S) Específico:** Desarrollar un dashboard interactivo en Looker que permita comparar el rendimiento y la degradación de los tres compuestos de neumáticos (Blando, Medio, Duro). El análisis se centrará en 3 circuitos representativos seleccionados que exhiban diferentes características de desgaste (ej: Bahréin por su tracción, Silverstone por su alta carga aerodinámica y Mónaco por su baja degradación).

* **(M) Medible:** El éxito de este objetivo se medirá por la existencia de una visualización funcional (gráfica de líneas) en el dashboard que muestre el "Tiempo de vuelta" en el eje Y y el "Número de vuelta del stint" (vueltas con ese juego de neumáticos) en el eje X. La gráfica deberá ser filtrable por circuito, compuesto de neumático y equipo. La pendiente ascendente de las líneas en la gráfica representará visualmente la degradación del rendimiento, permitiendo comparaciones directas.

* **(A) Alcanzable:** Este objetivo es completamente alcanzable utilizando los datos del archivo `laps_2021_enriched.csv` cargados en Google BigQuery. Al limitar el análisis inicial a 3 circuitos clave, podemos enfocar nuestro esfuerzo en la calidad y profundidad del análisis en lugar de la cantidad, lo cual es una estrategia realista para el tiempo disponible del proyecto. La creación de la visualización en Looker a partir de una consulta SQL sobre BigQuery es una tarea estándar.

* **(R) Relevante:** Este análisis es críticamente relevante para el problema de negocio central. Entender cómo, cuándo y a qué ritmo un neumático pierde rendimiento es la pieza de información más fundamental para definir y optimizar una estrategia de paradas en pits. Responde directamente a la pregunta: "¿Cuánto dura realmente cada compuesto en este circuito?".

* **(T) Temporal:** La funcionalidad completa para este objetivo, incluyendo la ingesta de datos a BigQuery y la creación del dashboard correspondiente en Looker, deberá estar completada y funcional para el final de la tercera semana de desarrollo del proyecto.

---

## Objetivo 2: Evaluar el Impacto de las Ventanas de Parada en Pits

Este objetivo profundiza el análisis estratégico, demostrando cómo podemos usar nuestro Data Warehouse para evaluar decisiones históricas y encontrar patrones en las estrategias de carrera.

* **(S) Específico:** Crear una vista dedicada en el dashboard de Looker que compare el rendimiento general en carrera de los pilotos, agrupándolos según la ventana de vueltas en la que realizaron su primera parada en pits. Se crearán cohortes o grupos de estrategia (ej: "Parada Temprana: vueltas 10-18", "Parada Óptima: vueltas 19-27", "Parada Tardía: vueltas 28+").

* **(M) Medible:** El entregable será una tabla comparativa o un gráfico de barras dentro de Looker que muestre métricas clave de resultado (como el tiempo total de carrera, la posición final promedio o el número de adelantamientos netos) para cada cohorte de estrategia. Esto permitirá una comparación cuantitativa directa del éxito de cada enfoque en los 3 circuitos seleccionados.

* **(A) Alcanzable:** La lógica para este análisis se puede implementar con una consulta SQL en BigQuery. Dicha consulta identificará la vuelta de la primera parada para cada piloto (buscando en la columna `Stint`), los agrupará en las cohortes definidas y calculará las métricas de rendimiento agregadas. La visualización de estos resultados agregados en Looker es una tarea directa.

* **(R) Relevante:** Este objetivo ataca directamente el corazón de la estrategia de carrera. Proporciona evidencia histórica y basada en datos para responder a la pregunta "¿Cuándo es el mejor momento para parar?". Permite a un estratega validar si una estrategia de "undercut" (parar antes para ganar posición) o "overcut" (parar más tarde para tener neumáticos más nuevos al final) fue más efectiva en un circuito y condiciones determinadas.

* **(T) Temporal:** Esta vista del dashboard se desarrollará en paralelo o inmediatamente después del Objetivo 1, con el objetivo de tenerla lista para revisión dentro del plazo de las tres primeras semanas de desarrollo.

---

## Objetivo 3: Correlacionar Condiciones Climáticas con el Rendimiento por Sector

Este objetivo demuestra la capacidad de nuestra arquitectura para integrar múltiples fuentes de datos y enriquecer nuestro análisis con contexto externo crucial.

* **(S) Específico:** Implementar una visualización en el dashboard de Looker que correlacione una variable climática clave (específicamente, la `TrackTemp` o Temperatura de la Pista del archivo `weather_2021.csv`) con los tiempos de vuelta o los tiempos de sector individuales del archivo `laps_2021_enriched.csv`.

* **(M) Medible:** El resultado final será un gráfico de dispersión (scatter plot) funcional. Un eje representará la Temperatura de la Pista y el otro el Tiempo de Vuelta/Sector. Cada punto en el gráfico será una vuelta individual. Esto permitirá identificar visualmente si existe una tendencia (por ejemplo, si a mayor temperatura, los tiempos de vuelta tienden a empeorar, indicando un mayor desgaste de neumáticos).

* **(A) Alcanzable:** La implementación requiere unir (o, idealmente, desnormalizar durante el proceso ETL) las tablas de clima y vueltas en BigQuery, usando el timestamp como clave de unión aproximada. Esta es una operación estándar en un Data Warehouse. Una vez que los datos están en una sola tabla ancha, la creación de un gráfico de dispersión en Looker es trivial.

* **(R) Relevante:** Este análisis añade una capa indispensable de contexto. Las condiciones climáticas, y en particular la temperatura del asfalto, tienen un impacto masivo en el comportamiento y la degradación de los neumáticos. Este objetivo ayuda a un estratega a responder preguntas como "¿Nuestra estrategia planificada sigue siendo óptima si el día de la carrera es 10°C más caluroso de lo previsto?".

* **(T) Temporal:** Esta funcionalidad se añadirá al dashboard principal de Looker antes de la fecha final de entrega del proyecto, una vez que los análisis principales estén establecidos.

---

## Objetivo 4: Construir el Backend para Perfiles de Piloto de Baja Latencia

Este objetivo valida nuestra arquitectura de tres capas, demostrando el caso de uso de una capa de servicio rápida para consumir los *insights* generados en la capa analítica.

* **(S) Específico:** Desarrollar y desplegar una API RESTful con un endpoint único (`/api/driver/{driver_id}/profile`) que devuelva un perfil de rendimiento pre-calculado y consolidado para un piloto específico.

* **(M) Medible:** El éxito se define por un endpoint funcional que, al ser consultado con un ID de piloto válido, retorna un objeto JSON desde Amazon DynamoDB con una latencia de respuesta inferior a 200 milisegundos. Este JSON representará el **subconjunto de métricas "productizadas"** y debe contener al menos 3 *insights* clave, previamente calculados en BigQuery. Por ejemplo:
    1.  `tyreManagementIndex`: Un score numérico (ej: 1-10) que cuantifica la habilidad del piloto para gestionar el desgaste de los neumáticos.
    2.  `consistencyScore`: Un score numérico que mide la consistencia de sus tiempos de vuelta durante stints largos de carrera.
    3.  `sectorPerformanceProfile`: Un objeto que indique el rendimiento relativo del piloto en los **tipos de sector que hemos clasificado** (ej: `{ "high_speed_performance": "Above Average", "low_speed_performance": "Average", "medium_speed_performance": "Elite" }`).

* **(A) Alcanzable:** El plan de ejecución es claro y factible:
    1.  Escribir las consultas SQL en BigQuery para calcular las métricas complejas, incluyendo la clasificación de sectores por velocidad promedio.
    2.  Crear un script (parte de nuestro ETL) que ejecute estas consultas y cargue los resultados finales y curados en la tabla de DynamoDB.
    3.  Construir y desplegar una API simple (por ejemplo, usando AWS Lambda y API Gateway) que simplemente lea un ítem de DynamoDB por su clave primaria.

* **(R) Relevante:** Este objetivo es fundamental para justificar nuestra arquitectura políglota. Demuestra de manera práctica el caso de uso del "escaparate vs. la fábrica": servir datos ya procesados a una aplicación hipotética de cara al cliente (App de Comentaristas) con la altísima velocidad que requiere, separando completamente la carga de trabajo analítica (OLAP) de la operativa (Key-Value).

* **(T) Temporal:** El endpoint de la API debe estar completamente operativo y documentado para la fecha final de entrega del proyecto.