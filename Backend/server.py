from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
import os
import time
import cv2
import subprocess
from datetime import datetime, timedelta
from reconocimiento_facial import reconocer_desde_imagen

# Importar funciones de base de datos
from database import (
    registrar_asistencia,
    obtener_asistencias_por_fecha,
    obtener_asistencias_rango,
    obtener_historial_estudiante,
    obtener_todos_estudiantes,
    insertar_estudiante
)

# Importar generador de Excel
from excel_exporter import generar_excel_asistencias, generar_excel_por_estudiante

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
REPORTS_FOLDER = os.path.join(BASE_DIR, "reportes")

os.makedirs(UPLOAD_FOLDER, exist_ok=True)
os.makedirs(OUTPUT_FOLDER, exist_ok=True)
os.makedirs(REPORTS_FOLDER, exist_ok=True)

ALLOWED_EXTENSIONS = {'jpg', 'jpeg', 'png'}
MIN_IMAGES_PER_PERSON = 200


def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS


# ===============================
#  FUNCIONES AUXILIARES
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


def ejecutar_entrenamiento():
    try:
        print("\n🔵 Iniciando entrenamiento del modelo...")
        entrenamiento_path = os.path.join(BASE_DIR, "entrenamiento.py")
        subprocess.Popen(["python", entrenamiento_path])
        return True
    except Exception as e:
        print("❌ Error en entrenamiento:", e)
        return False


def reconocer_desde_imagen_segura(image_path):
    try:
        result = reconocer_desde_imagen(image_path)
        nombre = result.get("nombre", "Desconocido")
        confidence = result.get("confidence", 100)
        print(f"🔍 Reconocimiento: {nombre} (confianza: {confidence})")
        return result
    except Exception as e:
        print(f"❌ Error en reconocimiento: {e}")
        return {"nombre": "Desconocido", "confidence": 100, "error": str(e)}


# ===============================
#  ENDPOINTS ORIGINALES
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

    # Registrar estudiante en BD
    insertar_estudiante(nombre)

    person_folder = os.path.join(OUTPUT_FOLDER, nombre)
    if not os.path.exists(person_folder):
        os.makedirs(person_folder, exist_ok=True)
    
    count = len([f for f in os.listdir(person_folder) 
                 if f.lower().endswith(('.png', '.jpg', '.jpeg'))])

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
    temp_path = os.path.join(UPLOAD_FOLDER, f"temp_{int(time.time() * 1000)}.jpg")
    imagen.save(temp_path)

    result = reconocer_desde_imagen_segura(temp_path)
    
    try:
        os.remove(temp_path)
    except:
        pass

    nombre = result.get("nombre")
    
    # Registrar asistencia en BD si es reconocido
    if nombre and nombre not in ["Desconocido", "No se detectó rostro"]:
        asistencia_result = registrar_asistencia(nombre)
        result["asistencia"] = asistencia_result

    return jsonify(result), 200


# ===============================
#  NUEVOS ENDPOINTS DE ASISTENCIA
# ===============================

@app.route('/api/asistencia/hoy', methods=['GET'])
def asistencias_hoy():
    """Obtener asistencias del día actual"""
    try:
        fecha_hoy = datetime.now().strftime('%Y-%m-%d')
        asistencias = obtener_asistencias_por_fecha(fecha_hoy)
        
        return jsonify({
            "fecha": fecha_hoy,
            "total": len(asistencias),
            "asistencias": asistencias
        }), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route('/api/asistencia/fecha/<fecha>', methods=['GET'])
def asistencias_por_fecha(fecha):
    """Obtener asistencias de una fecha específica (formato: YYYY-MM-DD)"""
    try:
        asistencias = obtener_asistencias_por_fecha(fecha)
        
        return jsonify({
            "fecha": fecha,
            "total": len(asistencias),
            "asistencias": asistencias
        }), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route('/api/asistencia/rango', methods=['GET'])
def asistencias_por_rango():
    """
    Obtener asistencias en un rango de fechas
    Query params: fecha_inicio, fecha_fin (formato: YYYY-MM-DD)
    """
    try:
        fecha_inicio = request.args.get('fecha_inicio')
        fecha_fin = request.args.get('fecha_fin')
        
        if not fecha_inicio or not fecha_fin:
            return jsonify({"error": "Se requieren fecha_inicio y fecha_fin"}), 400
        
        asistencias = obtener_asistencias_rango(fecha_inicio, fecha_fin)
        
        return jsonify({
            "fecha_inicio": fecha_inicio,
            "fecha_fin": fecha_fin,
            "total": len(asistencias),
            "asistencias": asistencias
        }), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route('/api/asistencia/estudiante/<nombre>', methods=['GET'])
def historial_estudiante(nombre):
    """Obtener historial completo de un estudiante"""
    try:
        historial = obtener_historial_estudiante(nombre)
        
        return jsonify({
            "estudiante": nombre,
            "total_asistencias": len(historial),
            "historial": historial
        }), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route('/api/estudiantes', methods=['GET'])
def listar_estudiantes():
    """Obtener lista completa de estudiantes con estadísticas"""
    try:
        estudiantes = obtener_todos_estudiantes()
        return jsonify({
            "total": len(estudiantes),
            "estudiantes": estudiantes
        }), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route('/api/asistencia/exportar/excel', methods=['GET'])
def exportar_excel():
    """
    Exportar asistencias a Excel
    Query params: fecha_inicio, fecha_fin (opcional)
    """
    try:
        fecha_inicio = request.args.get('fecha_inicio')
        fecha_fin = request.args.get('fecha_fin', fecha_inicio)
        
        if not fecha_inicio:
            # Si no se proporciona fecha, usar hoy
            fecha_inicio = datetime.now().strftime('%Y-%m-%d')
            fecha_fin = fecha_inicio
        
        filepath = generar_excel_asistencias(fecha_inicio, fecha_fin)
        
        return send_file(
            filepath,
            mimetype='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            as_attachment=True,
            download_name=os.path.basename(filepath)
        )
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route('/api/asistencia/exportar/estudiante/<nombre>', methods=['GET'])
def exportar_excel_estudiante(nombre):
    """Exportar historial de un estudiante a Excel"""
    try:
        filepath = generar_excel_por_estudiante(nombre)
        
        return send_file(
            filepath,
            mimetype='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            as_attachment=True,
            download_name=os.path.basename(filepath)
        )
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route('/asistencias', methods=['GET'])
def asistencias_legacy():
    """Endpoint legacy - mantener compatibilidad"""
    try:
        estudiantes = obtener_todos_estudiantes()
        lista = []
        
        for est in estudiantes:
            lista.append({
                "persona": est["nombre"],
                "fecha_creacion": est.get("ultima_asistencia", "N/A"),
                "asistencias": est.get("total_asistencias", 0)
            })
        
        return jsonify({"asistencias": lista}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ===============================
#  EJECUCIÓN
# ===============================
if __name__ == '__main__':
    print("=" * 60)
    print("🚀 Servidor Flask iniciado")
    print(f"📂 Carpeta de datos: {OUTPUT_FOLDER}")
    print(f"🗄️  Base de datos: {os.path.join(BASE_DIR, 'asistencias.db')}")
    print(f"📊 Reportes Excel: {REPORTS_FOLDER}")
    print(f"🤖 Modelo LBPH: {MODEL_PATH}")
    print(f"🌐 Servidor disponible en: http://0.0.0.0:8000")
    print("=" * 60)
    app.run(debug=True, host='0.0.0.0', port=8000)