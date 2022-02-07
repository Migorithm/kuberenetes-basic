#create key
openssl genrsa -out tls.key 2048

#create certificate
openssl req -new -x509 -key tls.key -out tls.cert -days 360 -subj /CN=migo.example.com

#Create Secret resource from the above two files.
kubectl create secret tls tls-secret --cert=tls.cert --key=tls.key