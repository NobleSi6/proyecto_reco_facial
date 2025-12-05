from flask import Flask, request, jsonify
from flask_cors import CORS
import os
import time
import cv2
import subprocess
from reconocimiento_facial import reconocer_desde_imagen

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
    with open(archivo_asistencia, "a") as f:
        f.write(f"Asistencia: {time.ctime()}\n")

    print(f"✔ Asistencia guardada para {nombre}")


# ===============================
#  FUNCION DE RECONOCIMIENTO SEGURA
# ===============================
def reconocer_desde_imagen_segura(image_path):
    """
    Envuelve a reconocer_desde_imagen para manejar IndexError
    y prevenir que el servidor rompa.
    """
    try:
        result = reconocer_desde_imagen(image_path)
        nombre = result.get("nombre", "Desconocido")
        confidence = result.get("confidence", 100)
        labels_disponibles = result.get("labels_disponibles", [])

        if "label" in result:
            label = result["label"]
            if 0 <= label < len(labels_disponibles):
                nombre = labels_disponibles[label] if confidence < 70 else "Desconocido"
            else:
                nombre = "Desconocido"

        result["nombre"] = nombre
        return result

    except IndexError:
        return {"nombre": "Desconocido", "confidence": 100}
    except Exception as e:
        return {"nombre": "Desconocido", "error": str(e), "confidence": 100}


# ===============================
#  ENDPOINTS
# ===============================

@app.route('/personas', methods=['GET'])
def listar_personas():
    try:
        personas = [
            nombre for nombre in os.listdir(OUTPUT_FOLDER)
            if os.path.isdir(os.path.join(OUTPUT_FOLDER, nombre))
        ] if os.path.exists(OUTPUT_FOLDER) else []

        return jsonify({"personas": personas}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route('/registrar_foto', methods=['POST'])
def registrar_foto():
    # 🔥 LIMPIAR ESPACIOS EN BLANCO DEL NOMBRE
    nombre = request.form.get('nombre', '').strip()
    imagen = request.files.get('imagen')

    if not nombre:
        return jsonify({"error": "Nombre requerido"}), 400
    if not imagen:
        return jsonify({"error": "No se envió imagen"}), 400
    if not allowed_file(imagen.filename):
        return jsonify({"error": "Formato no permitido"}), 400

    filename = f"{int(time.time() * 1000)}_{imagen.filename}"
    filepath = os.path.join(UPLOAD_FOLDER, filename)
    imagen.save(filepath)

    saved = process_face_image(filepath, nombre)
    if not saved:
        return jsonify({"error": "No se detectó rostro"}), 400

    person_folder = os.path.join(OUTPUT_FOLDER, nombre)
    
    # 🔥 VERIFICAR QUE LA CARPETA EXISTE ANTES DE CONTAR
    if not os.path.exists(person_folder):
        os.makedirs(person_folder, exist_ok=True)
    
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
    temp_path = os.path.join(BASE_DIR, f"temp_{int(time.time() * 1000)}.jpg")
    imagen.save(temp_path)

    result = reconocer_desde_imagen_segura(temp_path)
    
    # Limpiar archivo temporal
    try:
        os.remove(temp_path)
    except:
        pass

    nombre = result.get("nombre")
    if nombre and nombre not in ["Desconocido", "No se detectó rostro"]:
        guardar_asistencia(nombre)

    return jsonify(result), 200


@app.route('/asistencias', methods=['GET'])
def asistencias():
    lista = []
    if not os.path.exists(OUTPUT_FOLDER):
        return jsonify({"asistencias": lista})
        
    for persona in os.listdir(OUTPUT_FOLDER):
        persona_path = os.path.join(OUTPUT_FOLDER, persona)
        if os.path.isdir(persona_path):
            fecha_creacion = time.ctime(os.path.getctime(persona_path))
            archivo_asistencia = os.path.join(persona_path, "asistencia.txt")
            conteo = 0
            if os.path.exists(archivo_asistencia):
                try:
                    with open(archivo_asistencia, 'r') as f:
                        conteo = len(f.readlines())
                except:
                    conteo = 0
            lista.append({
                "persona": persona,
                "fecha_creacion": fecha_creacion,
                "asistencias": conteo
            })
    return jsonify({"asistencias": lista})


# ===============================
#  EJECUCIÓN
# ===============================
if __name__ == '__main__':
    print("🚀 Servidor en ejecución: http://localhost:8000")
    app.run(debug=True, host='0.0.0.0', port=8000)