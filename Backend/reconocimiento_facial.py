#reconocimiento_facial.py
import cv2
import os

# 🔥 USAR RUTAS RELATIVAS EN LUGAR DE HARDCODEADAS
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_PATH = os.path.join(BASE_DIR, 'Datos')
MODEL_PATH = os.path.join(BASE_DIR, 'modeloLBPHFace.xml')

# Verificar que exista el modelo
if not os.path.exists(MODEL_PATH):
    raise FileNotFoundError(f"❌ No se encontró el modelo entrenado en: {MODEL_PATH}")

# Obtener lista de personas (carpetas en Datos)
image_paths = []
if os.path.exists(DATA_PATH):
    image_paths = [
        name for name in os.listdir(DATA_PATH)
        if os.path.isdir(os.path.join(DATA_PATH, name))
    ]

# Cargar reconocedor LBPH entrenado
face_recognizer = cv2.face.LBPHFaceRecognizer_create()
face_recognizer.read(MODEL_PATH)

# Cargar Haar Cascade para detección
face_detector = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')


def reconocer_desde_imagen(image_path: str):
    """
    Recibe la ruta de una imagen y devuelve:
    - nombre reconocido
    - nivel de confianza
    - label (índice de la persona)
    - labels_disponibles (lista de nombres)
    """

    if not os.path.exists(image_path):
        return {
            "error": "La imagen no existe",
            "nombre": "Desconocido",
            "confidence": 100
        }

    # Leer imagen
    image = cv2.imread(image_path)
    
    if image is None:
        return {
            "error": "No se pudo leer la imagen",
            "nombre": "Desconocido",
            "confidence": 100
        }

    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)

    faces = face_detector.detectMultiScale(gray, scaleFactor=1.3, minNeighbors=5)

    if len(faces) == 0:
        return {
            "nombre": "No se detectó rostro",
            "confidence": None,
            "labels_disponibles": image_paths
        }

    mejor_nombre = "Desconocido"
    mejor_confianza = 100
    mejor_label = -1

    for (x, y, w, h) in faces:
        rostro = gray[y:y+h, x:x+w]
        rostro = cv2.resize(rostro, (250, 250), interpolation=cv2.INTER_CUBIC)

        try:
            label, confidence = face_recognizer.predict(rostro)

            # Si tiene buena coincidencia (<70)
            if confidence < mejor_confianza:
                mejor_confianza = confidence
                mejor_label = label
                
                # Verificar que el label esté en rango
                if 0 <= label < len(image_paths):
                    mejor_nombre = image_paths[label] if confidence < 70 else "Desconocido"
                else:
                    mejor_nombre = "Desconocido"
        except Exception as e:
            print(f"❌ Error al predecir: {e}")
            continue

    return {
        "nombre": mejor_nombre,
        "confidence": round(mejor_confianza, 2),
        "label": mejor_label,
        "labels_disponibles": image_paths
    }