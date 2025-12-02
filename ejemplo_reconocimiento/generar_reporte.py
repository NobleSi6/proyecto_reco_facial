import pandas as pd
import os
from datetime import datetime

def generar_reporte_mensual():
    """Genera un reporte mensual de asistencia"""
    
    archivo_asistencia = 'registro_asistencia.xlsx'
    
    if not os.path.exists(archivo_asistencia):
        print("No existe el archivo de asistencia.")
        return
    
    # Cargar datos
    df = pd.read_excel(archivo_asistencia)
    
    # Solicitar mes y año
    mes = input("Ingrese el mes (1-12): ")
    año = input("Ingrese el año (YYYY): ")
    
    try:
        mes = int(mes)
        año = int(año)
        
        # Filtrar columnas del mes especificado
        columnas_mes = [col for col in df.columns if f"{año}-{mes:02d}" in col]
        
        if not columnas_mes:
            print(f"No hay datos para {mes}/{año}")
            return
        
        # Crear reporte
        reporte = df[['Codigo', 'Nombre'] + columnas_mes].copy()
        
        # Calcular total de asistencias
        reporte['Total_Asistencias'] = reporte[columnas_mes].notna().sum(axis=1)
        reporte['Porcentaje_Asistencia'] = (reporte['Total_Asistencias'] / len(columnas_mes)) * 100
        
        # Guardar reporte
        nombre_reporte = f"reporte_asistencia_{año}_{mes:02d}.xlsx"
        reporte.to_excel(nombre_reporte, index=False)
        
        print(f"\nReporte generado: {nombre_reporte}")
        print(f"Total de días en el mes: {len(columnas_mes)}")
        print(f"Personas con 100% de asistencia: {len(reporte[reporte['Porcentaje_Asistencia'] == 100])}")
        
    except ValueError:
        print("Mes o año inválido")

def mostrar_estadisticas():
    """Muestra estadísticas generales"""
    
    archivo_asistencia = 'registro_asistencia.xlsx'
    
    if not os.path.exists(archivo_asistencia):
        print("No existe el archivo de asistencia.")
        return
    
    df = pd.read_excel(archivo_asistencia)
    
    print("\n" + "="*50)
    print("ESTADÍSTICAS DEL SISTEMA")
    print("="*50)
    
    # Columnas de fecha (excluyendo Código y Nombre)
    columnas_fecha = [col for col in df.columns if col not in ['Codigo', 'Nombre']]
    
    print(f"Total de personas registradas: {len(df)}")
    print(f"Total de días con registro: {len(columnas_fecha)}")
    
    if columnas_fecha:
        print(f"\nPrimer día registrado: {min(columnas_fecha)}")
        print(f"Último día registrado: {max(columnas_fecha)}")
        
        # Persona con más asistencias
        df['Total_Asistencias'] = df[columnas_fecha].notna().sum(axis=1)
        max_asistencias = df['Total_Asistencias'].max()
        mejores = df[df['Total_Asistencias'] == max_asistencias]
        
        print(f"\nMejor asistencia ({max_asistencias}/{len(columnas_fecha)} días):")
        for _, persona in mejores.iterrows():
            print(f"  - {persona['Nombre']} ({persona['Codigo']})")

if __name__ == "__main__":
    while True:
        print("\n" + "="*50)
        print("GENERADOR DE REPORTES")
        print("="*50)
        print("1. Generar reporte mensual")
        print("2. Mostrar estadísticas generales")
        print("3. Salir")
        
        opcion = input("\nSeleccione una opción: ")
        
        if opcion == '1':
            generar_reporte_mensual()
        elif opcion == '2':
            mostrar_estadisticas()
        elif opcion == '3':
            break
        else:
            print("Opción inválida")