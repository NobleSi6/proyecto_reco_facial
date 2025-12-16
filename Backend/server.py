from flask import Flask, request, jsonify
from flask_cors import CORS
import os
import time
import cv2
import subprocess
from reconocimiento_facial import reconocer_desde_imagen
from datetime import datetime

# ===============================
#  APP + CORS (FIX FLUTTER WEB)
# ===============================
app = Flask(__name__)

CORS(
    app,
    resources={r"/*": {"origins": "*"}},
    supports_credentials=True,
    methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["Content-Type", "Authorization"]
)

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
        face = gray[y:y + h, x:x + w]
        face = cv2.resize(face, (150, 150))

        file_name = f"{int(time.time() * 1000)}.png"
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
#  GUARDAR ASISTENCIA
# ===============================
def guardar_asistencia(nombre):
    carpeta = os.path.join(OUTPUT_FOLDER, nombre)
    os.makedirs(carpeta, exist_ok=True)

    archivo_asistencia = os.path.join(carpeta, "asistencia.txt")
    hoy = datetime.now().strftime("%Y-%m-%d")

    if os.path.exists(archivo_asistencia):
        with open(archivo_asistencia, "r") as f:
            if hoy in f.read():
                return

    with open(archivo_asistencia, "a") as f:
        f.write(hoy + "\n")


# ===============================
#  RECONOCIMIENTO SEGURO
# ===============================
def reconocer_desde_imagen_segura(image_path):
    try:
        result = reconocer_desde_imagen(image_path)
        nombre = result.get("nombre", "Desconocido")
        confidence = result.get("confidence", 100)
        labels = result.get("labels_disponibles", [])

        if "label" in result:
            label = result["label"]
            if 0 <= label < len(labels):
                nombre = labels[label] if confidence < 70 else "Desconocido"
            else:
                nombre = "Desconocido"

        result["nombre"] = nombre
        return result

    except Exception as e:
        return {"nombre": "Desconocido", "confidence": 100, "error": str(e)}


# ===============================
#  ENDPOINTS
# ===============================

@app.route('/personas', methods=['GET'])
def listar_personas():
    personas = [
        nombre for nombre in os.listdir(OUTPUT_FOLDER)
        if os.path.isdir(os.path.join(OUTPUT_FOLDER, nombre))
    ]
    return jsonify({"personas": personas}), 200


@app.route('/registrar_foto', methods=['POST'])
def registrar_foto():
    nombre = request.form.get('nombre')
    imagen = request.files.get('imagen')

    if not nombre or not imagen:
        return jsonify({"error": "Datos incompletos"}), 400

    if not allowed_file(imagen.filename):
        return jsonify({"error": "Formato no permitido"}), 400

    filepath = os.path.join(
        UPLOAD_FOLDER, f"{int(time.time() * 1000)}_{imagen.filename}"
    )
    imagen.save(filepath)

    saved = process_face_image(filepath, nombre)
    if not saved:
        return jsonify({"error": "No se detectó rostro"}), 400

    person_folder = os.path.join(OUTPUT_FOLDER, nombre)
    count = len(os.listdir(person_folder))

    if count >= MIN_IMAGES_PER_PERSON:
        ejecutar_entrenamiento()

    return jsonify({"total_imagenes": count}), 200


@app.route('/reconocer', methods=['POST'])
def reconocer():
    if "imagen" not in request.files:
        return jsonify({"error": "No hay imagen"}), 400

    imagen = request.files["imagen"]
    temp_path = os.path.join(BASE_DIR, f"temp_{int(time.time() * 1000)}.jpg")
    imagen.save(temp_path)

    result = reconocer_desde_imagen_segura(temp_path)
    os.remove(temp_path)

    if result.get("nombre") not in ["Desconocido", None]:
        guardar_asistencia(result["nombre"])

    return jsonify(result), 200


@app.route('/asistencias', methods=['GET'])
def asistencias():
    lista = []

    for persona in os.listdir(OUTPUT_FOLDER):
        archivo = os.path.join(OUTPUT_FOLDER, persona, "asistencia.txt")
        fechas = []

        if os.path.exists(archivo):
            with open(archivo) as f:
                fechas = [line.strip() for line in f.readlines()]

        lista.append({
            "persona": persona,
            "asistencias": len(fechas),
            "fechas": fechas
        })

    return jsonify({"asistencias": lista}), 200


@app.route('/personas/<nombre>', methods=['PUT'])
def editar_persona(nombre):
    data = request.get_json() or {}
    nuevo = data.get("nuevo_nombre")

    origen = os.path.join(OUTPUT_FOLDER, nombre)
    destino = os.path.join(OUTPUT_FOLDER, nuevo)

    if not nuevo or not os.path.exists(origen):
        return jsonify({"error": "Datos inválidos"}), 400

    os.rename(origen, destino)
    return jsonify({"message": "Persona actualizada"}), 200


@app.route('/personas/<nombre>', methods=['DELETE'])
def eliminar_persona(nombre):
    path = os.path.join(OUTPUT_FOLDER, nombre)

    if not os.path.exists(path):
        return jsonify({"error": "No existe"}), 404

    for root, dirs, files in os.walk(path, topdown=False):
        for f in files:
            os.remove(os.path.join(root, f))
        for d in dirs:
            os.rmdir(os.path.join(root, d))
    os.rmdir(path)

    return jsonify({"message": "Eliminado"}), 200


@app.route('/asistencias/<nombre>', methods=['PUT'])
def actualizar_asistencias(nombre):
    data = request.get_json() or {}
    fechas = data.get("fechas")

    path = os.path.join(OUTPUT_FOLDER, nombre)
    if not isinstance(fechas, list) or not os.path.exists(path):
        return jsonify({"error": "Datos inválidos"}), 400

    archivo = os.path.join(path, "asistencia.txt")
    with open(archivo, "w") as f:
        for fecha in fechas:
            f.write(fecha + "\n")

    return jsonify({"total": len(fechas)}), 200


# ===============================
#  OPTIONS (CORS PREFLIGHT FIX)
# ===============================
@app.route('/asistencias/<nombre>', methods=['OPTIONS'])
@app.route('/personas/<nombre>', methods=['OPTIONS'])
def options_handler(nombre):
    return '', 200


# ===============================
#  EJECUCIÓN
# ===============================
if __name__ == '__main__':
    print("🚀 Servidor en ejecución: http://localhost:8000")
    app.run(debug=True, host='0.0.0.0', port=8000)
