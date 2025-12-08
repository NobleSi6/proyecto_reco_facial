import cv2
import os
import numpy as np

def entrenar_modelo(data_path="Datos", output_model="modeloLBPHFace.xml"):
    """
    Entrena un modelo LBPH con las imágenes almacenadas en Datos/<persona>/.
    Cada carpeta es una etiqueta (persona).
    """

    people_list = os.listdir(data_path)
    print("Personas encontradas:", people_list)

    labels = []
    faces_data = []
    label = 0

    for person in people_list:
        person_path = os.path.join(data_path, person)

        print("\nProcesando imágenes de:", person)

        for file_name in os.listdir(person_path):
            file_path = os.path.join(person_path, file_name)

            # Cargar la imagen en tamaño 150x150
            image = cv2.imread(file_path, cv2.IMREAD_GRAYSCALE)

            if image is None:
                print("⚠ Imagen dañada o incompatible:", file_path)
                continue

            faces_data.append(image)
            labels.append(label)

        label += 1

    print("\nTotal de imágenes:", len(faces_data))
    print("Total de etiquetas:", len(labels))

    # Convertir listas a arrays
    labels = np.array(labels)

    # Crear el modelo LBPH
    face_recognizer = cv2.face.LBPHFaceRecognizer_create()

    print("\nEntrenando modelo LBPH, por favor espera...")
    face_recognizer.train(faces_data, labels)

    # Guardar el modelo
    face_recognizer.write(output_model)

    print("\n✔ Entrenamiento completado.")
    print(f"Modelo guardado como: {output_model}")


if __name__ == "__main__":
    # Entrena el modelo usando las imágenes procesadas del servidor
    entrenar_modelo()
