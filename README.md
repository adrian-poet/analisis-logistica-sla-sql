# Optimización de Operaciones Logísticas y Cumplimiento de SLA en SQL

## 📈 Visión General del Proyecto
Este proyecto presenta un modelo analítico avanzado desarrollado en SQL enfocado en la **auditoría de procesos logísticos, control de acuerdos de nivel de servicio (SLA) y análisis de riesgo financiero por demoras**. A través de un enfoque modular, el modelo transforma eventos de logs de transportes crudos en un panel estructurado de insights operativos y comerciales.

El script está diseñado para responder tres preguntas críticas de negocio:
1. ¿En qué hitos específicos del proceso de distribución se generan los mayores cuellos de botella?
2. ¿Cuál es el impacto financiero directo (Monto USD implicado) de los pedidos demorados?
3. ¿Quiénes son nuestros clientes estratégicos (Pareto A) que están experimentando peores niveles de servicio?

---

## 🛠️ Tecnologías y Conceptos Avanzados Aplicados
- **Lenguaje:** T-SQL / SQL Server.
- **Ventanas Analíticas (Window Functions):** Uso de `LAG()` para calcular tiempos entre hitos secuenciales y `SUM() OVER()` para cálculo de métricas acumuladas y distribuciones porcentuales.
- **Abstracción de Lógica:** Implementación de Vistas (`CREATE VIEW`) para centralizar las reglas de negocio del SLA y garantizar la reutilización del código.
- **Estructuras de Control y Modularidad:** Uso extensivo de Common Table Expressions (`CTEs`) anidadas para mantener un código limpio, legible y de alta mantenibilidad.
- **Estrategia Comercial:** Segmentación ABC de Pareto analizando concentración de ingresos vs performance de entrega.

---

## 📐 Estructura del Modelo Analítico (5 Capas de Insights)

El script se divide estratégicamente en las siguientes secciones secuenciales:

### 1. Análisis de Hitos de Proceso
Calcula dinámicamente el tiempo transcurrido (en horas decimales) entre cada etapa del flujo de un pedido utilizando `LAG()`. Compara la duración real contra el `tiempo_deseado` parametrizado para clasificar el estado de cada hito como *'A Tiempo'*, *'Demorado'* o *'Inicio'*.

### 2. Auditoría de Cumplimiento de SLA (Vista Centralizada)
Agrupa los logs por pedido para capturar de forma exacta el ciclo total: `Fecha_Pedido`, `Fecha_Prometida` y `Fecha_Llegada`. Clasifica el cumplimiento global de la orden y determina el peso financiero que representa cada pedido sobre el total de la facturación de la compañía a través de variables ponderadas.

### 3. Operatividad y KPI Logístico General
Una consulta de alto nivel gerencial que consolida el volumen total de pedidos y el monto económico implicado agrupados por su clasificación de SLA. Permite dimensionar de un vistazo qué porcentaje de la facturación global se encuentra en riesgo debido a ineficiencias logísticas.

### 4. Matriz de Impacto Cliente - SLA
Cruza el estado de cumplimiento logístico con la cartera de clientes. Permite identificar de manera granular qué cuentas están sufriendo las mayores demoras y el volumen de dinero involucrado en dichas incidencias, facilitando la priorización en mesas de atención al cliente.

### 5. Diagnóstico de Desvíos por Hito y Pareto ABC de Clientes
- **Performance de Etapas:** Ejecuta agregaciones para calcular el desvío promedio en horas por hito, detectando las fases del proceso de distribución con mayor tasa y porcentaje de demoras.
- **Segmentación Pareto ABC:** Clasifica a los clientes según sus ingresos acumulados utilizando ventanas ordenadas. Esto permite aislar al **Grupo A** (clientes críticos que aportan el 80% del valor del negocio) para cruzarlo con sus tasas de SLA y evitar penalizaciones o fugas de cuentas principales (`Churn`).
