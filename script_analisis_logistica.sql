--ANALISIS HITOS
WITH Fecha AS(
select 
	p.id_pedido,
	p.id_cliente,
	p.nombre_cliente,
	p.producto,
	p.unidades,
	p.proceso_hito,
	p.fecha_hora_evento,
	LAG(fecha_hora_evento) OVER(Partition by id_pedido ORDER BY fecha_hora_evento) AS fecha_anterior,
	p.tiempo_deseado
from pedidos_logistica p
),
Diferencia_Horas AS(
Select 
	*,
	DATEDIFF(MINUTE, fecha_anterior, fecha_hora_evento) / 60.0 AS horas_transcurridas
FROM Fecha		
)
Select
	id_pedido,
	id_cliente,
	nombre_cliente,
	producto,
	unidades,
	proceso_hito,
	fecha_hora_evento,
	CASE 
        WHEN proceso_hito LIKE '%1. Flux Pedido%' THEN 'Inicio'
        ELSE CAST(CAST(horas_transcurridas AS DECIMAL(10,2)) AS VARCHAR(20))
    END AS horas_transcurridas,
  
    CASE 
        WHEN proceso_hito LIKE '%1. Flux Pedido%' THEN 'Inicio'
        ELSE CAST(CAST(tiempo_deseado AS DECIMAL(10,2)) AS VARCHAR(20))
    END AS tiempo_deseado,
	CASE
		WHEN proceso_hito LIKE '%1. Flux Pedido%' THEN 'Inicio'
		WHEN horas_transcurridas > tiempo_deseado THEN 'Demorado'
		WHEN horas_transcurridas <= tiempo_deseado THEN 'A Tiempo'
		Else 'Revisar'
		END AS estado_etapa
FROM Diferencia_Horas

---------------------------------------------------------------------------------------
--ANALISIS SLA---  Luego creamos vista del scrip para reutilizar el scrip (Vista_SLA)
Create VIEW Vista_SLA AS

WITH Fechas As(
select 
	pl.id_pedido,
	pl.id_cliente,
	pl.nombre_cliente,
	pl.producto,
	pl.unidades,
	pl.monto_unitario_usd,
	(pl.unidades * pl.monto_unitario_usd) AS Monto_total_Factura, 
	MIN(pl.fecha_hora_evento) AS Fecha_Pedido,
	MAX(pl.fecha_hora_prometida) AS Fecha_Prometida,
	MAX(CASE WHEN pl.proceso_hito LIKE '%5. Fecha de Llegada%' THEN pl.fecha_hora_evento END) AS Fecha_Llegada
from pedidos_logistica pl
GROUP BY pl.id_pedido,pl.id_cliente,pl.nombre_cliente,pl.producto,pl.unidades,pl.monto_unitario_usd
),
Entregas AS(
Select 
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
	ROUND(DATEDIFF(MINUTE, Fecha_Pedido, Fecha_Prometida) / CAST(60.0 AS FLOAT),2) AS horas_prometida,
	ROUND(DATEDIFF(MINUTE,Fecha_Pedido, Fecha_Llegada) / CAST(60.0 AS FLOAT),2) AS horas_real
FROM Fechas f
),
SLA AS(
Select 
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
	CASE
	WHEN Fecha_Llegada IS NULL THEN 'En Camino'
	WHEN horas_real <= horas_prometida THEN 'A Tiempo'
	WHEN horas_real > horas_prometida THEN 'Demorado'
	ELSE 'Revisar'
	END AS CLasificacion_SLA,
	Monto_total_Factura,
	ROUND((Monto_total_Factura / SUM(CAST(Monto_total_Factura AS FLOAT)) OVER () * 100),2) AS Porcentaje_Monto_Implicado
From Entregas)
Select 
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
	CASE
		WHEN dif_tiempo_hs > 0 THEN 'Demorado por ' + CAST(dif_tiempo_hs AS VARCHAR(10)) +  ' hs'
		WHEN dif_tiempo_hs <= 0 THEN 'A tiempo por '  + CAST(ABS(dif_tiempo_hs) AS VARCHAR(10)) +  ' hs'
		ELSE 'En camino'
		END AS resumen_logistica,
	Monto_total_Factura,
	Porcentaje_Monto_Implicado
from SLA

-------------------------
--Operatividad Logistica (Vista_SLA)
  
WITH Analisis AS (
Select 
	CLasificacion_SLA,
	COUNT(*) AS Pedidos,
	SUM(Monto_total_Factura) AS Monto_Implicado
FROM Vista_SLA
GROUP BY CLasificacion_SLA
)
Select
	CLasificacion_SLA,
	Pedidos,
	ROUND((Pedidos / SUM(CAST(Pedidos AS FLOAT)) OVER()) * 100,2) AS Porcentaje_Pedidos,
	Monto_Implicado,
	ROUND(Monto_Implicado / SUM(CAST(Monto_Implicado AS FLOAT)) OVER() * 100,2) AS Porcentaje_Monto
From Analisis

-----------------
--ANALISIS CLIENTE - Clasificacion SLA - (Vista_SLA)
WITH Resumen AS (
SELECT 
	id_cliente,
	nombre_cliente,
	CLasificacion_SLA,
	COUNT(*) AS Pedidos,
	SUM(Monto_total_Factura) AS Monto_Implicado
FROM Vista_SLA
Group by CLasificacion_SLA, id_cliente, nombre_cliente
)
Select 
	id_cliente,
	nombre_cliente,
	CLasificacion_SLA,
	Pedidos,
	ROUND(Pedidos / SUM(CAST(Pedidos AS FLOAT)) OVER() * 100,2) AS Porcentaje_Pedidos,
	Monto_Implicado,
	ROUND(Monto_Implicado / SUM(CAST(Monto_Implicado AS FLOAT)) OVER() * 100,2) AS Monto_Involucrado
FROM Resumen
ORDER BY Monto_Implicado DESC

-------------------------
--Analisis por Hito
  
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
    WHERE proceso_hito NOT LIKE '%1. Flux Pedido%' -- Excluimos el inicio ya que no tiene etapa anterior
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

------------------------------------------------------
--Analisis por Cliente (Vista_SLA)

WITH Detalle AS(
select 
	id_cliente,
	nombre_cliente,
	COUNT(id_pedido) AS Cantidad_Compras,
	SUM(Monto_total_Factura) AS Monto_Total
from Vista_SLA
GROUP BY id_cliente, nombre_cliente
),
Totales AS(
Select 
	*, 
	ROUND(Monto_Total / SUM(CAST(Monto_Total AS FLOAT)) OVER() * 100,2) AS Porcentaje_Monto 
From Detalle
),
Porcentaje AS(
Select 
	*,
	SUM(Porcentaje_Monto) OVER (ORDER BY Monto_Total DESC) AS Porcentaje_Acumulado
from Totales
)
Select 
	*,
	CASE
		WHEN Porcentaje_Acumulado <= 80 THEN 'A'
		WHEN Porcentaje_Acumulado <= 95 THEN 'B'
		ELSE 'C'
		END AS Pareto_ABC,
	DENSE_RANK() OVER (ORDER BY Porcentaje_Acumulado ASC) AS Principales_Clientes
FROM Porcentaje
