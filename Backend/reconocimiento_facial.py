import cv2
import os

# Ruta donde está la carpeta Datos
dataPath = 'C:/Users/elias/OneDrive/Desktop/proyecto_reco_facial-main/proyecto_reco_facial-main/Datos'
imagePaths = os.listdir(dataPath)

# Cargar reconocedor LBPH
face_recognizer = cv2.face.LBPHFaceRecognizer_create()
face_recognizer.read('modeloLBPHFace.xml')

# Cargar clasificador Haar Cascade
faceClassif = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')


def reconocer_rostro():
    """
    Captura un solo cuadro de la cámara,
    detecta un rostro y devuelve el nombre reconocido.
    """

    cap = cv2.VideoCapture(0)

    if not cap.isOpened():
        return "Error: No se pudo acceder a la cámara"

    ret, frame = cap.read()
    cap.release()

    if not ret:
        return "Error al capturar imagen"

    # Procesar imagen
    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    faces = faceClassif.detectMultiScale(gray, 1.3, 5)

    # Si no encuentra rostros:
    if len(faces) == 0:
        return "No se detectó rostro"

    for (x, y, w, h) in faces:
        rostro = gray[y:y+h, x:x+w]
        rostro = cv2.resize(rostro, (150,150), interpolation=cv2.INTER_CUBIC)

        result = face_recognizer.predict(rostro)
        label, confidence = result

        # LBPH threshold recomendado: 70
        if confidence < 70:
            return imagePaths[label]
        else:
            return "Desconocido"

    return "No se pudo procesar el rostro"
