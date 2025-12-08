import sqlite3
import os
from datetime import datetime
from contextlib import contextmanager

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DB_PATH = os.path.join(BASE_DIR, 'asistencias.db')


@contextmanager
def get_db_connection():
    """Context manager para manejar conexiones a la BD"""
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row  # Para obtener resultados como diccionarios
    try:
        yield conn
        conn.commit()
    except Exception as e:
        conn.rollback()
        raise e
    finally:
        conn.close()


def init_database():
    """Crear tablas si no existen"""
    with get_db_connection() as conn:
        cursor = conn.cursor()
        
        # Tabla estudiantes
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS estudiantes (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                nombre TEXT NOT NULL UNIQUE,
                codigo TEXT UNIQUE,
                foto_path TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        # Tabla asistencias
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS asistencias (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                estudiante_id INTEGER NOT NULL,
                fecha DATE NOT NULL,
                hora TIME NOT NULL,
                estado TEXT DEFAULT 'presente',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (estudiante_id) REFERENCES estudiantes(id),
                UNIQUE(estudiante_id, fecha)
            )
        ''')
        
        # Índices para mejorar rendimiento
        cursor.execute('''
            CREATE INDEX IF NOT EXISTS idx_asistencias_fecha 
            ON asistencias(fecha)
        ''')
        
        cursor.execute('''
            CREATE INDEX IF NOT EXISTS idx_asistencias_estudiante 
            ON asistencias(estudiante_id)
        ''')
        
        print("✅ Base de datos inicializada correctamente")


def insertar_estudiante(nombre: str, codigo: str = None, foto_path: str = None):
    """Insertar o actualizar estudiante"""
    with get_db_connection() as conn:
        cursor = conn.cursor()
        try:
            cursor.execute('''
                INSERT INTO estudiantes (nombre, codigo, foto_path)
                VALUES (?, ?, ?)
            ''', (nombre, codigo, foto_path))
            return cursor.lastrowid
        except sqlite3.IntegrityError:
            # Si ya existe, obtener su ID
            cursor.execute('SELECT id FROM estudiantes WHERE nombre = ?', (nombre,))
            result = cursor.fetchone()
            return result['id'] if result else None


def obtener_estudiante_por_nombre(nombre: str):
    """Obtener datos de un estudiante por nombre"""
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute('SELECT * FROM estudiantes WHERE nombre = ?', (nombre,))
        result = cursor.fetchone()
        return dict(result) if result else None


def registrar_asistencia(nombre: str):
    """
    Registrar asistencia del día actual.
    No permite duplicados en el mismo día.
    """
    fecha_actual = datetime.now().strftime('%Y-%m-%d')
    hora_actual = datetime.now().strftime('%H:%M:%S')
    
    with get_db_connection() as conn:
        cursor = conn.cursor()
        
        # Obtener o crear estudiante
        estudiante_id = insertar_estudiante(nombre)
        
        if not estudiante_id:
            return {"error": "No se pudo registrar el estudiante", "registrado": False}
        
        try:
            cursor.execute('''
                INSERT INTO asistencias (estudiante_id, fecha, hora, estado)
                VALUES (?, ?, ?, 'presente')
            ''', (estudiante_id, fecha_actual, hora_actual))
            
            return {
                "mensaje": f"Asistencia registrada para {nombre}",
                "fecha": fecha_actual,
                "hora": hora_actual,
                "registrado": True
            }
        except sqlite3.IntegrityError:
            # Ya tiene asistencia hoy
            cursor.execute('''
                SELECT hora FROM asistencias 
                WHERE estudiante_id = ? AND fecha = ?
            ''', (estudiante_id, fecha_actual))
            result = cursor.fetchone()
            hora_previa = result['hora'] if result else "desconocida"
            
            return {
                "mensaje": f"{nombre} ya registró asistencia hoy a las {hora_previa}",
                "fecha": fecha_actual,
                "hora": hora_previa,
                "registrado": False
            }


def obtener_asistencias_por_fecha(fecha: str):
    """Obtener todas las asistencias de una fecha específica"""
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute('''
            SELECT 
                e.nombre,
                e.codigo,
                a.fecha,
                a.hora,
                a.estado
            FROM asistencias a
            JOIN estudiantes e ON a.estudiante_id = e.id
            WHERE a.fecha = ?
            ORDER BY a.hora ASC
        ''', (fecha,))
        
        results = cursor.fetchall()
        return [dict(row) for row in results]


def obtener_asistencias_rango(fecha_inicio: str, fecha_fin: str):
    """Obtener asistencias en un rango de fechas"""
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute('''
            SELECT 
                e.nombre,
                e.codigo,
                a.fecha,
                a.hora,
                a.estado
            FROM asistencias a
            JOIN estudiantes e ON a.estudiante_id = e.id
            WHERE a.fecha BETWEEN ? AND ?
            ORDER BY a.fecha DESC, a.hora ASC
        ''', (fecha_inicio, fecha_fin))
        
        results = cursor.fetchall()
        return [dict(row) for row in results]


def obtener_historial_estudiante(nombre: str):
    """Obtener historial completo de asistencias de un estudiante"""
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute('''
            SELECT 
                a.fecha,
                a.hora,
                a.estado
            FROM asistencias a
            JOIN estudiantes e ON a.estudiante_id = e.id
            WHERE e.nombre = ?
            ORDER BY a.fecha DESC, a.hora DESC
        ''', (nombre,))
        
        results = cursor.fetchall()
        return [dict(row) for row in results]


def obtener_todos_estudiantes():
    """Obtener lista de todos los estudiantes registrados"""
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute('''
            SELECT 
                e.id,
                e.nombre,
                e.codigo,
                COUNT(a.id) as total_asistencias,
                MAX(a.fecha) as ultima_asistencia
            FROM estudiantes e
            LEFT JOIN asistencias a ON e.id = a.estudiante_id
            GROUP BY e.id, e.nombre, e.codigo
            ORDER BY e.nombre ASC
        ''')
        
        results = cursor.fetchall()
        return [dict(row) for row in results]


# Inicializar la base de datos al importar el módulo
init_database()