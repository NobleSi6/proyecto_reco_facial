from flask import Flask, request, jsonify
from flask_cors import CORS
import os
import time
import cv2
import subprocess
from reconocimiento_facial import reconocer_desde_imagen  # ⬅ usamos tu módulo nuevo

app = Flask(__name__)
CORS(app)

# ===============================
#  CONFIGURACIONES
# ===============================
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
UPLOAD_FOLDER = os.path.join(BASE_DIR, "uploads")
OUTPUT_FOLDER = os.path.join(BASE_DIR, "Datos")
MODEL_PATH = os.path.join(BASE_DIR, "modeloLBPHFace.xml")
CASCADE_PATH = cv2.data.haarcascades + "haarcascade_frontalface_default.xml"

os.makedirs(UPLOAD_FOLDER, exist_ok=True)
os.makedirs(OUTPUT_FOLDER, exist_ok=True)

ALLOWED_EXTENSIONS = {'jpg', 'jpeg', 'png'}
MIN_IMAGES_PER_PERSON = 200


def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS


# ===============================
#  PROCESAR Y GUARDAR ROSTROS
# ===============================
def process_face_image(image_path, person_name):
    face_detector = cv2.CascadeClassifier(CASCADE_PATH)

    img = cv2.imread(image_path)
    if img is None:
        return None

    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    faces = face_detector.detectMultiScale(gray, 1.2, 5, minSize=(80, 80))

    if len(faces) == 0:
        return None

    person_folder = os.path.join(OUTPUT_FOLDER, person_name)
    os.makedirs(person_folder, exist_ok=True)

    saved_files = []

    for (x, y, w, h) in faces:
        face = gray[y:y+h, x:x+w]
        face = cv2.resize(face, (150, 150))

        file_name = f"{int(time.time()*1000)}.png"
        save_path = os.path.join(person_folder, file_name)

        cv2.imwrite(save_path, face)
        saved_files.append(save_path)

    return saved_files


# ===============================
#  ENTRENAMIENTO AUTOMÁTICO
# ===============================
def ejecutar_entrenamiento():
    try:
        print("\n🔵 Entrenando modelo...")
        subprocess.Popen(["python", os.path.join(BASE_DIR, "entrenamiento.py")])
        return True
    except Exception as e:
        print("❌ Error en entrenamiento:", e)
        return False


# ===============================
#  ENDPOINTS
# ===============================

@app.route('/registrar_foto', methods=['POST'])
def registrar_foto():

    nombre = request.form.get('nombre')
    imagen = request.files.get('imagen')

    if not nombre:
        return jsonify({"error": "Nombre requerido"}), 400

    if not imagen:
        return jsonify({"error": "No se envió imagen"}), 400

    if not allowed_file(imagen.filename):
        return jsonify({"error": "Formato no permitido"}), 400

    filename = f"{int(time.time()*1000)}_{imagen.filename}"
    filepath = os.path.join(UPLOAD_FOLDER, filename)
    imagen.save(filepath)

    saved = process_face_image(filepath, nombre)

    if not saved:
        return jsonify({"error": "No se detectó rostro"}), 400

    person_folder = os.path.join(OUTPUT_FOLDER, nombre)
    count = len(os.listdir(person_folder))

    estado = "waiting"
    if count >= MIN_IMAGES_PER_PERSON:
        ejecutar_entrenamiento()
        estado = "training"

    return jsonify({
        "message": "Imagen guardada",
        "total_imagenes": count,
        "estado": estado
    }), 200


@app.route('/reconocer', methods=['POST'])
def reconocer():

    if "imagen" not in request.files:
        return jsonify({"error": "No hay imagen"}), 400

    imagen = request.files["imagen"]
    temp_path = os.path.join(BASE_DIR, f"temp_{int(time.time()*1000)}.jpg")
    imagen.save(temp_path)

    result = reconocer_desde_imagen(temp_path)

    os.remove(temp_path)

    return jsonify(result), 200


# ===============================
#  EJECUCIÓN
# ===============================
if __name__ == '__main__':
    print("🚀 Servidor en ejecución: http://localhost:8000")
    app.run(debug=True, host='0.0.0.0', port=8000)
