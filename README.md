
# Abgabe 1.
## S3-Bucket
![AWS_S3_Bucket_flask_photo_album](images/AWS_S3_Bucket_flask_photo_album.png)

# Abgabe 2.
## FlaskWeb
![Image_Upload_Website](images/Website_flask_photo_album.png)

# Abgabe 3.
## RDS-DATABASE
![RDS_PRIMARY_REPLICA_SOURCE](images/RDS_Primary_ReplicaSource.png)
![RDS_PRIMARY_REPLICA_SOURCE](images/RDS_Console_primary_replicasource.png)

# Abgabe 4.
## AWS ARCHITECTURE 
![AWS ARCHITECTURE](images/aws_Architektur.png)
*Ein Architektur-Diagramm, welches die von Terraform kreierten AWS-Komponenten/Instanzen in Beziehung zueinander darstellt.*

# Abgabe 5.
## AWS Architecture Kubernetes
![AWS ARCHITECTURE KUBERNETES](images/aws_architektur_kubernetes.png)
*Ein Architektur-Diagramm, welches die von Terraform und kubeclt/helm kreierten AWS-Komponenten/Instanzen in Beziehung zueinander darstellt.*


# Abgabe 6.
## S3 Bucket thumbnails on the Flaskwebapp
![flask_app_with_thumbnails](images/flask_app_with_thumbnails.png)
*Hier ist die Flaskwebapp mit den Thumbnails zusehen. Jedoch bevor das Thumbnail nach dem Upload erscheint, dauert das ein wenig. Deswegen sollte man ein paar Sekunden warten (ca. 10s-30s) und nochmal die Webseite neuladen, danach sollten die Thumbnails zu sehen sein.*

### S3 Bucket folders
![S3_Bucket_Original_Small1](images/S3_Bucket_Original_Small1.png)
*Das ist der S3 Bucket mit dem Unterordner "Original" für die Originalbilder sowie dem Unterordner "Small" für die Thumbnails.*

![S3_Bucket_Original_Small2](images/S3_Bucket_Original_Small2.png)
*Hier sind sie nochmal ausführlich mit Beispielbildern zu sehen.*

## CloudWatch Logs
![CloudWatch_Logs_Lambda](images/CloudWatch_Logs_Lambda.png)
*Die CloudWatch Logs zeigen wie das Originalbild ins Thumbnail, also das .small Bild umgewandelt wurde.*