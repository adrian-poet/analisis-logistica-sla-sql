/*
================================================================================
PROYECTO: Logística - Análisis de SLA y Cuellos de Botella
AUTOR: Adrián Poet | Data Analyst & BI Specialist
FECHA: Junio 2026
DESCRIPCIÓN: Script analítico avanzado para la optimización de la cadena de suministro.
             Aplana eventos de hitos lógicos en registros únicos por pedido, 
             mide desvíos contra Service Level Agreements (SLA), calcula el impacto 
             financiero en riesgo y clasifica estratégicamente la cartera de clientes.
================================================================================
*/

-- =============================================================================
-- FASE 1: ANÁLISIS ATÓMICO POR HITO (AUDITORÍA DE TIEMPOS ENTRE ETAPAS)
-- =============================================================================

WITH Fecha AS (
    SELECT 
        p.id_pedido,
        p.id_cliente,
        p.nombre_cliente,
        p.producto,
        p.unidades,
        p.proceso_hito,
        p.fecha_hora_evento,
        -- Identificación del evento inmediato anterior para calcular tiempos de ciclo
        LAG(p.fecha_hora_evento) OVER(PARTITION BY p.id_pedido ORDER BY p.fecha_hora_evento) AS fecha_anterior,
        p.tiempo_deseado
    FROM pedidos_logistica p
),
Diferencia_Horas AS (
    SELECT 
        *,
        DATEDIFF(MINUTE, fecha_anterior, fecha_hora_evento) / 60.0 AS horas_transcurridas
    FROM Fecha		
)
SELECT
    id_pedido,
    id_cliente,
    nombre_cliente,
    producto,
    unidades,
    proceso_hito,
    fecha_hora_evento,
    -- Normalización estética para omitir cálculos en el hito de origen
    CASE 
        WHEN proceso_hito LIKE '%1. Flux Pedido%' THEN 'Inicio'
        ELSE CAST(CAST(horas_transcurridas AS DECIMAL(10,2)) AS VARCHAR(20))
    END AS horas_transcurridas,
    CASE 
        WHEN proceso_hito LIKE '%1. Flux Pedido%' THEN 'Inicio'
        ELSE CAST(CAST(tiempo_deseado AS DECIMAL(10,2)) AS VARCHAR(20))
    END AS tiempo_deseado,
    -- Evaluación de cumplimiento del Service Target por etapa
    CASE
        WHEN proceso_hito LIKE '%1. Flux Pedido%' THEN 'Inicio'
        WHEN horas_transcurridas > tiempo_deseado THEN 'Demorado'
        WHEN horas_transcurridas <= tiempo_deseado THEN 'A Tiempo'
        ELSE 'Revisar'
    END AS estado_etapa
FROM Diferencia_Horas;


-- =============================================================================
-- FASE 2: MODELADO VISTA DE CUMPLIMIENTO GLOBAL DE SLA
-- =============================================================================

CREATE VIEW Vista_SLA AS
WITH Fechas AS (
    SELECT 
        pl.id_pedido,
        pl.id_cliente,
        pl.nombre_cliente,
        pl.producto,
        pl.unidades,
        pl.monto_unitario_usd,
        (pl.unidades * pl.monto_unitario_usd) AS Monto_total_Factura, 
        -- Captura de hitos temporales críticos mediante agregación condicional
        MIN(pl.fecha_hora_evento) AS Fecha_Pedido,
        MAX(pl.fecha_hora_prometida) AS Fecha_Prometida,
        MAX(CASE WHEN pl.proceso_hito LIKE '%5. Fecha de Llegada%' THEN pl.fecha_hora_evento END) AS Fecha_Llegada
    FROM pedidos_logistica pl
    GROUP BY pl.id_pedido, pl.id_cliente, pl.nombre_cliente, pl.producto, pl.unidades, pl.monto_unitario_usd
),
Entregas AS (
    SELECT 
        id_pedido,
        id_cliente,
        nombre_cliente,
        producto,
        unidades,
        monto_unitario_usd,
        Monto_total_Factura,
        Fecha_Pedido,
        Fecha_Prometida,
        Fecha_Llegada,
        ROUND(DATEDIFF(MINUTE, Fecha_Pedido, Fecha_Prometida) / CAST(60.0 AS FLOAT), 2) AS horas_prometida,
        ROUND(DATEDIFF(MINUTE, Fecha_Pedido, Fecha_Llegada) / CAST(60.0 AS FLOAT), 2) AS horas_real
    FROM Fechas
),
SLA AS (
    SELECT 
        id_pedido,
        id_cliente,
        nombre_cliente,
        producto,
        unidades,
        monto_unitario_usd,
        Fecha_Pedido,
        Fecha_Prometida,
        Fecha_Llegada,
        horas_prometida,
        horas_real,
        horas_real - horas_prometida AS dif_tiempo_hs,
        -- Clasificación del SLA basado en la ventana de entrega final prometida
        CASE
            WHEN Fecha_Llegada IS NULL THEN 'En Camino'
            WHEN horas_real <= horas_prometida THEN 'A Tiempo'
            WHEN horas_real > horas_prometida THEN 'Demorado'
            ELSE 'Revisar'
        END AS CLasificacion_SLA,
        Monto_total_Factura,
        -- Medición de la participación financiera de cada pedido sobre el global facturado
        ROUND((Monto_total_Factura / SUM(CAST(Monto_total_Factura AS FLOAT)) OVER () * 100), 2) AS Porcentaje_Monto_Implicado
    FROM Entregas
)
SELECT 
    id_pedido,
    id_cliente,
    nombre_cliente,
    producto,
    unidades,
    monto_unitario_usd,
    Fecha_Pedido,
    Fecha_Prometida,
    Fecha_Llegada,
    horas_prometida,
    horas_real,
    dif_tiempo_hs,
    CLasificacion_SLA,
    -- Generación de string ejecutivo de diagnóstico operativo para logistica
    CASE
        WHEN dif_tiempo_hs > 0 THEN 'Demorado por ' + CAST(dif_tiempo_hs AS VARCHAR(10)) + ' hs'
        WHEN dif_tiempo_hs <= 0 THEN 'A tiempo por ' + CAST(ABS(dif_tiempo_hs) AS VARCHAR(10)) + ' hs'
        ELSE 'En camino'
    END AS resumen_logistica,
    Monto_total_Factura,
    Porcentaje_Monto_Implicado
FROM SLA;


-- =============================================================================
-- FASE 3: EXTRACCIÓN DE METRICAS OPERATIVAS Y FINANCIERAS
-- =============================================================================

/* 
   Métrica A: Operatividad Logística General
   Determina el volumen total y porcentual de pedidos demorados vs. a tiempo, cruzándolo con el monto total en riesgo.
*/
WITH Analisis AS (
    SELECT 
        CLasificacion_SLA,
        COUNT(*) AS Pedidos,
        SUM(Monto_total_Factura) AS Monto_Implicado
    FROM Vista_SLA
    GROUP BY CLasificacion_SLA
)
SELECT
    CLasificacion_SLA,
    Pedidos,
    ROUND((Pedidos / SUM(CAST(Pedidos AS FLOAT)) OVER()) * 100, 2) AS Porcentaje_Pedidos,
    Monto_Implicado,
    ROUND(Monto_Implicado / SUM(CAST(Monto_Implicado AS FLOAT)) OVER() * 100, 2) AS Porcentaje_Monto
FROM Analisis;


/* 
   Métrica B: Degradación del SLA por Cuenta de Cliente
   Segmenta el volumen de cumplimiento de entregas permitiendo aislar qué cuentas sufren las mayores demoras.
*/
WITH Resumen AS (
    SELECT 
        id_cliente,
        nombre_cliente,
        CLasificacion_SLA,
        COUNT(*) AS Pedidos,
        SUM(Monto_total_Factura) AS Monto_Implicado
    FROM Vista_SLA
    GROUP BY CLasificacion_SLA, id_cliente, nombre_cliente
)
SELECT 
    id_cliente,
    nombre_cliente,
    CLasificacion_SLA,
    Pedidos,
    ROUND(Pedidos / SUM(CAST(Pedidos AS FLOAT)) OVER() * 100, 2) AS Porcentaje_Pedidos,
    Monto_Implicado,
    ROUND(Monto_Implicado / SUM(CAST(Monto_Implicado AS FLOAT)) OVER() * 100, 2) AS Monto_Involucrado
FROM Resumen
ORDER BY Monto_Implicado DESC;


/* 
   Métrica C: Diagnóstico de Cuellos de Botella por Hito Operativo
   Mide desvíos promedio de horas reales vs. targets y tasa de fallos acumulada por etapa.
   Identifica los hitos físicos que ralentizan la operación (ej. Carga y Despacho).
*/
WITH Fecha AS (
    SELECT
        id_pedido,
        proceso_hito,
        fecha_hora_evento,
        LAG(fecha_hora_evento) OVER(PARTITION BY id_pedido ORDER BY fecha_hora_evento) AS fecha_anterior,
        tiempo_deseado
    FROM pedidos_logistica
),
Diferencia_Horas AS (
    SELECT
        proceso_hito,
        tiempo_deseado,
        DATEDIFF(MINUTE, fecha_anterior, fecha_hora_evento) / 60.0 AS horas_transcurridas
    FROM Fecha
    -- Se excluye el origen de la cadena logística por carecer de hito previo
    WHERE proceso_hito NOT LIKE '%1. Flux Pedido%' 
)
SELECT
    proceso_hito AS Etapa,
    COUNT(*) AS Total_Eventos,
    ROUND(AVG(horas_transcurridas), 2) AS Promedio_Horas_Reales,
    ROUND(AVG(CAST(tiempo_deseado AS FLOAT)), 2) AS Promedio_Tiempo_Deseado,
    ROUND(AVG(horas_transcurridas - CAST(tiempo_deseado AS FLOAT)), 2) AS Desvio_Promedio_Hs,
    SUM(CASE WHEN horas_transcurridas > tiempo_deseado THEN 1 ELSE 0 END) AS Cantidad_Demoras,
    ROUND((SUM(CASE WHEN horas_transcurridas > tiempo_deseado THEN 1 ELSE 0 END) / CAST(COUNT(*) AS FLOAT)) * 100, 2) AS Porcentaje_Demoras
FROM Diferencia_Horas
GROUP BY proceso_hito;


/* 
   Métrica D: Clasificación Estratégica de Cartera (Modelo Pareto ABC)
   Ranking denso y acumulación financiera por cliente para priorizar cuentas de alto valor expuestas a quiebres de SLA.
*/
WITH Detalle AS (
    SELECT 
        id_cliente,
        nombre_cliente,
        COUNT(id_pedido) AS Cantidad_Compras,
        SUM(Monto_total_Factura) AS Monto_Total
    FROM Vista_SLA
    GROUP BY id_cliente, nombre_cliente
),
Totales AS (
    SELECT 
        *, 
        ROUND(Monto_Total / SUM(CAST(Monto_Total AS FLOAT)) OVER() * 100, 2) AS Porcentaje_Monto 
    FROM Detalle
),
Porcentaje AS (
    SELECT 
        *,
        SUM(Porcentaje_Monto) OVER (ORDER BY Monto_Total DESC) AS Porcentaje_Acumulado
    FROM Totales
)
SELECT 
    *,
    CASE
        WHEN Porcentaje_Acumulado <= 80 THEN 'A'
        WHEN Porcentaje_Acumulado <= 95 THEN 'B'
        ELSE 'C'
    END AS Pareto_ABC,
    DENSE_RANK() OVER (ORDER BY Porcentaje_Acumulado ASC) AS Principales_Clientes
FROM Porcentaje;
