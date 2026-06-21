# Analisis SLA Logistica - Mitigacion de Cuellos de Botella.

**Problema de negocio detectado** 
Al analizar la base de logistica en contre que <span style="color:red">22.22%</span> de los pedidos llegaban demorados, comprometiendo el <span style="color:red">29.54 %</span> del monto.
Mediante queries SQL identifique que el hito "<span style="color:deepskyblue">Carga y Despacho</span>" generaba <span style="color:red">+ 1.78</span> hs de retraso vs objetivo. 

**Hallazgos del analisis** 
78 % de los pedidos llegan a tiempo vs <span style="color:red">22 %</span> demorados. 
Cuello de botella principal: hito "<span style="color:deepskyblue">Carga y Despacho</span>".
Cliente Pareto A con 24.61 % de ingresos presenta demoras severas. 70.46 % del monto protegido por entregas a tiempo.

---

### 🛠️ Herramientas y Técnicas Utilizadas
* **SQL Avanzado:** Optimización de consultas para calcular desviaciones de tiempo entre hitos logísticos vs. targets operativos.
* **Análisis de Pareto (80/20):** Segmentación de clientes e impacto financiero para priorizar la toma de decisiones basada en el valor en riesgo.

* 📄 **[Ver Reporte Completo: Análisis de Avanzada en Mitigación de Cuellos de botella.pdf](./Análisis%20de%20Avanzada%20en%20Mitigación%20de%20Cuellos%20de%20botella.pdf)**

## 💻 Código Fuente
El desarrollo completo de las vistas analíticas y el script de optimización logística se encuentran disponibles para su ejecución en la sección de archivos:

* 💾 **[Ver Script SQL Completo](./script_analisis_logistica.sql)**

---
## 👤 Autor
* **Adrián Poet** - *Data Analyst & Business Intelligence Specialist*
* [LinkedIn](https://www.linkedin.com/in/adrian-poet)
