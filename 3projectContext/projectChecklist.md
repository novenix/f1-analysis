# Checklist para el Proyecto Final - Tópicos Avanzados en BD

## Fase 1: Planificación y Definición del Proyecto

- [x] **Conformar el Equipo de Trabajo (3-5 personas):**
    - [x] Definir roles y responsabilidades.
    - [x] Establecer canales de comunicación (Slack, Discord, etc.).
    - [x] Sincronizar horarios y definir un cronograma de reuniones.

- [x] **Seleccionar el Conjunto de Datos:**
    - [x] Explorar fuentes de datos (Kaggle, Datos Abiertos, etc.).
    - [x] Elegir un dataset que sea lo suficientemente rico y complejo para el proyecto.
    - [x] Realizar un análisis exploratorio inicial para entender las variables disponibles.

- [ ] **Definir el Problema de Negocio:**
    - [ ] Identificar un problema o área de oportunidad a resolver con los datos seleccionados.
    - [ ] Formular entre **3 y 5 preguntas de negocio** claras y concisas que guiarán el desarrollo. *Ej: ¿Cuál es el impacto de la estrategia de neumáticos en el resultado de una carrera?*

- [ ] **Definir el Alcance del Proyecto:**
    - [ ] Describir qué hará (y qué no hará) la aplicación final.
    - [ ] Establecer los objetivos y entregables clave.

- [ ] **Configurar el Entorno de Desarrollo y Repositorio:**
    - [ ] Crear un repositorio en Git (GitHub, GitLab).
    - [ ] Definir la metodología de trabajo (Agile, Kanban) y herramientas de gestión (Trello, Jira).

## Fase 2: Arquitectura y Diseño de Datos

- [ ] **Seleccionar las 3 Bases de Datos:**
    - [ ] Basado en las preguntas de negocio y la naturaleza de los datos, elegir **al menos 3 tipos de BD vistos en clase** (Relacional, Key-Value, Columnar, Documental, etc.).
    - [ ] **Justificar la elección de cada base de datos:** ¿Por qué es la mejor opción para esa parte específica del problema? *Ej: Usaremos una BD de series de tiempo para telemetría, una relacional para resultados y una documental para metadatos de los eventos.*

- [ ] **Diseñar la Arquitectura de la Solución:**
    - [ ] Crear un diagrama de arquitectura que muestre cómo se conectan las bases de datos, la capa de aplicación (API) y la capa cliente (visualización).
    - [ ] Definir los flujos de datos: ¿Cómo se ingieren los datos? ¿Cómo se procesan y almacenan en cada BD?

- [ ] **Modelado de Datos para cada Base de Datos:**
    - [ ] **BD Relacional (PostgreSQL/MySQL):** Diseñar el esquema entidad-relación (tablas, columnas, relaciones, llaves primarias/foráneas).
    - [ ] **BD NoSQL (MongoDB, DynamoDB, etc.):** Diseñar la estructura de los documentos, las claves de partición/ordenamiento, o el esquema de columnas según corresponda.
    - [ ] Definir cómo se relacionarán o consultarán los datos entre las diferentes bases de datos.

## Fase 3: Desarrollo e Implementación

- [ ] **Ingesta y Procesamiento de Datos (ETL):**
    - [ ] Desarrollar scripts para leer los archivos CSV (o la fuente de datos).
    - [ ] Limpiar, transformar y enriquecer los datos según sea necesario.
    - [ ] Cargar los datos procesados en las bases de datos correspondientes.

- [ ] **Configurar e Instanciar las Bases de Datos:**
    - [ ] Instalar y configurar los motores de las 3 bases de datos seleccionadas (localmente o en la nube).

- [ ] **Desarrollar la Capa de Aplicación (Backend/API):**
    - [ ] Crear una API (REST, GraphQL) que exponga los datos de las bases de datos.
    - [ ] Implementar los endpoints necesarios para responder a cada una de las preguntas de negocio. *Ej: un endpoint `/api/race/{raceId}/tyre-strategy` que consulte la información de neumáticos.*

- [ ] **Desarrollar la Capa Cliente (Frontend/Visualización):**
    - [ ] Crear una interfaz de usuario (puede ser simple) o un dashboard.
    - [ ] Implementar visualizaciones (gráficas, tablas) que muestren las respuestas a las preguntas de negocio de manera clara.
    - [ ] Conectar el cliente a la API para consumir los datos.

## Fase 4: Pruebas y Evaluación

- [ ] **Realizar Pruebas Funcionales:**
    - [ ] Verificar que la API devuelve los datos correctos.
    - [ ] Asegurar que la capa cliente muestra la información como se espera.
    - [ ] Probar los flujos de usuario clave.

- [ ] **Evaluar el Rendimiento (Opcional pero recomendado):**
    - [ ] Medir los tiempos de respuesta de las consultas en cada base de datos.
    - [ ] Analizar si el diseño del modelo de datos fue eficiente.

- [ ] **Analizar los Resultados:**
    - [ ] Validar si las respuestas obtenidas a través de la aplicación son coherentes y responden efectivamente a las preguntas de negocio planteadas.
    - [ ] Documentar hallazgos importantes o inesperados.

## Fase 5: Documentación y Presentación

- [ ] **Elaborar el Reporte Escrito (`reporte.pdf`):**
    - [ ] **Introducción:** Contexto, problema y preguntas de negocio.
    - [ ] **Dataset:** Descripción de la fuente y estructura de los datos.
    - [ ] **Arquitectura Propuesta:** Incluir el diagrama de arquitectura y la justificación detallada de cada BD elegida.
    - [ ] **Modelo de Datos:** Explicar el diseño específico para cada una de las bases de datos.
    - [ ] **Resultados y Análisis:** Presentar las respuestas a las preguntas de negocio, apoyándose en las visualizaciones creadas.
    - [ ] **Desafíos Técnicos:** Describir los principales obstáculos encontrados y cómo se solucionaron.
    - [ ] **Conclusiones y Trabajo Futuro.**

- [ ] **Grabar el Video de Presentación (10 minutos):**
    - [ ] **(1-2 min) Arquitectura y Decisiones Clave:** Mostrar el diagrama y justificar las elecciones tecnológicas.
    - [ ] **(5-6 min) Demo en Vivo:** Mostrar la aplicación funcionando, enfocándose en cómo resuelve las preguntas de negocio.
    - [ ] **(2-3 min) Resultados y Desafíos:** Resumir los hallazgos y los retos superados.

- [ ] **Preparar la Entrega Final:**
    - [ ] Subir el video a una plataforma (YouTube, Loom).
    - [ ] Empaquetar el código fuente, el reporte en PDF y el enlace al video en un archivo `.zip`.
    - [ ] Realizar la entrega según las indicaciones del curso.