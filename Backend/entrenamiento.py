import cv2
import os
import numpy as np
import requests
import sys

# -----------------------------
# Rutas y preparación de datos
# -----------------------------
BASE_DIR = os.path.dirname(os.path.abspath(__file__))  # FIX
dataPath = os.path.join(BASE_DIR, 'Datos')
os.makedirs(dataPath, exist_ok=True)

# -----------------------------
# Manejo de argumento opcional
# -----------------------------
personName = sys.argv[1] if len(sys.argv) > 1 else None

# -----------------------------
# Listar carpetas con imágenes
# -----------------------------
if personName:
    personPath = os.path.join(dataPath, personName)
    if not os.path.exists(personPath) or not os.listdir(personPath):
        print(f"⚠ No hay imágenes en la carpeta de {personName}. Finalizando entrenamiento.")
        exit(0)
    peopleList = [personName]
else:
    peopleList = [
        name for name in os.listdir(dataPath)
        if os.path.isdir(os.path.join(dataPath, name)) and os.listdir(os.path.join(dataPath, name))
    ]

if not peopleList:
    print("⚠ No se encontraron carpetas de personas con imágenes. Finalizando entrenamiento.")
    exit(0)

print('📌 Personas a entrenar:', peopleList)

labels = []
facesData = []
label = 0

# -----------------------------
# Leer imágenes
# -----------------------------
for nameDir in peopleList:
    personPath = os.path.join(dataPath, nameDir)
    print('📸 Leyendo imágenes de:', nameDir)

    for fileName in os.listdir(personPath):
        filePath = os.path.join(personPath, fileName)

        img = cv2.imread(filePath, 0)
        if img is None:
            print(f"⚠ No se pudo leer la imagen: {filePath}")
            continue

        facesData.append(img)
        labels.append(label)
        print('✔ Rostro leído:', fileName)

    label += 1

if not facesData:
    print("⚠ No se encontraron rostros válidos para entrenar. Finalizando entrenamiento.")
    exit(0)

# -----------------------------
# Entrenar modelo LBPH
# -----------------------------
print("🧠 Entrenando modelo LBPH...")
face_recognizer = cv2.face.LBPHFaceRecognizer_create()
face_recognizer.train(facesData, np.array(labels))

# Guardar modelo
modelo_path = os.path.join(BASE_DIR, 'modeloLBPHFace.xml')
face_recognizer.write(modelo_path)
print("✅ Modelo almacenado en:", modelo_path)

# -----------------------------
# Avisar al servidor
# -----------------------------
try:
    url = "http://127.0.0.1:8000/modelo_entrenado"
    response = requests.post(url, json={"mensaje": "modelo_generado", "ruta": modelo_path})
    print("📩 Servidor respondió:", response.text)
except Exception as e:
    print("⚠ No se pudo conectar al servidor:", e)
