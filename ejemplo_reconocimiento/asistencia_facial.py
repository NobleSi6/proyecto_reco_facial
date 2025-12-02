import cv2
import os
import pandas as pd
from datetime import datetime, timedelta
import json
import time

class SistemaAsistencia:
    def __init__(self):
        self.dataPath = 'C:/Users/Juan Jose/Desktop/Reconociemiento Facial/proyecto_reco_facial/Datos'
        self.modelo_path = 'modeloLBPHFace.xml'
        self.label_mapping_path = 'label_mapping.json'
        self.archivo_asistencia = 'registro_asistencia.xlsx'
        
        # Cargar modelo si existe
        if os.path.exists(self.modelo_path):
            self.face_recognizer = cv2.face.LBPHFaceRecognizer_create()
            self.face_recognizer.read(self.modelo_path)
            print("Modelo cargado exitosamente")
        else:
            print("ERROR: No se encontró el modelo. Ejecute primero 'entrenar_modelo.py'")
            self.face_recognizer = None
        
        # Cargar mapeo de labels
        if os.path.exists(self.label_mapping_path):
            with open(self.label_mapping_path, 'r') as f:
                self.label_mapping = json.load(f)
            # Convertir keys de string a int (porque JSON guarda keys como strings)
            self.label_mapping = {int(k): v for k, v in self.label_mapping.items()}
        else:
            self.label_mapping = {}
        
        # Clasificador de rostros
        self.faceClassif = cv2.CascadeClassifier(
            cv2.data.haarcascades + 'haarcascade_frontalface_default.xml'
        )
        
        # Variables de control
        self.asistencia_registrada = {}  # Para evitar duplicados en una sesión
        self.fecha_asistencia = None
        
    def solicitar_fecha(self):
        """Solicita la fecha para la asistencia"""
        print("\n" + "="*50)
        print("SISTEMA DE ASISTENCIA CON RECONOCIMIENTO FACIAL")
        print("="*50)
        
        fecha_hoy = datetime.now().strftime('%Y-%m-%d')
        print(f"\nFecha actual: {fecha_hoy}")
        
        while True:
            opcion = input("\n¿Desea usar la fecha actual? (s/n): ").lower()
            
            if opcion == 's':
                self.fecha_asistencia = fecha_hoy
                break
            elif opcion == 'n':
                while True:
                    fecha_input = input("Ingrese la fecha (formato YYYY-MM-DD): ")
                    try:
                        # Validar formato de fecha
                        fecha_obj = datetime.strptime(fecha_input, '%Y-%m-%d')
                        self.fecha_asistencia = fecha_input
                        break
                    except ValueError:
                        print("Formato inválido. Use YYYY-MM-DD")
                break
            else:
                print("Opción inválida. Ingrese 's' o 'n'")
        
        print(f"\nFecha seleccionada para asistencia: {self.fecha_asistencia}")
        return self.fecha_asistencia
    
    def inicializar_registro_asistencia(self):
        """Inicializa o carga el archivo de asistencia"""
        if os.path.exists(self.archivo_asistencia):
            # Cargar archivo existente
            try:
                self.df_asistencia = pd.read_excel(self.archivo_asistencia)
                print(f"Archivo de asistencia cargado: {self.archivo_asistencia}")
                
                # Verificar si la columna de la fecha existe
                if self.fecha_asistencia not in self.df_asistencia.columns:
                    # Agregar nueva columna para la fecha
                    self.df_asistencia[self.fecha_asistencia] = ''
                    print(f"Nueva columna agregada: {self.fecha_asistencia}")
            except Exception as e:
                print(f"Error al cargar archivo: {e}")
                # Crear nuevo DataFrame
                self._crear_nuevo_dataframe()
        else:
            # Crear nuevo archivo
            self._crear_nuevo_dataframe()
    
    def _crear_nuevo_dataframe(self):
        """Crea un nuevo DataFrame para asistencia"""
        # Cargar información de personas registradas
        archivo_maestro = 'registro_personas.csv'
        if os.path.exists(archivo_maestro):
            df_personas = pd.read_csv(archivo_maestro)
            self.df_asistencia = pd.DataFrame({
                'Codigo': df_personas['Codigo'],
                'Nombre': df_personas['Nombre']
            })
        else:
            # Si no hay registro maestro, crear uno básico
            self.df_asistencia = pd.DataFrame(columns=['Codigo', 'Nombre'])
        
        # Agregar columna para la fecha actual
        self.df_asistencia[self.fecha_asistencia] = ''
        print(f"Nuevo archivo de asistencia creado para {self.fecha_asistencia}")
    
    def registrar_asistencia(self, codigo, nombre):
        """Registra la asistencia de una persona"""
        if codigo in self.asistencia_registrada:
            return False  # Ya registrado en esta sesión
        
        # Marcar como registrado en esta sesión
        self.asistencia_registrada[codigo] = True
        
        # Actualizar DataFrame
        if codigo in self.df_asistencia['Codigo'].values:
            # Persona ya existe en el registro
            idx = self.df_asistencia[self.df_asistencia['Codigo'] == codigo].index[0]
            self.df_asistencia.at[idx, self.fecha_asistencia] = datetime.now().strftime('%H:%M:%S')
        else:
            # Nueva persona (agregar fila)
            nueva_fila = {
                'Codigo': codigo,
                'Nombre': nombre,
                self.fecha_asistencia: datetime.now().strftime('%H:%M:%S')
            }
            self.df_asistencia = pd.concat([self.df_asistencia, pd.DataFrame([nueva_fila])], ignore_index=True)
        
        # Guardar inmediatamente
        self.guardar_asistencia()
        
        return True
    
    def guardar_asistencia(self):
        """Guarda el registro de asistencia en Excel"""
        try:
            # Ordenar columnas: primero Código y Nombre, luego fechas ordenadas
            columnas_fecha = [col for col in self.df_asistencia.columns if col not in ['Codigo', 'Nombre']]
            columnas_fecha.sort()  # Ordenar fechas cronológicamente
            columnas_ordenadas = ['Codigo', 'Nombre'] + columnas_fecha
            
            self.df_asistencia = self.df_asistencia[columnas_ordenadas]
            
            # Guardar en Excel
            self.df_asistencia.to_excel(self.archivo_asistencia, index=False)
            
            # También guardar una copia en CSV para fácil visualización
            csv_path = self.archivo_asistencia.replace('.xlsx', '.csv')
            self.df_asistencia.to_csv(csv_path, index=False, encoding='utf-8-sig')
            
        except Exception as e:
            print(f"Error al guardar: {e}")
    
    def mostrar_resumen(self):
        """Muestra un resumen de la asistencia"""
        total_personas = len(self.df_asistencia)
        presentes_hoy = self.df_asistencia[self.fecha_asistencia].notna().sum()
        
        print("\n" + "="*50)
        print("RESUMEN DE ASISTENCIA")
        print("="*50)
        print(f"Fecha: {self.fecha_asistencia}")
        print(f"Total de personas registradas: {total_personas}")
        print(f"Personas presentes hoy: {presentes_hoy}")
        print(f"Personas ausentes: {total_personas - presentes_hoy}")
        
        if presentes_hoy > 0:
            print("\nPersonas presentes:")
            presentes = self.df_asistencia[self.df_asistencia[self.fecha_asistencia].notna()]
            for _, row in presentes.iterrows():
                print(f"  - {row['Nombre']} ({row['Codigo']}): {row[self.fecha_asistencia]}")
    
    def ejecutar_reconocimiento(self):
        """Ejecuta el reconocimiento facial en tiempo real"""
        if self.face_recognizer is None:
            print("No se puede ejecutar sin modelo entrenado.")
            return
        
        cap = cv2.VideoCapture(0)
        if not cap.isOpened():
            print("Error: No se pudo abrir la cámara.")
            return
        
        print("\nIniciando reconocimiento facial...")
        print("Presione 'ESC' para terminar")
        print("Presione 's' para ver resumen")
        print("Presione 'g' para guardar y generar reporte")
        
        tiempo_ultimo_reconocimiento = time.time()
        reconocimientos_por_minuto = {}
        
        while True:
            ret, frame = cap.read()
            if not ret:
                break
            
            # Espejar el frame para efecto espejo
            frame = cv2.flip(frame, 1)
            
            # Convertir a escala de grises
            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            auxFrame = gray.copy()
            
            # Detectar rostros
            faces = self.faceClassif.detectMultiScale(gray, 1.3, 5)
            
            for (x, y, w, h) in faces:
                rostro = auxFrame[y:y+h, x:x+w]
                rostro = cv2.resize(rostro, (150, 150), interpolation=cv2.INTER_CUBIC)
                
                # Predecir
                result = self.face_recognizer.predict(rostro)
                
                # Umbral para LBPH
                if result[1] < 70:  # Reconocido
                    label = result[0]
                    if label in self.label_mapping:
                        persona_info = self.label_mapping[label]
                        nombre = persona_info['nombre']
                        codigo = persona_info['carpeta'].split('_')[0]
                        
                        # Verificar si ya pasó suficiente tiempo desde el último reconocimiento
                        tiempo_actual = time.time()
                        if codigo not in reconocimientos_por_minuto or \
                           tiempo_actual - reconocimientos_por_minuto[codigo] > 2:  # 2 segundos mínimo
                            
                            reconocimientos_por_minuto[codigo] = tiempo_actual
                            
                            # Registrar asistencia
                            if self.registrar_asistencia(codigo, nombre):
                                print(f"✓ Asistencia registrada: {nombre} ({codigo})")
                            
                            # Dibujar cuadro verde
                            cv2.rectangle(frame, (x, y), (x+w, y+h), (0, 255, 0), 2)
                            cv2.putText(frame, nombre, (x, y-10), 
                                       cv2.FONT_HERSHEY_SIMPLEX, 0.9, (0, 255, 0), 2)
                            cv2.putText(frame, f'Conf: {result[1]:.1f}', (x, y+h+25), 
                                       cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 0), 1)
                        else:
                            # Ya reconocido recientemente
                            cv2.rectangle(frame, (x, y), (x+w, y+h), (0, 255, 255), 2)
                            cv2.putText(frame, f"{nombre} (Ya registrado)", (x, y-10), 
                                       cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 255), 2)
                    else:
                        # Reconocido pero no en el mapeo
                        cv2.rectangle(frame, (x, y), (x+w, y+h), (255, 255, 0), 2)
                        cv2.putText(frame, 'Desconocido', (x, y-10), 
                                   cv2.FONT_HERSHEY_SIMPLEX, 0.9, (255, 255, 0), 2)
                else:
                    # No reconocido
                    cv2.rectangle(frame, (x, y), (x+w, y+h), (0, 0, 255), 2)
                    cv2.putText(frame, 'Desconocido', (x, y-10), 
                               cv2.FONT_HERSHEY_SIMPLEX, 0.9, (0, 0, 255), 2)
            
            # Mostrar información en pantalla
            cv2.putText(frame, f"Fecha: {self.fecha_asistencia}", (10, 30), 
                       cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
            cv2.putText(frame, f"Presentes: {len(self.asistencia_registrada)}", (10, 60), 
                       cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
            cv2.putText(frame, "ESC: Salir  |  s: Resumen  |  g: Guardar", (10, 450), 
                       cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 1)
            
            cv2.imshow('Sistema de Asistencia - Reconocimiento Facial', frame)
            
            # Controles del teclado
            key = cv2.waitKey(1) & 0xFF
            if key == 27:  # ESC
                break
            elif key == ord('s'):
                self.mostrar_resumen()
            elif key == ord('g'):
                print("\nGuardando y generando reporte...")
                self.guardar_asistencia()
                print(f"Archivo guardado: {self.archivo_asistencia}")
        
        cap.release()
        cv2.destroyAllWindows()
        
        # Mostrar resumen final
        self.mostrar_resumen()
        print(f"\nArchivo de asistencia guardado: {self.archivo_asistencia}")
        print("También se generó una versión en CSV para fácil apertura.")
    
    def ejecutar(self):
        """Método principal para ejecutar el sistema"""
        # Solicitar fecha
        self.solicitar_fecha()
        
        # Inicializar registro
        self.inicializar_registro_asistencia()
        
        # Ejecutar reconocimiento
        self.ejecutar_reconocimiento()

if __name__ == "__main__":
    sistema = SistemaAsistencia()
    sistema.ejecutar()