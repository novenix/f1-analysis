# Documento de Arquitectura de Datos - Proyecto F1
*Nota: Este es un documento vivo. La arquitectura y los flujos de datos aquí descritos pueden estar sujetos a cambios y refinamientos a medida que el proyecto evolucione.*

## 1. Introducción y Filosofía de Diseño

Este documento define la estrategia de persistencia de datos para el proyecto de análisis de Fórmula 1. En lugar de forzar todos nuestros datos en una única base de datos ("one size fits all"), adoptaremos un enfoque de **persistencia políglota**. Esto significa que seleccionaremos la tecnología de base de datos más adecuada para cada tipo de dato y caso de uso, asegurando así un rendimiento, escalabilidad y eficiencia óptimos.

Nuestra arquitectura se compondrá de tres pilares fundamentales, cada uno sirviendo un propósito distinto pero interconectado:
1.  **Una Base de Datos Relacional (PostgreSQL):** El núcleo para datos maestros y transaccionales.
2.  **Una Base de Datos Columnar (Google BigQuery):** El motor para análisis de Big Data (Data Warehouse).
3.  **Una Base de Datos Key-Value (Amazon DynamoDB):** La capa de acceso de ultra baja latencia para aplicaciones.

A continuación, se detalla el rol, los datos y la justificación de cada componente.

---

## 1.5. Flujo de Datos General

El siguiente diagrama y descripción ilustran el ciclo de vida de los datos dentro de nuestra arquitectura, desde su origen en los archivos CSV hasta su consumo final en las capas de análisis y aplicación.
mermaid diagram

graph TD
    subgraph "Fuente de Datos"
        A[Archivos CSV]
    end

    subgraph "Procesamiento y Almacenamiento"
        B(Proceso ETL / ELT)
        C["BD Relacional <br> (PostgreSQL)"]
        D["Data Warehouse <br> (Google BigQuery)"]
        E(Cálculos Agregados)
        F["BD Key-Value <br> (Amazon DynamoDB)"]
    end

    subgraph "Consumo y Aplicaciones"
        G{{"Capa Analítica <br> (Looker)"}}
        H(API)
        I[/App de Comentarista/]
    end

    %% Conexiones del Flujo
    A --> B

    B -- "Metadatos y Entidades Maestras" --> C
    B -- "Datos de Telemetría Enriquecidos" --> D

    D -- "Ejecuta consultas de agregación" --> E
    E -- "Carga perfiles pre-calculados" --> F

    D -- "Fuente de datos para Dashboards" --> G
    F -- "Lecturas de baja latencia (Perfiles)" --> H
    C -- "Lecturas de metadatos" --> H
    H --> I



### Descripción del Flujo:

1.  **Extracción (Extract):** El proceso comienza con los archivos CSV de Fórmula 1 como nuestra fuente de datos en crudo.

2.  **Transformación y Carga (Transform & Load):** Un proceso central de ETL (o ELT) se encarga de orquestar el movimiento y la preparación de los datos. Este proceso es responsable de:
    * **Limpieza y Estandarización:** Asegurar la calidad de los datos, manejar valores nulos y estandarizar formatos (ej: fechas, tiempos).
    * **Carga a la BD Relacional:** Los datos maestros y estructurales (`events`, `results`, `sessions`) se cargan directamente en **PostgreSQL**. Esta base de datos se convierte en la fuente de verdad para las entidades principales.
    * **Desnormalización y Carga al DWH:** Los datos de series de tiempo y telemetría (`laps_enriched`, `weather`, etc.) son **enriquecidos** durante este paso. Se añaden columnas de contexto (como `EventName` o `Country` desde la data relacional) para crear una "super-tabla" analítica. Esta tabla ancha y desnormalizada se carga en **Google BigQuery**.
    * **Cálculo de Agregados:** Después de que los datos están en BigQuery (o como un paso intermedio en el ETL), se ejecutan consultas programadas para calcular las estadísticas agregadas que necesitamos para los perfiles de piloto (ej: "índice de gestión de neumáticos", "mejor circuito").
    * **Carga a la BD Key-Value:** Los resultados de estos cálculos (los perfiles de piloto en formato JSON) se cargan en **Amazon DynamoDB**, utilizando el `DriverID` como clave primaria.

3.  **Consumo y Servicio (Serve):**
    * **Capa Analítica:** La herramienta de Business Intelligence, **Looker**, se conecta directamente a **BigQuery**. Esto permite a los analistas de datos (nosotros) explorar, visualizar y descubrir patrones en el volumen masivo de datos de telemetría.
    * **Capa de Aplicación:** Una API (que construiremos) sirve los datos a la aplicación final (la "App de Comentaristas"). Esta API realiza dos tipos de consultas:
        * Consultas de **baja latencia** a **DynamoDB** para obtener perfiles de piloto de forma instantánea (ej: "Dame el perfil de 'HAM'").
        * Consultas a **PostgreSQL** para obtener datos contextuales o de metadatos que no requieren la velocidad de DynamoDB (ej: "Muéstrame el calendario de la temporada 2024").

Este flujo garantiza que cada componente de la arquitectura se utilice para lo que fue diseñado, separando las cargas de trabajo analíticas pesadas de las consultas rápidas y operativas de la aplicación.

---

## 2. Componente 1: La Base de Datos Relacional (PostgreSQL)

### Rol: "El Hub de Metadatos y Transacciones"

Esta base de datos será la **fuente única de verdad (Single Source of Truth)** para las entidades principales y la información estructural de nuestro dominio. Su enfoque es la consistencia, integridad y las relaciones bien definidas. Es una base de datos optimizada para cargas de trabajo **OLTP (Online Transaction Processing)**, aunque en nuestro caso las transacciones serán principalmente cargas iniciales y actualizaciones ocasionales.

### Datos a Almacenar:

* `events_2021.csv`: El calendario de Grandes Premios.
* `results_2021.csv`: Los pilotos, equipos y los resultados finales consolidados de cada sesión.
* `sessions_2021.csv`: Las sesiones específicas (Práctica 1, Carrera, etc.) de cada evento.

*(Nota: Los datos se cargarán para el rango de años 2021-2025)*

### Justificación Técnica:

* **Integridad de Datos:** Las restricciones de llaves primarias y foráneas garantizan que no podamos tener, por ejemplo, un resultado de carrera que no esté asociado a un evento y un piloto válidos.
* **Consistencia (ACID):** Las propiedades ACID (Atomicidad, Consistencia, Aislamiento, Durabilidad) aseguran que nuestras operaciones de escritura sean seguras y predecibles.
* **Modelo de Datos Intuitivo:** El modelo Entidad-Relación es perfecto para representar la jerarquía lógica de la F1: una temporada tiene eventos, un evento tiene sesiones, y una sesión tiene resultados para varios pilotos de diferentes equipos.
* **Consultas de Búsqueda (Lookups):** Es extremadamente eficiente para consultas del tipo: "Tráeme toda la información del Gran Premio de Bahréin 2021" o "Lista todos los pilotos del equipo Red Bull Racing".

### ¿Por qué NO usarla para todo?

Aunque técnicamente posible, cargar los 6 CSVs en PostgreSQL sería una mala decisión de arquitectura. Las bases de datos relacionales utilizan un **almacenamiento orientado a filas**. Cuando se realiza una consulta analítica masiva (ej: `AVG(Velocidad_Media)`) sobre millones de vueltas, la base de datos se ve obligada a leer del disco cada fila completa (con sus 80+ columnas) para extraer solo el valor de una columna. Este exceso de operaciones de I/O hace que las consultas analíticas a gran escala sean lentas y costosas. Es como querer atornillar un tornillo con un martillo; no es la herramienta adecuada para el trabajo.

---

## 3. Componente 2: La Base de Datos Columnar (Google BigQuery)

### Rol: "El Motor Analítico y Data Warehouse"

Aquí es donde reside el verdadero poder de nuestro proyecto. BigQuery será nuestro **Data Warehouse (DWH)**, optimizado para consultas analíticas complejas sobre volúmenes masivos de datos (cargas de trabajo **OLAP - Online Analytical Processing**). Su propósito no es la consistencia transaccional, sino la velocidad vertiginosa en agregaciones y el descubrimiento de patrones.

### Datos a Almacenar:

* **`laps_enriched_final` (Tabla Principal):** Este es el corazón de nuestro análisis. Contiene la telemetría detallada por vuelta y sector, completamente desnormalizada con datos de eventos.
  - **Optimización**: Particionada por `EventDate`, Clustering por `["Driver", "EventName", "Country"]`
  - **Filas**: 125,205 | **Tamaño**: 124.87 MB

* **`weather`**: Datos meteorológicos a lo largo del tiempo, cruciales para el análisis contextual.
  - **Optimización**: Clustering por `["EventName", "Year", "SessionName"]`
  - **Filas**: 19,192 | **Tamaño**: 1.99 MB

* **`race_control`**: Mensajes de control de carrera para correlacionar eventos con datos de vuelta.
  - **Optimización**: Clustering por `["EventName", "Year", "Category"]`
  - **Filas**: 10,479 | **Tamaño**: 1.21 MB

* **`results`** (Tabla de conveniencia): Aunque los resultados se pueden derivar de los datos de vueltas, tener esta tabla pre-calculada en BigQuery simplificará enormemente la creación de visualizaciones de resumen en herramientas de BI como Looker.
  - **Optimización**: Clustering por `["Abbreviation", "EventName", "Year"]`
  - **⚠️ NOTA**: El campo del piloto se llama `Abbreviation` (no `Driver` como en laps_enriched)
  - **Filas**: 2,558 | **Tamaño**: 0.79 MB

**Referencia completa**: Ver `3projectContext/bigquery_schema_reference.md` para detalles de campos y queries optimizadas.

### Justificación Técnica:

* **Almacenamiento Columnar:** A diferencia de PostgreSQL, BigQuery almacena los datos por columnas. Cuando ejecutamos `AVG(Velocidad_Media)`, BigQuery lee *únicamente* el archivo de la columna `Velocidad_Media`, ignorando todas las demás. Esto reduce drásticamente el I/O y acelera las consultas por órdenes de magnitud.
* **Escalabilidad Masiva:** Es una plataforma *serverless* que distribuye el trabajo de una consulta entre miles de nodos. Podemos analizar petabytes de datos en segundos sin gestionar ninguna infraestructura.
* **Optimizado para BI y Analítica:** Es el backend ideal para herramientas como Looker. Permite a los analistas (en este caso, nosotros) explorar, filtrar, agregar y visualizar los datos de forma interactiva para responder a las preguntas de negocio.

### Tip de Implementación: Desnormalización

Para optimizar aún más las consultas en BigQuery y evitar *joins* costosos en tiempo de ejecución, durante el proceso de **ETL (Extract, Transform, Load)**, enriqueceremos nuestra tabla principal de `laps` con las columnas de contexto más importantes de las tablas `events` y `sessions`. De esta forma, nuestra tabla principal de análisis será una tabla "ancha" que contendrá todo lo necesario para la mayoría de las consultas, haciendo el análisis aún más rápido.

---

## 4. Componente 3: La Base de Datos Key-Value (Amazon DynamoDB)

### Rol: "La Capa de Acceso de Ultra Baja Latencia"

Este componente aborda un caso de uso completamente diferente al del analista: el de una **aplicación de cara al usuario final** (ej. una app para comentaristas de TV, un widget en un sitio web de fans). Estas aplicaciones no necesitan análisis complejos; necesitan respuestas predefinidas e instantáneas. DynamoDB nos proporcionará un acceso a datos con latencias de milisegundos de un solo dígito.

### Datos a Almacenar:

No se almacenará ningún CSV directamente. En su lugar, DynamoDB contendrá **agregados y perfiles pre-calculados**, generados a partir de los análisis realizados en BigQuery. Por ejemplo:

* **Tabla:** `DriverProfiles`
* **Clave Primaria (Key):** `DriverID` (ej: "PER")
* **Valor (Value):** Un documento JSON con estadísticas clave:
    ```json
    {
      "fullName": "Sergio Pérez",
      "totalWins": 6,
      "bestTrack": "Baku",
      "tyreManagementIndex": 8.5,
      "wetWeatherRating": 9.0,
      "lastRacePosition": 2
    }
    ```
### Justificación Técnica:

La necesidad de DynamoDB se justifica al entender que nuestra plataforma sirve a dos perfiles de usuario fundamentalmente distintos, con necesidades opuestas. Aquí es donde aplicamos la filosofía del **"Laboratorio Analítico vs. El Marcador Público"**.

**1. El Laboratorio Analítico (BigQuery + Looker):**
* **Usuario:** El estratega del equipo, el analista de datos.
* **Necesidad:** Máxima flexibilidad para explorar, descubrir patrones, cruzar variables y responder preguntas complejas e imprevistas.
* **Tolerancia:** Puede esperar segundos o minutos por una respuesta, ya que el valor reside en la profundidad del análisis, no en la inmediatez.
* **Función:** Este es el entorno donde se realizan cientos de análisis exploratorios. La gran mayoría de estos insights son para consumo interno y se quedan "en el laboratorio".

**2. El Marcador Público (DynamoDB + API):**
* **Usuario:** Una aplicación de cara al público (App de comentaristas, Fans, etc.).
* **Necesidad:** Acceso instantáneo a un conjunto pequeño y curado de métricas clave predefinidas (el perfil del piloto).
* **Tolerancia:** Cero. La respuesta debe estar en milisegundos para que la aplicación se sienta fluida y en tiempo real.
* **Función:** Este es el "escaparate" o el "marcador del estadio". De los cientos de análisis del laboratorio, solo se "productizan" unos pocos insights finales. Estos resultados pre-calculados se almacenan aquí para una recuperación ultra-rápida.

**Conclusión de la Justificación:**

DynamoDB no es un repositorio para todos los resultados de los análisis. Es una **capa de servicio de baja latencia** que contiene únicamente un subconjunto curado de los insights más valiosos, pre-calculados en BigQuery. Esta separación de cargas de trabajo es una práctica de arquitectura fundamental que asegura que las consultas analíticas pesadas (OLAP) nunca impacten el rendimiento de las aplicaciones operativas (OLTP/Key-Value). Su diseño basado en `Clave-Valor` nos obliga a pensar primero en los patrones de acceso, garantizando un rendimiento predecible para las consultas que sí hemos planificado.

---

## 5. Conclusión de la Arquitectura

Esta arquitectura de tres capas nos proporciona una solución robusta y profesional:

* **PostgreSQL** nos da una base sólida y consistente.
* **BigQuery** nos da el poder ilimitado para hacer descubrimientos analíticos.
* **DynamoDB** nos da la velocidad para servir esos descubrimientos a una aplicación en tiempo real.

Al utilizar la herramienta adecuada para cada trabajo, estamos construyendo un sistema que no solo cumple con los requisitos del proyecto, sino que también sigue las mejores prácticas de la industria para la construcción de plataformas de datos modernas y escalables.

---

## 6. Definiciones y Métricas Derivadas

Esta sección documenta la lógica de negocio y las metodologías propuestas para crear las métricas y *insights* clave del proyecto. Estas definiciones son el puente entre los datos en crudo y las conclusiones estratégicas.

### 6.1. Clasificación de Sectores por Velocidad

**Problema:** Los datos en crudo no nos informan sobre la topología de un circuito (ej: si un sector es de "curvas lentas" o "rectas largas").

**Solución Propuesta:** Crearemos una clasificación propia (una métrica "proxy") basada en los datos de telemetría que sí tenemos. Durante una fase de análisis exploratorio, calcularemos la distribución de la velocidad promedio (`SectorX_Speed_Avg`) de todos los sectores de todos los circuitos en la temporada. Basado en esta distribución, propondremos una clasificación por percentiles:

* **Sector de Baja Velocidad (Técnico):** Cualquier sector cuyo `Speed_Avg` se encuentre en el tercio inferior (percentil 0-33) de todas las velocidades promedio de la temporada.
* **Sector de Velocidad Media (Mixto):** Cualquier sector cuyo `Speed_Avg` se encuentre en el tercio medio (percentil 34-66).
* **Sector de Alta Velocidad (Rápido):** Cualquier sector cuyo `Speed_Avg` se encuentre en el tercio superior (percentil 67-100).

**Uso:** Esta clasificación nos permitirá analizar el rendimiento de un piloto de manera contextual. Por ejemplo, podremos calcular su rendimiento relativo en "Sectores Técnicos" y determinar si es una de sus fortalezas, proporcionando un *insight* mucho más rico que un simple tiempo de vuelta.

*(Nota: Esta es una propuesta inicial. Los umbrales exactos de los percentiles pueden ser ajustados durante la fase de análisis para obtener la clasificación más significativa.)*