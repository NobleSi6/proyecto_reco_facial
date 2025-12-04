from flask import Flask, request, jsonify
from flask_cors import CORS
import os
import time
import cv2

app = Flask(__name__)
CORS(app)

# Carpetas
UPLOAD_FOLDER = 'uploads/'
OUTPUT_FOLDER = 'Datos/'
ALLOWED_EXTENSIONS = {'jpg', 'jpeg', 'png'}

app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

# Detección de rostro y guardado
def process_face_image(image_path, person_name):
    faceClassif = cv2.CascadeClassifier(
        cv2.data.haarcascades + 'haarcascade_frontalface_default.xml'
    )

    image = cv2.imread(image_path)
    if image is None:
        print("⚠ Error al cargar imagen:", image_path)
        return None

    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    faces = faceClassif.detectMultiScale(gray, 1.3, 5)

    if len(faces) == 0:
        print("⚠ No se detectó rostro.")
        return None

    # Crear carpeta de la persona
    personPath = os.path.join(OUTPUT_FOLDER, person_name)
    os.makedirs(personPath, exist_ok=True)

    processed_paths = []

    for (x, y, w, h) in faces:
        face = image[y:y+h, x:x+w]
        face = cv2.resize(face, (150, 150))

        filename = f"{int(time.time()*1000)}.png"
        filepath = os.path.join(personPath, filename)

        cv2.imwrite(filepath, face)
        processed_paths.append(filepath)

        print("✔ Rostro guardado en:", filepath)

    return processed_paths

# -------------------------
#   ENDPOINT PRINCIPAL
# -------------------------
@app.route('/registrar_foto', methods=['POST'])
def registrar_foto():

    nombre = request.form.get('nombre')
    if not nombre:
        return jsonify({"error": "Nombre no proporcionado"}), 400

    if 'imagen' not in request.files:
        return jsonify({"error": "No se recibió ninguna imagen"}), 400

    imagen = request.files['imagen']

    if not allowed_file(imagen.filename):
        return jsonify({"error": "Formato no permitido"}), 400

    # Guardar foto temporalmente
    filename = f"{int(time.time()*1000)}_{imagen.filename}"
    filepath = os.path.join(UPLOAD_FOLDER, filename)
    imagen.save(filepath)

    print("📸 Imagen recibida:", filepath)

    # Procesar rostro
    processed = process_face_image(filepath, nombre)

    if not processed:
        return jsonify({"error": "No se detectó rostro"}), 400

    return jsonify({
        "message": "Rostro procesado correctamente",
        "saved_files": processed
    }), 200
# -------------------------
#   ENDPOINT Para reconocer rostro
# -------------------------

@app.route('/reconocer_rostro', methods=['POST'])
def reconocer_rostro():
    
    if 'imagen' not in request.files:
        return jsonify({"error": "No se recibió ninguna imagen"}), 400

    imagen = request.files['imagen']

    if not allowed_file(imagen.filename):
        return jsonify({"error": "Formato no permitido"}), 400

    # Guardar foto temporalmente
    filename = f"temp_{int(time.time()*1000)}_{imagen.filename}"
    filepath = os.path.join(UPLOAD_FOLDER, filename)
    imagen.save(filepath)

    print("📸 Imagen recibida para reconocimiento:", filepath)

    try:
        # Cargar el modelo LBPH
        face_recognizer = cv2.face.LBPHFaceRecognizer_create()
        face_recognizer.read('modeloLBPHFace.xml')
        
        # Cargar clasificador
        faceClassif = cv2.CascadeClassifier(
            cv2.data.haarcascades + 'haarcascade_frontalface_default.xml'
        )
        
        # Leer imagen
        frame = cv2.imread(filepath)
        if frame is None:
            return jsonify({"error": "No se pudo leer la imagen"}), 400
        
        # Procesar
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        faces = faceClassif.detectMultiScale(gray, 1.3, 5)
        
        if len(faces) == 0:
            return jsonify({"error": "No se detectó rostro"}), 200
        
        # Obtener carpetas de personas
        dataPath = 'Datos'
        imagePaths = os.listdir(dataPath)
        
        for (x, y, w, h) in faces:
            rostro = gray[y:y+h, x:x+w]
            rostro = cv2.resize(rostro, (150, 150), interpolation=cv2.INTER_CUBIC)
            
            result = face_recognizer.predict(rostro)
            label, confidence = result
            
            print(f"🔍 Resultado: label={label}, confidence={confidence}")
            
            if confidence < 70:
                nombre = imagePaths[label]
                return jsonify({
                    "nombre": nombre,
                    "confidence": float(confidence)
                }), 200
            else:
                return jsonify({"nombre": "Desconocido"}), 200
        
        return jsonify({"error": "No se pudo procesar el rostro"}), 400
        
    except Exception as e:
        print(f"❌ Error en reconocimiento: {str(e)}")
        return jsonify({"error": f"Error en el reconocimiento: {str(e)}"}), 500
    finally:
        # Limpiar archivo temporal
        if os.path.exists(filepath):
            os.remove(filepath)

# -------------------------
#    INICIAR SERVIDOR
# -------------------------
if __name__ == '__main__':
    os.makedirs(UPLOAD_FOLDER, exist_ok=True)
    os.makedirs(OUTPUT_FOLDER, exist_ok=True)

    app.run(debug=True, host='0.0.0.0', port=8000)
