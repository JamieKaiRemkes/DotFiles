alias krr="kubectl rollout restart"
alias kdelnsstuck="delete-stuck-namespace"
alias kdm="data-mover"
alias kbb="busybox"

delete-stuck-namespace()
{
  NAMESPACE=$1
  echo "Attempting to delete stuck namespace $1..."
  kubectl proxy &
  kubectl get namespace $NAMESPACE -o json |jq '.spec = {"finalizers":[]}' >temp.json
  curl -k -H "Content-Type: application/json" -X PUT --data-binary @temp.json 127.0.0.1:8001/api/v1/namespaces/$NAMESPACE/finalize
  rm temp.json
  echo "Namespace $NAMESPACE should now be deleted."
}

data-mover() {
  cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: data-mover-$1-to-$2
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: data-mover
        image: busybox
        command: ["/bin/sh", "-c", "echo 'Starting copy...' && cp -rv /mnt/source/. /mnt/destination/ && echo 'Copy complete.'"]
        volumeMounts:
        - name: source
          mountPath: /mnt/source
        - name: destination
          mountPath: /mnt/destination
      volumes:
      - name: source
        persistentVolumeClaim:
          claimName: $1
      - name: destination
        persistentVolumeClaim:
          claimName: $2
EOF
}

busybox() {
  if [ -n "$1" ]; then
    kubectl run -it --rm busybox \
      --image=busybox \
      --restart=Never \
      --overrides='{
        "spec": {
          "containers": [{
            "name": "busybox",
            "image": "busybox",
            "stdin": true,
            "tty": true,
            "command": ["/bin/sh"],
            "volumeMounts": [{
              "name": "volume",
              "mountPath": "/volume"
            }]
          }],
          "volumes": [{
            "name": "volume",
            "persistentVolumeClaim": {
              "claimName": "'"$1"'"
            }
          }]
        }
      }'
  else
    kubectl run -it --rm busybox \
      --image=busybox \
      --restart=Never \
      -- /bin/sh
  fi
}