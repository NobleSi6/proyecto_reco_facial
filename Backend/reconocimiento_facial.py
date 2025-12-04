import cv2
import os

# Ruta donde se guardan las carpetas con nombres
DATA_PATH = 'C:/Users/elias/OneDrive/Desktop/proyecto_reco_facial-main/proyecto_reco_facial-main/Backend/Datos'
image_paths = os.listdir(DATA_PATH)

# Cargar reconocedor LBPH entrenado
face_recognizer = cv2.face.LBPHFaceRecognizer_create()
face_recognizer.read('modeloLBPHFace.xml')

# Cargar Haar Cascade para detección
face_detector = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')


def reconocer_desde_imagen(image_path: str):
    """
    Recibe la ruta de una imagen y devuelve:
    - nombre reconocido
    - nivel de confianza
    """

    if not os.path.exists(image_path):
        return {"error": "La imagen no existe"}

    # Leer imagen
    image = cv2.imread(image_path)
    
    if image is None:
        return {"error": "No se pudo leer la imagen"}

    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)

    faces = face_detector.detectMultiScale(gray, scaleFactor=1.3, minNeighbors=5)

    if len(faces) == 0:
        return {"nombre": "No se detectó rostro", "confidence": None}

    mejor_nombre = "Desconocido"
    mejor_confianza = 998

    for (x, y, w, h) in faces:
        rostro = gray[y:y+h, x:x+w]
        rostro = cv2.resize(rostro, (150,150), interpolation=cv2.INTER_CUBIC)

        label, confidence = face_recognizer.predict(rostro)

        # Si tiene buena coincidencia (<70)
        if confidence < mejor_confianza:
            mejor_confianza = confidence
            mejor_nombre = image_paths[label] if confidence < 70 else "Desconocido"

    return {
        "nombre": mejor_nombre,
        "confidence": round(mejor_confianza, 2)
    }
