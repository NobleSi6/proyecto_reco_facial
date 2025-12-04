from flask import Flask, request, jsonify
from flask_cors import CORS
import os
import time
import cv2
import numpy as np

app = Flask(__name__)
CORS(app)

# Carpetas
UPLOAD_FOLDER = 'uploads/'
OUTPUT_FOLDER = 'Datos/'
ALLOWED_EXTENSIONS = {'jpg', 'jpeg', 'png'}

app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

# Contador de fotos para reentrenar automáticamente
foto_counter = {}

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


def entrenar_modelo_automatico():
    """
    Entrena el modelo LBPH automáticamente después de registrar fotos
    """
    try:
        data_path = OUTPUT_FOLDER
        people_list = [d for d in os.listdir(data_path) if os.path.isdir(os.path.join(data_path, d))]
        
        if len(people_list) == 0:
            print("⚠ No hay personas registradas para entrenar")
            return False
        
        print(f"\n🔄 Entrenando modelo con {len(people_list)} personas...")

        labels = []
        faces_data = []
        label = 0

        for person in people_list:
            person_path = os.path.join(data_path, person)
            
            for file_name in os.listdir(person_path):
                file_path = os.path.join(person_path, file_name)
                
                image = cv2.imread(file_path, cv2.IMREAD_GRAYSCALE)
                
                if image is None:
                    continue
                
                faces_data.append(image)
                labels.append(label)
            
            label += 1

        if len(faces_data) == 0:
            print("⚠ No se encontraron imágenes para entrenar")
            return False

        labels = np.array(labels)
        
        face_recognizer = cv2.face.LBPHFaceRecognizer_create()
        face_recognizer.train(faces_data, labels)
        face_recognizer.write('modeloLBPHFace.xml')
        
        print(f"✅ Modelo entrenado exitosamente con {len(faces_data)} imágenes")
        return True
        
    except Exception as e:
        print(f"❌ Error entrenando modelo: {str(e)}")
        return False


# -------------------------
#   ENDPOINT REGISTRO
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

    # Contador de fotos por persona
    if nombre not in foto_counter:
        foto_counter[nombre] = 0
    
    foto_counter[nombre] += 1
    
    # Entrenar automáticamente cada 50 fotos o cuando llegue a 300
    if foto_counter[nombre] % 50 == 0 or foto_counter[nombre] >= 300:
        print(f"\n🎯 {nombre} tiene {foto_counter[nombre]} fotos. Reentrenando modelo...")
        entrenar_modelo_automatico()

    return jsonify({
        "message": "Rostro procesado correctamente",
        "saved_files": processed,
        "total_fotos": foto_counter[nombre]
    }), 200


# -------------------------
#   ENDPOINT RECONOCIMIENTO
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
        # Verificar que existe el modelo
        if not os.path.exists('modeloLBPHFace.xml'):
            return jsonify({"error": "Modelo no entrenado. Registra personas primero."}), 400
        
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
        dataPath = OUTPUT_FOLDER
        imagePaths = [d for d in os.listdir(dataPath) if os.path.isdir(os.path.join(dataPath, d))]
        
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
#   ENDPOINT ENTRENAR MANUAL
# -------------------------
@app.route('/entrenar_modelo', methods=['POST'])
def entrenar_modelo_endpoint():
    """
    Endpoint para entrenar el modelo manualmente si es necesario
    """
    success = entrenar_modelo_automatico()
    
    if success:
        return jsonify({"message": "Modelo entrenado exitosamente"}), 200
    else:
        return jsonify({"error": "Error al entrenar el modelo"}), 500


# -------------------------
#    INICIAR SERVIDOR
# -------------------------
if __name__ == '__main__':
    os.makedirs(UPLOAD_FOLDER, exist_ok=True)
    os.makedirs(OUTPUT_FOLDER, exist_ok=True)

    app.run(debug=True, host='0.0.0.0', port=8000)